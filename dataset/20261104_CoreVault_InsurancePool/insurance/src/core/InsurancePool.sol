// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Auth} from "../access/Auth.sol";
import {IAccounting} from "../interfaces/IAccounting.sol";
import {IPancakeRouter, IPancakePair} from "../interfaces/IPancake.sol";
import {GlobalConfig} from "./GlobalConfig.sol";

// ── Automatic market-support insurance pool (FIST market-making channel) ──
// Requirement 2.0 section 2 L63: the insurance pool makes markets automatically -- buy 5% when the price drops 10%, sell when the price rises 10% only down to a +3% rise,
//   a single buy is worth at most 1000 usd, and if the target is not met it buys in multiple batches; once met it stops supporting the market this cycle; selling is once per cycle
//   (cycle = PERIOD_SECONDS: production 1 day / FAST_TEST 1 hour -- client request on 2026-09-26).
//   Market-making funds = the 20% FIST reserve from farming FIST deposits.
// Requirement 2.0 section 2 L43: the BNB reserve is used only as a redemption payment reserve -- **no market-making**.
// Pitfall: requirement 1.0's "BNB channel market-making" (executeBuy/executeSell, supporting OSK/WBNB) has been removed entirely --
//   (1) requirement 2.0 L43's BNB description deleted the market-making clause;
//   (2) requirement 2.0 L144 states OSK has only the OSK/FIST pair, so the BNB channel has no available pair.
// The BNB reserve capability (receive + withdrawReserve) is kept, for the redemption reserve.
contract InsurancePool is Auth, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ── External dependencies ──
    IERC20 public aToken;          // OSK (sold when the market support sells)
    IPancakeRouter public router;
    IAccounting public accounting;
    address public treasury;

    // ── Adjustable parameters (storage-packing optimized) ──
    uint48 public slippageBp;

    // ── Parameter timelock ──
    uint256 private _pendingSlippageBp;
    uint256 private _pendingAt;

    // ════════════════════════════════════════════════════════════
    //  Requirement 2.0 section 2 L63: FIST market-making channel (supporting the OSK/FIST pair)
    // ════════════════════════════════════════════════════════════
    // Design intent: this pool's only market-making channel --
    //   - fund token: FIST reserve (from the 20% of farming FIST deposits)
    //   - target pair: OSK/FIST (Requirement 2.0 L144: OSK has only this pair)
    //   - price policy: "how much FIST is 1 OSK worth" = rFist/rOsk
    //   - trigger/target: buy on a 10% drop down to -5% / sell on a 10% rise down to +3%
    // WARNING: requirement L63 explicitly says "buy and sell market-making once a day" -> for the cycle basis see `PERIOD_SECONDS`
    //    (production 1 day; 1 hour under FAST_TEST, per the client request on 2026-09-26).
    IERC20 public bToken;                 // FIST token (market-making payment token)
    IPancakePair public oskFistPair;      // OSK/FIST pair (market support target)
    uint256 public dailyRefPriceFist;     // this cycle's reference price (OSK per FIST)
    uint256 public refPeriodStartFist;
    uint256 public todayBuyFistUsed;      // FIST budget used this cycle (also serves as the "bought this cycle" flag)
    uint256 public todayMaxBuyFistBudget;
    uint32 public todayBuyFistDay;        // this cycle number (= block.timestamp / PERIOD_SECONDS)
    bool public todayBuyFistFinished;
    uint32 public todaySellFistDay;       // this cycle number (sell-cycle dedup)
    /// @dev The reference price snapshot's **single-period maximum deviation** (bp). Prevents manipulating the spot reserves at a cycle boundary to lock in a distorted reference price.
    ///      Default 2000 (20%). Setting it to 0 disables clamping (not recommended).
    uint256 public maxRefDeviationBp;

    // ── Fixed parameters ──
    // Pitfall: raised from private to internal -- so a derived test harness can assert the constant policy,
    //       without changing any runtime behavior or the storage layout (a constant occupies no slot).
    uint256 internal constant BP = 10000;
    uint256 internal constant BUY_TRIGGER_DROP_BP = 1000;
    uint256 internal constant BUY_TARGET_DROP_BP = 500;
    // Requirement 2.0 L63: "a single buy is worth at most 1000 usd" -- the USD value cap of a single buy.
    //   Converted into FIST amount by accounting.getBPerUsd(); when accounting is not wired it degrades to the in-pool balance cap.
    uint256 internal constant MAX_SINGLE_BUY_USD = 1000 ether;
    // Note: POOL_BUDGET_BP (5% of the pool balance) was requirement 1.0's batched budget policy, and 2.0 changed it to "a single 1000 USD";
    //     this constant is kept only for historical traceability and no longer participates in any computation.
    uint256 internal constant POOL_BUDGET_BP = 500;
    uint256 internal constant SELL_TRIGGER_RISE_BP = 1000;
    // Requirement 2.0 section 2: "sell when the price rises 10% only down to a +3% rise" -> trigger line +10%, target falls back to ref + 3%
    // Pitfall: requirement 1.0 said "sell 7%", while requirement 2.0 explicitly says "sell only down to a +3% rise"; 2.0 prevails.
    //       The buy side is implemented per 2.0's text "multiple batched buys + a single 1000 USD"; the sell side is once per cycle
    //       (cycle = PERIOD_SECONDS: production 1 day / FAST_TEST 1 hour).
    uint256 internal constant SELL_TARGET_RISE_BP = 300;
    uint256 internal constant TIMELOCK_DELAY = 2 days;
    uint256 internal constant SLIPPAGE_MAX_BP = 5000;
    // BNB->ATK single hop 0.25% fee, 3% buffer covers volatility
    uint256 internal constant SWAP_BUFFER_BP = 10300;
    /// @dev Market-making cycle length (seconds) -- the cycle basis for reference price locking and "sell once a day".
    ///      Production = **1 day**; when `GlobalConfig.FAST_TEST = true` it shortens to **1 hour**,
    ///      so that "support the market successfully once a day" can be reproduced within 1 hour in fast tests.
    ///      Evidence: the client requested on 2026-09-26 "change the insurance pool's once-a-day successful market support to once an hour".
    /// Pitfall: unrelated to `Treasury.REFILL_COOLDOWN` -- the latter is the treasury refill cooldown, and the two are independent.
    uint256 internal constant PERIOD_SECONDS = GlobalConfig.FAST_TEST ? 1 hours : 1 days;

    // ── Events ──
    event ParamsProposed(uint256 slippageBp, uint256 executeAt);
    event ParamsExecuted(uint256 slippageBp);
    event ParamsCancelled();
    event TreasurySet(address indexed treasury);
    event ReserveWithdrawn(address indexed token, address indexed to, uint256 amount);
    // ── Requirement 2.0 L63: FIST market-making channel events ──
    event FistDailyReferenceUpdated(uint256 price, uint256 periodStart);
    event FistBuyExecuted(uint256 fistAmount, uint256 oskReceived);
    event FistSellExecuted(uint256 oskAmount, uint256 fistReceived);
    event BTokenSet(address indexed bToken);
    event OskFistPairSet(address indexed pair);
    // reference price clamped by deviation (raw is the spot original value, clamped is the reference price actually used)
    event FistRefPriceClamped(uint256 raw, uint256 clamped);
    event MaxRefDeviationSet(uint256 bp);

    // ── Custom errors ──
    error InsPool_ZeroAddress();
    error InsPool_ZeroPrice();
    error InsPool_RefNotSet();
    error InsPool_Unauthorized();
    error InsPool_BadSlippage();
    error InsPool_PendingNone();
    error InsPool_TimelockPending();
    error InsPool_SweepZero();
    error InsPool_TransferFailed();
    // ── Requirement 2.0 L63: FIST market-making channel errors ──
    // Note: the former InsPool_FistBoughtToday (buy once-a-day gating) was removed along with requirement 2.0's "multiple batched buys" policy.
    error InsPool_FistNotConfigured();
    error InsPool_FistNoDip();
    error InsPool_FistNoPump();
    error InsPool_FistSoldToday();
    error InsPool_FistNoOsk();
    error InsPool_FistCalcZero();
    error InsPool_FistCapReached();
    error InsPool_FistBuyFinished();
    error InsPool_BadRefDeviation(uint256 bp);

    constructor(
        address _aToken, address _router,
        address _accounting
    ) Auth() {
        if (_aToken == address(0) || _router == address(0))
            revert InsPool_ZeroAddress();
        aToken = IERC20(_aToken);
        router = IPancakeRouter(_router);
        if (_accounting != address(0)) accounting = IAccounting(_accounting);
        slippageBp = 500;
        // Pitfall: the FIST channel's cycle counter must be initialized to a **sentinel** rather than 0 --
        //   if initialized to 0, then when block.timestamp < PERIOD_SECONDS (cycle computed as 0),
        //   `period == todayBuyFistDay` would hold on the **first call**, wrongly reporting "already market-made this cycle" and refusing to execute.
        //   The sentinel type(uint32).max cannot be any real cycle number, guaranteeing the first call always passes.
        todayBuyFistDay = type(uint32).max;
        todaySellFistDay = type(uint32).max;
        // FIST reference price single-period maximum deviation 20% (prevents manipulating spot at a cycle boundary to lock in a distorted reference price)
        maxRefDeviationBp = 2000;
    }

    // ── Public execution entry points ──
    // Note: requirement 2.0 removed BNB channel market-making (executeBuy/executeSell/updateDailyReference),
    //     keeping only the FIST market-making channel (executeBuyFist/executeSellFist/updateDailyReferenceFist).

    // ════════════════════════════════════════════════════════════
    //  Requirement 2.0 section 2 L63: FIST market-making channel -- supporting the OSK/FIST pair
    // ════════════════════════════════════════════════════════════
    // Requirement text: "20 usd worth of fist -> insurance pool multisig address (fist reserve, used as the redemption payment reserve,
    //           the insurance pool makes markets automatically, buy 5% when the price drops 10%, sell when the price rises 10% only down to a +3% rise,
    //           buy and sell market-making once a day)"

    /// @notice Refresh the FIST channel's intraday reference price (public keeper entry point)
    function updateDailyReferenceFist() external nonReentrant { _autoRefFist(); }

    /// @notice FIST market support buy: when OSK depreciates >=10% against FIST, use the FIST reserve to buy OSK
    /// @dev Price policy: "how much FIST is 1 OSK worth" (rFist/rOsk).
    /// Requirement L63 text: "buy 5% when the price drops 10% ... a single buy is worth at most 1000 usd,
    ///   if one buy does not meet the target then buy in multiple batches, and once met stop supporting the market that day" --
    ///   so the buy side is a **batched** mechanism: a single buy <= 1000 USD value, and if the target is not met it can be called again the same day;
    ///   once the price returns to the -5% target, todayBuyFistFinished is set and no more buying happens that day.
    /// Pitfall (severe): `todayBuyFistFinished` must be **reset on a new day** (handled by `_resetBuyFistDay()`) --
    ///   if it is only set true and never reset, then after the first target is met the flag stays true forever and the buy side is permanently crippled.
    /// Pitfall: the new-day check must come **before** the `todayBuyFistFinished` guard, otherwise the reset can never happen.
    /// Pitfall: CEI -- record the day's cumulative amount first, then perform the external swap interaction.
    function executeBuyFist() external nonReentrant {
        _autoRefFist();

        uint32 day = uint32(block.timestamp / PERIOD_SECONDS);
        if (day != todayBuyFistDay) _resetBuyFistDay(day);
        // Requirement L63: once the target is met, stop supporting the market that day (batched buying until the price returns to the -5% target).
        //   The early-return failure path does not set the flag, so it can be retried the same day.
        if (todayBuyFistFinished) revert InsPool_FistBuyFinished();

        uint256 curPrice = _getOskFistPrice();
        if (curPrice >= dailyRefPriceFist) revert InsPool_FistNoDip();
        uint256 dropBp = (dailyRefPriceFist - curPrice) * BP / dailyRefPriceFist;
        if (dropBp < BUY_TRIGGER_DROP_BP) revert InsPool_FistNoDip();

        uint256 targetPrice = dailyRefPriceFist * (BP - BUY_TARGET_DROP_BP) / BP;
        // Note: this branch is currently **unreachable** -- the drop >= 10% above requires cur <= 0.90·ref,
        //     while here it requires cur >= 0.95·ref; the two contradict. It is kept as a fallback path for after constant adjustments,
        //     and its semantics are restored automatically if the BUY_TRIGGER/BUY_TARGET constants are adjusted.
        if (curPrice >= targetPrice) { todayBuyFistFinished = true; return; }

        uint256 amount = _calcBuyFistCap(targetPrice); // single buy <= 1000 USD value
        if (amount == 0) revert InsPool_FistCalcZero();

        todayBuyFistUsed += amount; // day's cumulative (statistical use; no longer the "once a day" gate)
        uint256 received = _swapFistForOsk(amount);
        // Requirement L63: once the target is met, stop supporting the market this cycle
        if (_getOskFistPrice() >= targetPrice) todayBuyFistFinished = true;
        emit FistBuyExecuted(amount, received);
    }

    /// @notice FIST market support sell: when OSK appreciates >=10% against FIST, sell OSK back for FIST
    /// @dev Target: push back down to ref + 3% (SELL_TARGET_RISE_BP).
    /// Pitfall: once per cycle -- a second call in the same cycle reverts (cycle = PERIOD_SECONDS: production 1 day / FAST_TEST 1 hour).
    function executeSellFist() external nonReentrant {
        _autoRefFist();
        uint256 curPrice = _getOskFistPrice();
        if (curPrice <= dailyRefPriceFist) revert InsPool_FistNoPump();
        uint256 dev = (curPrice - dailyRefPriceFist) * BP / dailyRefPriceFist;
        if (dev < SELL_TRIGGER_RISE_BP) revert InsPool_FistNoPump();

        uint32 day = uint32(block.timestamp / PERIOD_SECONDS);
        if (day == todaySellFistDay) revert InsPool_FistSoldToday();

        uint256 oskHeld = aToken.balanceOf(address(this));
        if (oskHeld == 0) revert InsPool_FistNoOsk();

        uint256 toSell = _calcSellFistAmount(curPrice);
        if (toSell > oskHeld) toSell = oskHeld;
        if (toSell == 0) revert InsPool_FistCalcZero();

        todaySellFistDay = day;
        uint256 received = _swapOskForFist(toSell);
        emit FistSellExecuted(toSell, received);
    }

    // ── FIST channel internals ──

    /// @dev Reset the FIST buy cycle state on a new cycle
    /// Pitfall (severe): this is the **only reset point** for `todayBuyFistFinished`. Without this reset,
    ///   after the first target is met the flag stays true forever, and the buy side would permanently revert with `InsPool_FistBuyFinished`,
    ///   violating requirement L63's cycle-loop semantics of "once the target is met, stop supporting the market that day" (the next cycle should resume market support).
    function _resetBuyFistDay(uint32 day) internal {
        todayBuyFistDay = day;
        todayBuyFistUsed = 0;
        todayBuyFistFinished = false;
    }

    /// @dev Automatic reference price maintenance (zero keeper); the first call each cycle locks that cycle's reference price
    ///      (cycle = PERIOD_SECONDS: production 24h / FAST_TEST 1h)
    /// Pitfall: the reference price snapshot must go through **deviation clamping** -- this function has no permission gate and locks on the first call each period,
    ///   so without clamping an attacker could manipulate the OSK/FIST spot reserves at a cycle boundary and race to lock in a distorted reference price,
    ///   making the protocol "support the market" at a wrong price. With clamping, a single period's reference price deviates from the previous by at most maxRefDeviationBp.
    function _autoRefFist() internal {
        if (address(oskFistPair) == address(0) || address(bToken) == address(0)) {
            revert InsPool_FistNotConfigured();
        }
        uint256 ps = _currentPeriodStart();
        if (dailyRefPriceFist != 0 && ps <= refPeriodStartFist) return;
        uint256 raw = _getOskFistPrice();
        uint256 price = _clampRefFist(raw);
        dailyRefPriceFist = price;
        refPeriodStartFist = ps;
        emit FistDailyReferenceUpdated(price, ps);
        if (price != raw) emit FistRefPriceClamped(raw, price);
    }

    /// @dev Reference price deviation clamping: relative to the previous period's reference price, a single-period change does not exceed maxRefDeviationBp
    ///      No clamping on the first period (prev == 0) or when maxRefDeviationBp == 0.
    function _clampRefFist(uint256 raw) internal view returns (uint256) {
        uint256 prev = dailyRefPriceFist;
        uint256 maxBp = maxRefDeviationBp;
        if (prev == 0 || maxBp == 0) return raw;
        uint256 hi = prev * (BP + maxBp) / BP;
        uint256 lo = prev * (BP - maxBp) / BP;
        if (raw > hi) return hi;
        if (raw < lo) return lo;
        return raw;
    }

    /// @dev Live price: "how much FIST is 1 OSK worth" = rFist × 1e18 / rOsk
    /// Pitfall: token0/token1 direction is identified dynamically -- do not assume OSK or FIST is fixed as token0.
    function _getOskFistPrice() internal view returns (uint256) {
        if (address(oskFistPair) == address(0)) revert InsPool_FistNotConfigured();
        (uint112 r0, uint112 r1,) = oskFistPair.getReserves();
        if (r0 == 0 || r1 == 0) revert InsPool_ZeroPrice();
        address t0 = oskFistPair.token0();
        uint256 rA = t0 == address(aToken) ? uint256(r0) : uint256(r1); // OSK
        uint256 rF = t0 == address(aToken) ? uint256(r1) : uint256(r0); // FIST
        if (rA == 0) revert InsPool_ZeroPrice();
        return rF * 1e18 / rA;
    }

    /// @dev CPMM exact computation + single-buy cap trimming: the FIST needed to push to targetPrice (including the slippage buffer)
    ///      Derivation: price = rFist^2/k -> rFist' = rFist × sqrt(target/cur) -> Δfist = rFist × (sqrt(ratio) - 1)
    /// Requirement L63: "a single buy is worth at most 1000 usd" -- the single-buy cap = MAX_SINGLE_BUY_USD converted into FIST amount.
    ///   Conversion source: accounting.getBPerUsd() (= how many FIST per 1 USD).
    ///   Pitfall: when accounting is not wired or the price is unavailable, it degrades to the "full in-pool FIST" cap --
    ///         which is still bounded by the CPMM exact computation (amount will not exceed what is needed to reach the target price), so it never over-supports.
    function _calcBuyFistCap(uint256 targetPrice) internal returns (uint256 amount) {
        uint256 fistHeld = bToken.balanceOf(address(this));
        if (fistHeld == 0) return 0;

        uint256 cap = fistHeld;
        if (address(accounting) != address(0)) {
            uint256 bPerUsd = accounting.getBPerUsd(); // 1 USD = N FIST
            if (bPerUsd > 0) {
                uint256 usdCap = Math.mulDiv(MAX_SINGLE_BUY_USD, bPerUsd, 1e18, Math.Rounding.Floor);
                if (usdCap < cap) cap = usdCap;
            }
        }
        todayMaxBuyFistBudget = cap; // record this single-buy cap (for observation)
        if (cap == 0) revert InsPool_FistCapReached();

        amount = _calcBuyFistAmount(targetPrice);
        if (amount > cap) amount = cap;
    }

    /// @dev CPMM exact computation: the FIST needed to pull the OSK/FIST price from the current level to target
    function _calcBuyFistAmount(uint256 targetPrice) internal view returns (uint256 fistNeeded) {
        (uint112 r0, uint112 r1,) = oskFistPair.getReserves();
        address t0 = oskFistPair.token0();
        uint256 rA = t0 == address(aToken) ? uint256(r0) : uint256(r1);
        uint256 rF = t0 == address(aToken) ? uint256(r1) : uint256(r0);
        if (rA == 0 || rF == 0) return 0;
        uint256 curPrice = rF * 1e18 / rA;
        if (targetPrice <= curPrice) return 0;
        uint256 ratio = targetPrice * 1e18 / curPrice;
        uint256 sqrtRatio = _sqrt(ratio);
        if (sqrtRatio <= 1e9) return 0;
        // Δfist = rF × (sqrt(ratio)-1), +3% buffer covers the single-hop (FIST->OSK) fee
        fistNeeded = rF * (sqrtRatio - 1e9) / 1e9 * SWAP_BUFFER_BP / BP;
    }

    /// @dev CPMM exact computation: the OSK needed to push the OSK/FIST price from the current level down to ref+3%
    ///      Derivation: price = k/rOsk^2 -> rOsk' = rOsk × sqrt(cur/target) -> Δosk = rOsk × (sqrt(ratio) - 1)
    function _calcSellFistAmount(uint256 curPrice) internal view returns (uint256 oskNeeded) {
        (uint112 r0, uint112 r1,) = oskFistPair.getReserves();
        address t0 = oskFistPair.token0();
        uint256 rA = t0 == address(aToken) ? uint256(r0) : uint256(r1);
        uint256 rF = t0 == address(aToken) ? uint256(r1) : uint256(r0);
        if (rA == 0 || rF == 0) return 0;
        uint256 cur = curPrice != 0 ? curPrice : rF * 1e18 / rA;
        uint256 targetPrice = dailyRefPriceFist * (BP + SELL_TARGET_RISE_BP) / BP;
        if (cur <= targetPrice) return 0;
        uint256 ratio = cur * 1e18 / targetPrice;
        uint256 sqrtRatio = _sqrt(ratio);
        if (sqrtRatio <= 1e9) return 0;
        oskNeeded = rA * (sqrtRatio - 1e9) / 1e9;
    }

    /// @dev FIST -> OSK market support buy (direct on the OSK/FIST pair, consistent with requirement L66's "fist->OSK coin" policy)
    function _swapFistForOsk(uint256 amount) internal returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(bToken);
        path[1] = address(aToken);
        uint256[] memory amounts = router.getAmountsOut(amount, path);
        uint256 expected = amounts[amounts.length - 1];
        uint256 minOut = expected * (BP - slippageBp) / BP;
        if (minOut == 0) revert InsPool_SweepZero();
        bToken.forceApprove(address(router), amount);
        uint256[] memory result = router.swapExactTokensForTokens(
            amount, minOut, path, address(this), block.timestamp + 30 minutes
        );
        return result[result.length - 1];
    }

    /// @dev OSK -> FIST market support sell (direct on the OSK/FIST pair)
    function _swapOskForFist(uint256 amount) internal returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(aToken);
        path[1] = address(bToken);
        uint256[] memory amounts = router.getAmountsOut(amount, path);
        uint256 expected = amounts[amounts.length - 1];
        uint256 minOut = expected * (BP - slippageBp) / BP;
        if (minOut == 0) revert InsPool_SweepZero();
        aToken.forceApprove(address(router), amount);
        uint256[] memory result = router.swapExactTokensForTokens(
            amount, minOut, path, address(this), block.timestamp + 30 minutes
        );
        return result[result.length - 1];
    }

    // ── Treasury withdrawal (callable only by Treasury, supports native BNB + any ERC20) ──
    function withdrawReserve(address token, uint256 amount) external nonReentrant {
        if (msg.sender != treasury) revert InsPool_Unauthorized();
        if (amount == 0) return;
        if (token == address(0)) {
            (bool success,) = treasury.call{value: amount}("");
            if (!success) revert InsPool_TransferFailed();
        } else {
            IERC20(token).safeTransfer(treasury, amount);
        }
        emit ReserveWithdrawn(token, treasury, amount);
    }

    // ── Internal ──
    // Note: requirement 2.0 removed all internal implementations of BNB channel market-making
    //     (_resetBuyDay/_calcBuyCap/_autoRef/_getPrice/_getPairPrice/_getWbnbPerUsd/
    //      _calcBuyAmount/_calcSellAmount/_swapBnbForAToken/_swapATokenForBnb).

    function _currentPeriodStart() internal view returns (uint256) {
        return (block.timestamp / PERIOD_SECONDS) * PERIOD_SECONDS;
    }

    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) { y = z; z = (x / z + z) / 2; }
    }

    // ── Admin: parameter timelock ──
    // Note: after the BNB channel was removed, the timelock governs only the slippageBp used by the FIST market-making channel.

    function proposeParams(uint256 _slippageBp) external onlyOwner {
        if (_slippageBp == 0 || _slippageBp > SLIPPAGE_MAX_BP) revert InsPool_BadSlippage();
        _pendingSlippageBp = _slippageBp;
        _pendingAt = block.timestamp;
        emit ParamsProposed(_slippageBp, block.timestamp + TIMELOCK_DELAY);
    }

    function executeParams() external onlyOwner {
        if (_pendingAt == 0) revert InsPool_PendingNone();
        if (block.timestamp < _pendingAt + TIMELOCK_DELAY) revert InsPool_TimelockPending();
        slippageBp = uint48(_pendingSlippageBp);
        _pendingAt = 0;
        emit ParamsExecuted(_pendingSlippageBp);
    }

    function cancelParams() external onlyOwner {
        _pendingAt = 0;
        emit ParamsCancelled();
    }

    // ── Admin: other ──

    function emergencyWithdrawToken(address token, address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert InsPool_ZeroAddress();
        if (token == address(0)) {
            (bool ok,) = to.call{value: amount}("");
            if (!ok) revert InsPool_TransferFailed();
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    // ── Requirement 2.0 L63: FIST market-making channel wiring ──
    // Pitfall: when not wired, executeBuyFist/executeSellFist revert explicitly with InsPool_FistNotConfigured,
    //       never silently trading on a wrong path -- a fund-allocation error costs far more than a failed trade.

    /// @notice Set the FIST token address (market-making payment token)
    function setBToken(address _bToken) external onlyOwner {
        if (_bToken == address(0)) revert InsPool_ZeroAddress();
        bToken = IERC20(_bToken);
        emit BTokenSet(_bToken);
    }

    /// @notice Set the OSK/FIST pair (market support target)
    function setOskFistPair(address _pair) external onlyOwner {
        if (_pair == address(0)) revert InsPool_ZeroAddress();
        oskFistPair = IPancakePair(_pair);
        emit OskFistPairSet(_pair);
    }

    /// @notice Set the FIST reference price's single-period maximum deviation (bp)
    /// @dev 0 disables clamping (not recommended). The upper bound is BP (10000) = 100%.
    function setMaxRefDeviationBp(uint256 bp) external onlyOwner {
        if (bp > BP) revert InsPool_BadRefDeviation(bp);
        maxRefDeviationBp = bp;
        emit MaxRefDeviationSet(bp);
    }

    function setAccounting(address _accounting) external onlyOwner {
        if (_accounting == address(0)) revert InsPool_ZeroAddress();
        accounting = IAccounting(_accounting);
    }

    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert InsPool_ZeroAddress();
        treasury = _treasury;
        emit TreasurySet(_treasury);
    }

    receive() external payable {}
}
