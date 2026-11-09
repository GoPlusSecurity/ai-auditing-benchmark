// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IPancakePair} from "../interfaces/IPancake.sol";
import {GlobalConfig} from "./GlobalConfig.sol";

/// @dev ===== external library conversion (size constraint) =====
/// The runtime bytecode of the CoreVault inheritance chain already exceeds the EIP-170 limit (24,576), so it cannot be deployed to BSC mainnet.
/// Hence this library's **external entry points** were changed from `internal` to `public`:
///   - the compiler switches to DELEGATECALL to this library's separately deployed instance;
///   - all price logic (TWAP accumulation, 3-block average, deviation clamping, two-hop conversion) is thereby moved out of CoreVault's bytecode.
/// Cost: ~100 (warm)/~2600 (cold) extra gas per call; deployment must link the library address (forge handles it automatically).
/// Pitfall: `private` helper functions stay unchanged -- they are called by the public entry points and compiled into the **library itself**, not back into CoreVault.
/// Pitfall: the semantics of `storage` parameters are fully preserved under DELEGATECALL (the library reads and writes CoreVault's storage slots),
///   so writes like `s.aPerUsd = ...` still correctly affect CoreVault's `_oracle`.
library OracleLib {
  struct BlockWindow {
    uint64 lastBlock;
    uint8  filled;
    uint256 sample0;
    uint256 sample1;
    uint256 sample2;
  }

  struct TimeWindow {
    uint32 lastTs;
    uint8  filled;
    uint256 sample0;
    uint256 sample1;
    uint256 sample2;
  }

  struct OracleState {
    uint256 price0CumulativeLast;
    uint256 price1CumulativeLast;
    uint32  twapLastUpdate;
    uint256 aTwapPerB;
    uint256 bPrice0CumulativeLast;
    uint256 bPrice1CumulativeLast;
    uint32  bTwapLastUpdate;
    uint256 bTwapPerUsd;
    uint256 wbnbPrice0CumulativeLast;
    uint256 wbnbPrice1CumulativeLast;
    uint32  wbnbTwapLastUpdate;
    uint256 wbnbTwapPerUsd;
    BlockWindow aAvgWindow;
    BlockWindow bAvgWindow;
    TimeWindow  wbnbAvgWindow;
    uint256 aPerUsd;
    uint256 wbnbPerUsd;
    uint256 bPerUsd;
    IPancakePair aOskFistPair;
    IPancakePair wbnbUsdtPair;
    IPancakePair bUsdtPair;
    address aToken;
    address bToken;
    // WARNING: `address wbnb;` was removed -- that field **never had any write site** (the setter was removed during reconstruction),
    //   causing `spotWbnbPerUsd` / `updateWbnbTwap` to always return 0 => BNB farming deposits permanently failed with
    //   `CoreVault_PriceUnavailable`. The WBNB address now comes directly from `GlobalConfig.getWBNB()`
    //   (an on-chain constant, consistent with the 9/21 original behavior; the original `getWbnbPerUsd()` being nonzero is corroborating evidence).
    //   Regression: test/BnbDepositPriceFix.fork.t.sol
  }

  uint256 internal constant MAX_DEVIATION_BP = 1000;
  uint256 internal constant AVG_WINDOW_SIZE = 3;
  uint32 internal constant WBNB_SNAPSHOT_INTERVAL = 3 minutes;

  function getAPerUsd(OracleState storage s) public returns (uint256) {
    if (s.aPerUsd > 0) return s.aPerUsd;
    updateATwap(s);
    return _calcAPerUsd(s);
  }

  function getAPerUsdView(OracleState storage s) public view returns (uint256) {
    if (s.aPerUsd > 0) return s.aPerUsd;
    return _calcAPerUsd(s);
  }

  function getBPerUsd(OracleState storage s) public returns (uint256) {
    if (s.bPerUsd > 0) return s.bPerUsd;
    updateBTwap(s);
    return _calcBPerUsd(s);
  }

  function getBPerUsdView(OracleState storage s) public view returns (uint256) {
    if (s.bPerUsd > 0) return s.bPerUsd;
    return _calcBPerUsd(s);
  }

  function getWbnbPerUsd(OracleState storage s) public returns (uint256) {
    if (s.wbnbPerUsd > 0) return s.wbnbPerUsd;
    updateWbnbTwap(s);
    return _selectWbnbPerUsd(s);
  }

  function getWbnbPerUsdView(OracleState storage s) public view returns (uint256) {
    if (s.wbnbPerUsd > 0) return s.wbnbPerUsd;
    return _selectWbnbPerUsd(s);
  }

  function getAccountingPrices(OracleState storage s) public returns (uint256 aPerUsd, uint256 bPerUsd, uint256 wbnbPerUsd) {
    if (s.aPerUsd > 0) aPerUsd = s.aPerUsd;
    if (s.bPerUsd > 0) bPerUsd = s.bPerUsd;
    if (s.wbnbPerUsd > 0) wbnbPerUsd = s.wbnbPerUsd;

    _updateAccountingSnapshots(s);

    uint256 avgW = wbnbPerUsd > 0 ? wbnbPerUsd : _avgWbnbPerUsdView(s);
    wbnbPerUsd = avgW;
    if (aPerUsd == 0) {
      uint256 avgA = _avgAPerBView(s);
      uint256 avgB = _avgBPerUsdView(s);
      aPerUsd = (avgA == 0 || avgB == 0) ? 0 : Math.mulDiv(avgA, avgB, 1e18, Math.Rounding.Floor);
    }
    if (bPerUsd == 0) {
      bPerUsd = _avgBPerUsdView(s);
    }
  }

  function getAccountingPricesView(OracleState storage s) public view returns (uint256 aPerUsd, uint256 bPerUsd, uint256 wbnbPerUsd) {
    if (s.aPerUsd > 0) aPerUsd = s.aPerUsd;
    if (s.bPerUsd > 0) bPerUsd = s.bPerUsd;
    if (s.wbnbPerUsd > 0) wbnbPerUsd = s.wbnbPerUsd;

    uint256 avgW = wbnbPerUsd > 0 ? wbnbPerUsd : _avgWbnbPerUsdView(s);
    wbnbPerUsd = avgW;
    if (aPerUsd == 0) {
      uint256 avgA = _avgAPerBView(s);
      uint256 avgB = _avgBPerUsdView(s);
      aPerUsd = (avgA == 0 || avgB == 0) ? 0 : Math.mulDiv(avgA, avgB, 1e18, Math.Rounding.Floor);
    }
    if (bPerUsd == 0) {
      bPerUsd = _avgBPerUsdView(s);
    }
  }

  /// @dev Swap/display price policy -- **always computed live**, no longer short-circuiting to a manual `s.*PerUsd` snapshot.
  /// Pitfall (severe, a silent-failure backdoor): the original implementation returned the stored value directly when `s.aPerUsd > 0`.
  ///   But `s.aPerUsd` is written only by owner's `setAPerUsd` and **never self-heals** --
  ///   once set, this view and all downstream prices would be **permanently frozen** at that value, fully decoupled from the market.
  ///   The mainnet deployment's three snapshots measured 0 (never triggered), so that risk was not yet active; now it is computed live unconditionally to eliminate it.
  ///   Note: `getAccountingPrices`'s emergency-override semantics **stay unchanged** (that is the settlement policy, which needs manual intervention).
  /// Pitfall: when any factor of the multi-hop conversion is 0, the whole thing returns 0, and the caller checks for zero and reverts -- never treat 0 as a price.
  function getSwapPricesView(OracleState storage s) public view returns (uint256 aPerUsd, uint256 bPerUsd, uint256 wbnbPerUsd) {
    wbnbPerUsd = _selectWbnbPerUsd(s);
    uint256 aPerB = _pickAPerB(s);
    uint256 bUsd = _pickBPerUsd(s);
    aPerUsd = (aPerB == 0 || bUsd == 0) ? 0 : Math.mulDiv(aPerB, bUsd, 1e18, Math.Rounding.Floor);
    bPerUsd = bUsd;
  }

  function updateATwap(OracleState storage s) public {
    if (address(s.aOskFistPair) == address(0)) return;
    uint32 blockTs = uint32(block.timestamp % 2**32);
    uint256 p0 = s.aOskFistPair.price0CumulativeLast();
    uint256 p1 = s.aOskFistPair.price1CumulativeLast();
    if (s.twapLastUpdate == 0) {
      s.price0CumulativeLast = p0;
      s.price1CumulativeLast = p1;
      s.twapLastUpdate = blockTs;
      return;
    }
    uint32 elapsed = blockTs - s.twapLastUpdate;
    if (elapsed < GlobalConfig.TWAP_PERIOD) return;
    // OSK/FIST pair: when aToken=OSK is token0, use the price1 cumulative (FIST per OSK); otherwise use price0
    address t0 = s.aOskFistPair.token0();
    uint256 delta;
    unchecked { delta = t0 == s.aToken ? (p1 - s.price1CumulativeLast) / elapsed : (p0 - s.price0CumulativeLast) / elapsed; }
    s.aTwapPerB = Math.mulDiv(delta, 1e18, GlobalConfig.UQ112, Math.Rounding.Floor);
    s.price0CumulativeLast = p0;
    s.price1CumulativeLast = p1;
    s.twapLastUpdate = blockTs;
  }

  function updateBTwap(OracleState storage s) public {
    if (address(s.bUsdtPair) == address(0)) return;
    uint32 blockTs = uint32(block.timestamp % 2**32);
    uint256 p0 = s.bUsdtPair.price0CumulativeLast();
    uint256 p1 = s.bUsdtPair.price1CumulativeLast();
    if (s.bTwapLastUpdate == 0) {
      s.bPrice0CumulativeLast = p0;
      s.bPrice1CumulativeLast = p1;
      s.bTwapLastUpdate = blockTs;
      return;
    }
    uint32 elapsed = blockTs - s.bTwapLastUpdate;
    if (elapsed < GlobalConfig.TWAP_PERIOD) return;
    // FIST/USDT pair: when bToken=FIST is token0, use the price1 cumulative (the inverse direction of USDT per FIST),
    //   otherwise use price0.
    address t0 = s.bUsdtPair.token0();
    uint256 delta;
    unchecked { delta = t0 == s.bToken ? (p1 - s.bPrice1CumulativeLast) / elapsed : (p0 - s.bPrice0CumulativeLast) / elapsed; }
    s.bTwapPerUsd = Math.mulDiv(delta, 1e18, GlobalConfig.UQ112, Math.Rounding.Floor);
    s.bPrice0CumulativeLast = p0;
    s.bPrice1CumulativeLast = p1;
    s.bTwapLastUpdate = blockTs;
  }

  function updateWbnbTwap(OracleState storage s) public {
    if (address(s.wbnbUsdtPair) == address(0)) return;
    uint32 blockTs = uint32(block.timestamp % 2**32);
    uint256 p0 = s.wbnbUsdtPair.price0CumulativeLast();
    uint256 p1 = s.wbnbUsdtPair.price1CumulativeLast();
    if (s.wbnbTwapLastUpdate == 0) {
      s.wbnbPrice0CumulativeLast = p0;
      s.wbnbPrice1CumulativeLast = p1;
      s.wbnbTwapLastUpdate = blockTs;
      return;
    }
    uint32 elapsed = blockTs - s.wbnbTwapLastUpdate;
    if (elapsed < GlobalConfig.TWAP_PERIOD) return;
    // Pitfall: the WBNB address comes from an on-chain constant, not a storage field -- the original `s.wbnb` had no write site and was always 0,
    //   which would keep the TWAP from ever advancing. Regression: test/BnbDepositPriceFix.fork.t.sol
    address wbnb_ = GlobalConfig.getWBNB();
    if (wbnb_ == address(0)) return;
    address t0 = s.wbnbUsdtPair.token0();
    uint256 delta;
    unchecked { delta = t0 == wbnb_ ? (p1 - s.wbnbPrice1CumulativeLast) / elapsed : (p0 - s.wbnbPrice0CumulativeLast) / elapsed; }
    s.wbnbTwapPerUsd = Math.mulDiv(delta, 1e18, GlobalConfig.UQ112, Math.Rounding.Floor);
    s.wbnbPrice0CumulativeLast = p0;
    s.wbnbPrice1CumulativeLast = p1;
    s.wbnbTwapLastUpdate = blockTs;
  }

  function spotAPerB(OracleState storage s) public view returns (uint256) {
    if (address(s.aOskFistPair) == address(0)) return 0;
    (uint112 r0, uint112 r1,) = s.aOskFistPair.getReserves();
    if (r0 == 0 || r1 == 0) return 0;
    // OSK/FIST pair: returns OSK per FIST (OSK is token0 -> r0/r1; otherwise -> r1/r0)
    return s.aOskFistPair.token0() == s.aToken
      ? Math.mulDiv(uint256(r0), 1e18, uint256(r1), Math.Rounding.Floor)
      : Math.mulDiv(uint256(r1), 1e18, uint256(r0), Math.Rounding.Floor);
  }

  function spotBPerUsd(OracleState storage s) public view returns (uint256) {
    if (address(s.bUsdtPair) == address(0)) return 0;
    (uint112 r0, uint112 r1,) = s.bUsdtPair.getReserves();
    if (r0 == 0 || r1 == 0) return 0;
    // FIST/USDT pair: returns FIST per USD (= FIST per USDT, USDT≈USD)
    //   FIST is token0 -> r0/r1 (FIST/USDT); otherwise -> r1/r0
    return s.bUsdtPair.token0() == s.bToken
      ? Math.mulDiv(uint256(r0), 1e18, uint256(r1), Math.Rounding.Floor)
      : Math.mulDiv(uint256(r1), 1e18, uint256(r0), Math.Rounding.Floor);
  }

  function spotWbnbPerUsd(OracleState storage s) public view returns (uint256) {
    if (address(s.wbnbUsdtPair) == address(0)) return 0;
    (uint112 r0, uint112 r1,) = s.wbnbUsdtPair.getReserves();
    if (r0 == 0 || r1 == 0) return 0;
    // * Fix (2026-09-24): it used to be `address wbnb_ = s.wbnb;` -- that field has no write site anywhere in the repo and is always 0,
    //   making this function always return 0 => `_depositBNBCore`'s `avgWbnbPerUsd == 0` check passed
    //   => BNB farming deposits (including fallback op 0x01) **permanently reverted** with `CoreVault_PriceUnavailable`.
    //   Changed to the on-chain constant `GlobalConfig.getWBNB()` (consistent with the 9/21 original behavior).
    //   Regression: test/BnbDepositPriceFix.fork.t.sol (reproduction + fix verification)
    address wbnb_ = GlobalConfig.getWBNB();
    if (wbnb_ == address(0)) return 0;
    return s.wbnbUsdtPair.token0() == wbnb_
      ? Math.mulDiv(uint256(r0), 1e18, uint256(r1), Math.Rounding.Floor)
      : Math.mulDiv(uint256(r1), 1e18, uint256(r0), Math.Rounding.Floor);
  }

  function getTwapAPerB(OracleState storage s) public view returns (uint256) { return s.aTwapPerB; }
  function getTwapBPerUsd(OracleState storage s) public view returns (uint256) { return s.bTwapPerUsd; }
  function getTwapWbnbPerUsd(OracleState storage s) public view returns (uint256) { return s.wbnbTwapPerUsd; }

  function _pushBlockSample(BlockWindow storage w, uint256 sample) private {
    if (sample == 0 || block.number == w.lastBlock) return;
    w.lastBlock = uint64(block.number);
    w.sample0 = w.sample1;
    w.sample1 = w.sample2;
    w.sample2 = sample;
    if (w.filled < AVG_WINDOW_SIZE) w.filled++;
  }

  function _pushTimeSample(TimeWindow storage w, uint256 sample) private {
    if (sample == 0) return;
    uint32 blockTs = uint32(block.timestamp % 2**32);
    if (w.lastTs != 0 && blockTs - w.lastTs < WBNB_SNAPSHOT_INTERVAL) return;
    w.lastTs = blockTs;
    w.sample0 = w.sample1;
    w.sample1 = w.sample2;
    w.sample2 = sample;
    if (w.filled < AVG_WINDOW_SIZE) w.filled++;
  }

  function _avgBlockWindow(BlockWindow storage w, uint256 fallbackSpot) private view returns (uint256) {
    if (w.filled == 0) return fallbackSpot;
    return (w.sample0 + w.sample1 + w.sample2) / w.filled;
  }

  function _avgTimeWindow(TimeWindow storage w, uint256 fallbackSpot) private view returns (uint256) {
    if (w.filled == 0) return fallbackSpot;
    return (w.sample0 + w.sample1 + w.sample2) / w.filled;
  }

  function _updateAccountingSnapshots(OracleState storage s) private {
    _pushBlockSample(s.aAvgWindow, spotAPerB(s));
    _pushBlockSample(s.bAvgWindow, spotBPerUsd(s));
    _pushTimeSample(s.wbnbAvgWindow, spotWbnbPerUsd(s));
  }

  function _avgAPerBView(OracleState storage s) private view returns (uint256) {
    return _avgBlockWindow(s.aAvgWindow, spotAPerB(s));
  }

  function _avgBPerUsdView(OracleState storage s) private view returns (uint256) {
    return _avgBlockWindow(s.bAvgWindow, spotBPerUsd(s));
  }

  function _avgWbnbPerUsdView(OracleState storage s) private view returns (uint256) {
    return _avgTimeWindow(s.wbnbAvgWindow, spotWbnbPerUsd(s));
  }

  /// @dev Three-source median -- the core primitive resisting **single-source failure**.
  /// Pitfall (severe, the measured root cause): the original `_selectPrice(spot, twap)` **unconditionally trusted the TWAP** when the two differed by >10%,
  ///   on the premise that "the TWAP is trustworthy and spot may be manipulated". But this library's TWAP = `pair cumulative price delta / wall-clock seconds elapsed`,
  ///   and a Pancake pair's cumulative price **advances only when touched (swap/mint/burn/sync)** -- when trades are sparse the numerator is tiny
  ///   while the denominator is the full wall-clock time, so the TWAP is **systematically severely underestimated**. Measured on the mainnet test build:
  ///     - `aTwapPerB`   stored 4.96e29, real 2.97e35  -> off by **6 orders of magnitude**
  ///     - `bTwapPerUsd` stored 1875,    real 4.14e6   -> off by **3.7 orders of magnitude**
  ///   Consequence: `_pickAPerB × _pickBPerUsd` collapsed to 9.3e14 -> `mcap` surged to 1.28e29
  ///   -> hit the highest tier -> the yield rate was **pinned at 2.5%/day** (should be 0.7%/day, a +257% relative error).
  ///   This is the real cause of the "tier lock-in" -- fixing only the unit/dimension of `_getMcapUsd` (division) was **not sufficient**.
  /// Fix: changed to the **three-source median** of spot / TWAP / 3-block average. The median is naturally immune to a single outlier:
  ///   - TWAP underestimated -> the median takes the one between spot and the average (i.e. the true price);
  ///   - spot manipulated by a flash loan -> the median takes the one between the TWAP and the average (i.e. the unmanipulated price);
  ///   - all three agree -> equivalent to the original semantics, zero behavior change.
  function _median3(uint256 a, uint256 b, uint256 c) private pure returns (uint256) {
    uint256 hi = a > b ? (a > c ? a : c) : (b > c ? b : c);
    uint256 lo = a < b ? (a < c ? a : c) : (b < c ? b : c);
    unchecked { return a + b + c - hi - lo; }
  }

  /// @dev Two-source clamping (preserves the original semantics) -- used only when one of the TWAP or the average window is unavailable.
  function _selectPrice(uint256 spot, uint256 twap) private pure returns (uint256) {
    if (twap == 0) return spot;
    uint256 diff = spot > twap ? spot - twap : twap - spot;
    return diff * 10000 > twap * MAX_DEVIATION_BP ? twap : spot;
  }

  /// @dev Three-source pricing: when any source is 0 it degrades to two-source, and when both are 0 it degrades to spot.
  function _selectPrice3(uint256 spot, uint256 twap, uint256 avgW) private pure returns (uint256) {
    if (twap == 0) return avgW == 0 ? spot : _selectPrice(spot, avgW);
    if (avgW == 0) return _selectPrice(spot, twap);
    return _median3(spot, twap, avgW);
  }

  /// @dev Spot price + **three-source median** anti-manipulation. When the TWAP is not ready (== 0), the 3-block average fills in the second source.
  /// Pitfall: when the average window is not filled, its value equals spot -> the median degrades to spot, which is safe and introduces no new risk.
  /// Pitfall (gas): only one `getReserves()` read throughout -- the spot value is reused via `spot`, with no second evaluation.
  function _pickAPerB(OracleState storage s) public view returns (uint256) {
    uint256 spot = spotAPerB(s);
    if (spot == 0) return 0;
    uint256 avgW = s.aAvgWindow.filled == 0 ? spot : _avgBlockWindow(s.aAvgWindow, 0);
    return _selectPrice3(spot, getTwapAPerB(s), avgW);
  }

  function _pickBPerUsd(OracleState storage s) public view returns (uint256) {
    uint256 spot = spotBPerUsd(s);
    if (spot == 0) return 0;
    uint256 avgW = s.bAvgWindow.filled == 0 ? spot : _avgBlockWindow(s.bAvgWindow, 0);
    return _selectPrice3(spot, getTwapBPerUsd(s), avgW);
  }

  function _selectWbnbPerUsd(OracleState storage s) public view returns (uint256) {
    uint256 spot = spotWbnbPerUsd(s);
    if (spot == 0) return 0;
    uint256 avgW = s.wbnbAvgWindow.filled == 0 ? spot : _avgTimeWindow(s.wbnbAvgWindow, 0);
    return _selectPrice3(spot, getTwapWbnbPerUsd(s), avgW);
  }

  /// @notice Permissionless keeper: refresh all three TWAPs and the three average windows in one call.
  /// @dev Design rationale: the original implementation hung the TWAP/window refresh **only on the non-view deposit and claim paths**, so while the protocol was idle
  ///   the oracle stayed in a "TWAP = 0 + window has only 1 stale sample" state, and both anti-manipulation and smoothing failed.
  ///   This entry point upgrades the refresh from a "byproduct of user behavior" to an explicit action "that anyone/bot can actively maintain".
  /// Pitfall: no fund transfers, no state privileges, only writes price caches; anyone calling it produces no permission or economic risk.
  function refreshOracle(OracleState storage s) public {
    updateATwap(s);
    updateBTwap(s);
    updateWbnbTwap(s);
    _updateAccountingSnapshots(s);
  }

  function _calcAPerUsd(OracleState storage s) private view returns (uint256) {
    // OSK price = OSK/FIST × FIST/USDT (two hops: OSK->FIST->USD)
    // User statement: OSK has only the OSK/FIST pair, FIST has only the FIST/USDT pair; other pairs carry liquidity-removal risk
    uint256 b = _pickBPerUsd(s);
    if (b == 0) return 0;
    uint256 aPerB = _pickAPerB(s);
    return aPerB == 0 ? 0 : Math.mulDiv(aPerB, b, 1e18, Math.Rounding.Floor);
  }

  function _calcBPerUsd(OracleState storage s) private view returns (uint256) {
    // FIST price is read directly from the FIST/USDT pair, no longer routed via WBNB --
    //   user statement: FIST uses only the FIST/USDT pair; other pairs carry liquidity-removal risk.
    return _pickBPerUsd(s);
  }

  function getAllPrices(OracleState storage s) public returns (uint256 aPerUsd, uint256 bPerUsd, uint256 wbnbPerUsd) {
    bool needA;
    bool needB;
    bool needW;

    if (s.aPerUsd == 0) needA = true;
    else aPerUsd = s.aPerUsd;

    if (s.bPerUsd == 0) needB = true;
    else bPerUsd = s.bPerUsd;

    if (s.wbnbPerUsd == 0) needW = true;
    else wbnbPerUsd = s.wbnbPerUsd;

    if (needA || needB || needW) {
      if (needA) updateATwap(s);
      if (needB) updateBTwap(s);
      if (needW) updateWbnbTwap(s);

      uint256 w = wbnbPerUsd;
      if (needW) { w = _selectWbnbPerUsd(s); wbnbPerUsd = w; }
      else if (w == 0) w = _selectWbnbPerUsd(s);

      if (needA) {
        uint256 aPerB = _pickAPerB(s);
        uint256 bUsd = _pickBPerUsd(s);
        aPerUsd = (aPerB == 0 || bUsd == 0) ? 0 : Math.mulDiv(aPerB, bUsd, 1e18, Math.Rounding.Floor);
      }
      if (needB) {
        bPerUsd = _pickBPerUsd(s);
      }
    }
  }
}
