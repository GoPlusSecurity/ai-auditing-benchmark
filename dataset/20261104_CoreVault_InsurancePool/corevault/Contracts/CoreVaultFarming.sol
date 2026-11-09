// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OracleLib} from "../src/core/OracleLib.sol";
import {GlobalConfig} from "../src/core/GlobalConfig.sol";
import {YieldMath} from "../src/lib/YieldMath.sol";
import {CoreVaultReferral} from "./CoreVaultReferral.sol";

/// @title  CoreVaultFarming -- farming core (deposit / claim / redeem)
/// @notice Main BNB deposit, yield claim and redemption flows; referral distribution is implemented by sub-contracts via the virtual _onClaimYield.
/// @dev 3rd generation (facet split version) rewritten version -- for evidence and limitations see the top note of CoreVaultStorage.sol.
///      Differences from the 2nd generation (all backed by documentation):
///        - deposit bound validation changed from `GlobalConfig` constants to **storage variables**
///          (`_minDepositBnb`/`_maxDepositBnb`/`_minDepositUsd`/`_maxDepositUsd`) --
///          per the "change list" in `docs/03-deploy/mainnet-test-deployment-guide.md`.
///        - **fixed the `_getMcapUsd` unit/dimension error** -- per section 6 of the same document (with PoC evidence).
///      The **view functions** of this layer in the 2nd generation are not included (they were never in this layer either); views live in
///      `src/core/CoreVaultViewFacet.sol`.
///      WARNING: the inheritance base changed from the 2nd generation's `CoreVaultStaking` to **`CoreVaultReferral`** --
///      this is the precondition for the facet split to work. Evidence:
///        (1) the top comment of `src/CoreVault.sol` states two chains:
///           `CoreVault` = Storage->Admin->Referral->**Staking** + 31 forwarding wrappers;
///           `CoreVaultLogicFacet` = Storage->Admin->Referral->**Farming->FarmingReferral**.
///           If Farming still inherited Staking, LogicFacet would be forced to pull in the whole Staking layer.
///        (2) on-chain `logicFacet` (`0xca3116b0...`) measured: at runtime **14,925 B / 34 selectors**,
///           among which there are **no** `stakeA` / `stakeB` / `donateOskPool` / `donateFistPool`
///           => the real LogicFacet indeed does not contain Staking.
///        (3) this layer has **zero dependency** on Staking (verified function by function): all calls land only on
///           Storage (storage/helpers) / Admin (`_payoutStaking`) / Referral (`_checkLevelUpStaking`).
abstract contract CoreVaultFarming is CoreVaultReferral {
  // Pitfall: a Solidity using-for directive is scoped to the current contract only (not inherited by derived contracts),
  //       so this file must declare it itself; otherwise IERC20.safeTransferFrom/safeTransfer are not visible.
  using SafeERC20 for IERC20;

  /// @dev Empty virtual implementation -- the body is overridden by CoreVaultFarmingReferral
  function _onClaimYield(address, uint256, uint256) internal virtual returns (uint256, uint256) { return (0, 0); }

  /// @dev Requirements doc section 2: event emitted when the 2.5% withdrawal tax buying FIST and injecting it into the FIST staking pool fails
  event FistInjectFailed(uint256 oskAmount);

  // ── Internal helpers ──

  function _markExited(address user) internal {
    _fvUsers[user].flags |= 1;
    uint256 len = _fvUsers[user].positions.length;
    if (len > 0) {
      Position storage p = _fvUsers[user].positions[len - 1];
      if (p.flags & 1 == 0) p.flags |= 1;
    }
  }

  function _calcPendingYield(Position storage p, uint256 mcapUsd) private view returns (uint256) {
    if ((p.flags & 1) != 0 || block.timestamp <= p.lastRewardTime) return 0;
    unchecked {
      uint256 elapsed = block.timestamp - p.lastRewardTime;
      uint256 ratePerSec = YieldMath.apyPerSecond(mcapUsd, _tierUppers);
      uint256 interestUsd = YieldMath.calcInterest(p.principalUsd, ratePerSec, elapsed);
      uint256 maxEarnUsd = p.principalUsd * GlobalConfig.MAX_MULTIPLIER;
      if (p.earnedUsd >= maxEarnUsd) return 0;
      // WARNING: the **static yield is truncated here** at 3x max-out: interest stops at 3x, instead of "overflowing" the difference to aStaking.
      //   Consequence: the pendingUsd received by `_processYieldPayout` is already <= (3x - accrued),
      //        so the **static part of its overflowUsd is always 0** -- the overflow leg only absorbs the truncated referral/team difference.
      //   Evidence: Requirement L90 "static yield + team yield = 3x max-out"; client-confirmed policy on 2026-09-23.
      //   Regression: test/ThreeXMaxOutAudit.t.sol::test_Farming_3x_StaticPath_TruncatesInsteadOfOverflowing
      if (p.earnedUsd + interestUsd > maxEarnUsd) return maxEarnUsd - p.earnedUsd;
      return interestUsd;
    }
  }

  /// @dev The "LP market cap (USD)" needed for tier computation
  /// @notice WARNING: 3rd generation **fix**: the 2nd generation wrongly used **multiplication** (`ar × aPerUsd / 1e18`), with unit/dimension OSK^2/USD.
  ///   The correct conversion is **division** -- `aPerUsd` means "how many OSK per 1 USD", so USD = OSK / aPerUsd.
  /// Evidence: `docs/03-deploy/mainnet-test-deployment-guide.md` section 6 (with PoC: at a 1:1 price multiplication and division are indistinguishable,
  ///   but at real prices the error can reach 9×10^10 times, a +400% yield).
  /// Contrast (the existing correct form elsewhere in the repo, both division):
  ///   `_depositBNBCore`: bnbAmount × 1e18 / avgWbnbPerUsd
  ///   `_depositFistCore`: fistAmount × 1e18 / avgBRate
  /// Pitfall: the 2nd generation read aWbnbPair/bWbnbPair (the dual WBNB pairs); the 3rd generation price sources are now
  ///   the OSK/FIST pair + FIST/USDT pair (see OracleState in src/core/OracleLib.sol).
  ///   So here we take the OSK reserve of aOskFistPair, then convert to USD via aPerUsd.
  function _getMcapUsd() private view returns (uint256) {
    if (address(_oracle.aOskFistPair) == address(0)) return 0;
    uint256 aPerUsd = OracleLib.getAPerUsdView(_oracle);
    if (aPerUsd == 0) return 0;
    (uint112 r0, uint112 r1,) = _oracle.aOskFistPair.getReserves();
    uint256 ar = _oracle.aOskFistPair.token0() == address(aToken) ? uint256(r0) : uint256(r1);
    // Division: USD = OSK reserve / (OSK per USD)
    return Math.mulDiv(ar, 1e18, aPerUsd, Math.Rounding.Floor);
  }

  function _pendingYield(Position storage p) private returns (uint256) {
    OracleLib.updateATwap(_oracle);
    return _calcPendingYield(p, _getMcapUsd());
  }

  // ── Deposit ──

  function depositBNB(address referrer) external payable {
    _guardEnter();
    _requireValidReferrer(referrer);
    _depositBNBCore(msg.sender, msg.value, referrer);
    _guardExit();
  }

  /// @notice FIST deposit into farming (Requirement 2.0 section 2, "FIST on-chain mining mechanism 2")
  /// @dev The single-deposit bounds are defined by "gold-standard real-time USD value" -- the bounds come from the **currently effective storage variables**
  ///      (`_minDepositUsd` / `_maxDepositUsd`); production defaults to 100 - 10000 USD, and the test build lowers them via owner.
  ///      The caller must first approve fistAmount to this contract.
  /// Design intent: shares the same position/yield/3x max-out/redemption formulas with the BNB channel -- the only differences are the deposit token and the treasury-side fund allocation path,
  ///           so position principal is always converted to a USD denomination and the two channels have an identical yield policy.
  /// Pitfall: except for genesis addresses, a valid referrer must be provided -- reusing the same _requireValidReferrer as the BNB channel,
  ///       which enforces Requirement 2.0's "all users must first lock their relationship through the farming module before participating in other modules' business".
  /// Pitfall: redemption is always settled in BNB (Requirement 2.0 section 2), regardless of the deposit token.
  function depositFIST(address referrer, uint256 fistAmount) external {
    _guardEnter();
    _requireValidReferrer(referrer);
    _depositFistCore(msg.sender, fistAmount, referrer);
    _guardExit();
  }

  function _depositBNBCore(address user, uint256 bnbAmount, address referrer) internal {
    // Pitfall: read the storage variables, not the GlobalConfig constants -- otherwise the owner's setDepositBounds has no effect.
    if (bnbAmount < _minDepositBnb || bnbAmount > _maxDepositBnb) revert CoreVault_InvalidAmount();
    (uint256 spotARate,,) = OracleLib.getAllPrices(_oracle);
    (, , uint256 avgWbnbPerUsd) = OracleLib.getAccountingPrices(_oracle);
    if (avgWbnbPerUsd == 0 || spotARate == 0) revert CoreVault_PriceUnavailable();
    uint256 usdAmount = Math.mulDiv(bnbAmount, 1e18, avgWbnbPerUsd, Math.Rounding.Floor);
    // Valid-user threshold: the BNB channel is judged by **token count** (already validated above as `bnbAmount >= _minDepositBnb`) => pass 0 on the USD side.
    uint256 pid = _openPosition(user, usdAmount, spotARate, referrer, 0, 0);
    treasury.allocateDeposit{value: bnbAmount}(user, bnbAmount, 1500);
    emit BnbDeposited(user, bnbAmount, usdAmount, pid);  }

  function _depositFistCore(address user, uint256 fistAmount, address referrer) internal {
    if (fistAmount == 0) revert CoreVault_InvalidAmount();
    (uint256 spotARate, , ) = OracleLib.getAllPrices(_oracle);
    (, uint256 avgBRate, ) = OracleLib.getAccountingPrices(_oracle);
    if (spotARate == 0 || avgBRate == 0) revert CoreVault_PriceUnavailable();
    // Gold-standard pricing: FIST amount -> USD value (bPerUsd = number of FIST corresponding to 1 USD)
    uint256 usdAmount = Math.mulDiv(fistAmount, 1e18, avgBRate, Math.Rounding.Floor);
    // Pitfall: same as _depositBNBCore -- read the storage variables so the test build's small bounds take effect.
    if (usdAmount < _minDepositUsd || usdAmount > _maxDepositUsd) {
      revert CoreVault_InvalidAmount();
    }
    uint256 pid = _openPosition(user, usdAmount, spotARate, referrer, 1, GlobalConfig.VALID_USER_MIN_USD);
    // Fund allocation is executed by the treasury: 10% buys and burns FISTDAO / 20% insurance pool FIST reserve / 70% forms OSK+FIST LP
    // Pitfall: transfer FIST into the treasury first, then call -- the treasury uses "the balance before this transfer" as the baseline to sweep swap change and LP dust.
    IERC20(address(bToken)).safeTransferFrom(user, address(this), fistAmount);
    IERC20(address(bToken)).safeTransfer(address(treasury), fistAmount);
    treasury.allocateFistDeposit(user, fistAmount, GlobalConfig.LP_SLIPPAGE_BP);
    emit FistDeposited(user, fistAmount, usdAmount, pid);
  }

  /// @dev Unified position-opening pipeline (shared by the BNB / FIST channels)
  ///      Pitfall: CEI -- everything in this function is a state change (registration/quota/position/team performance), with no external calls,
  ///            so the caller can safely perform treasury fund allocation afterwards.
  /// @param validFloorUsd the USD threshold for a "valid direct referral" -- **passed per channel** (client ruling on 2026-09-27):
  ///        the BNB channel passes 0 (its lower bound is already validated by BNB **token count** in `_depositBNBCore`),
  ///        the FIST channel passes `GlobalConfig.VALID_USER_MIN_USD` (100 USD).
  ///        Pitfall: do not use a single shared USD constant for both channels -- BNB price fluctuation can make 0.1 BNB worth less than 100 USD.
  function _openPosition(
    address user, uint256 usdAmount, uint256 spotARate, address referrer,
    uint8 depositToken, uint256 validFloorUsd
  )
    internal returns (uint256 pid)
  {
    _register(user, referrer);
    FvUser storage fv = _fvUsers[user];
    bool wasExited = (fv.flags & 1) != 0;
    if (wasExited) {
      // Order-stacking rule: rebuilding after a 3x max-out requires the new order's USD amount to be **>= the principal of the last order before max-out**.
      //   Evidence: client-confirmed on 2026-09-24 -- "the user must rebuild a new order with a usd amount greater than or equal to the old order
      //         before entitlements can be restored"; same semantics as the staking side's `amount >= s.lastPrincipal` in design doc section 7.3.
      // Pitfall: must be read **before** `fv.positions.push` -- after push the last element is the new order.
      // Pitfall: must be judged before clearing the max-out flag -- use `wasExited` (set by _markExited).
      uint256 len = fv.positions.length;
      if (len > 0 && usdAmount < fv.positions[len - 1].principalUsd) revert CoreVault_InvalidAmount();
      fv.flags &= ~uint8(1);
    }
    if (fv.positions.length > 0) {
      Position storage _last = fv.positions[fv.positions.length - 1];
      if (_last.flags & 1 == 0) revert CoreVault_ActivePositionExists(fv.positions.length - 1);
    }
    pid = fv.positions.length;
    fv.positions.push(Position({
      principalUsd: usdAmount,
      principalA: Math.mulDiv(usdAmount, spotARate, 1e18, Math.Rounding.Floor),
      earnedYield: 0, earnedUsd: 0,
      lastRewardTime: block.timestamp,
      depositTime: block.timestamp,
      flags: wasExited ? 2 : 0,
      redeemableUsd: 0,
      snapshotDirect: fv.earnedDirect,
      snapshotTeam: fv.earnedTeam,
      depositToken: depositToken
    }));
    unchecked { fv.totalInvestedUsd += usdAmount; }
    _onInvest(user, usdAmount, validFloorUsd);
  }

  /// @param validFloorUsd the USD threshold for a "valid direct referral", passed per channel by `_openPosition` (see its comment).
  function _onInvest(address user, uint256 usdAmount, uint256 validFloorUsd) internal {
    if (!isRegistered(user) || usdAmount == 0) return;
    FvUser storage u = _fvUsers[user];
    uint256 prevMax = u.maxUsd;
    if (usdAmount <= prevMax) return;
    unchecked {
      uint256 delta = usdAmount - prevMax;
      u.maxUsd = usdAmount;
      bool isFirst = prevMax == 0;
      address _ref = _refs[user].referrer;
      if (_ref != address(0) && isFirst && usdAmount >= validFloorUsd) {
        if (_markFirstInvest(user)) {
          if (_refs[_ref].validDirectCount < GlobalConfig.MAX_REFERRAL_GEN) _incValidDirects(_ref);
        }
      }
      address curr = _ref;
      for (uint16 d = 0; d < GlobalConfig.MAX_TEAM_DEPTH && curr != address(0); d++) {
        _fvUsers[curr].totalTeamUsd += delta;
        if (d == 0) _fvUsers[curr].totalDirectUsd += delta;
        _checkLevelUpStaking(curr);
        curr = _refs[curr].referrer;
      }
    }
  }

  // ── Claim yield ──

  function claimYield(uint256 positionId) external {
    _guardEnter();
    _claimYieldCore(msg.sender, positionId);
    _guardExit();
  }

  function claimYieldActive() external {
    _guardEnter();
    _claimYieldCore(msg.sender, _findActivePosition(msg.sender));
    _guardExit();
  }

  function _findActivePosition(address user) internal view returns (uint256) {
    FvUser storage fv = _fvUsers[user];
    uint256 len = fv.positions.length;
    if (len == 0) revert CoreVault_NoActivePosition();
    uint256 lastIdx = len - 1;
    if (fv.positions[lastIdx].flags & 1 != 0) revert CoreVault_NoActivePosition();
    return lastIdx;
  }

  function _claimYieldCore(address user, uint256 positionId) internal {
    FvUser storage fv = _fvUsers[user];
    if (positionId >= fv.positions.length) revert CoreVault_InvalidAmount();
    Position storage p = fv.positions[positionId];
    if (p.flags & 1 != 0) revert CoreVault_InvalidAmount();
    if (block.timestamp - p.lastRewardTime < GlobalConfig.CLAIM_COOLDOWN) revert CoreVault_InvalidAmount();
    uint256 pendingUsd = _pendingYield(p);
    if (pendingUsd == 0) return;
    _processYieldPayout(user, positionId, fv, p, pendingUsd);
  }

  function _processYieldPayout(
    address user, uint256 positionId, FvUser storage fv, Position storage p, uint256 pendingUsd
  ) internal {
    uint256 totalEarnedUsd = p.earnedUsd + pendingUsd
      + (fv.earnedDirect - p.snapshotDirect)
      + (fv.earnedTeam - p.snapshotTeam);
    uint256 overflowUsd;
    if (totalEarnedUsd >= p.principalUsd * GlobalConfig.MAX_MULTIPLIER) {
      uint256 maxPayoutUsd = p.principalUsd * GlobalConfig.MAX_MULTIPLIER;
      uint256 referralDelta = (fv.earnedDirect - p.snapshotDirect) + (fv.earnedTeam - p.snapshotTeam);
      uint256 consumed = p.earnedUsd + referralDelta;
      uint256 cappedPending = consumed < maxPayoutUsd ? maxPayoutUsd - consumed : 0;
      overflowUsd = pendingUsd > cappedPending ? pendingUsd - cappedPending : 0;
      pendingUsd = cappedPending;
      p.flags |= 1;
      _markExited(user);
      emit PositionClosed(user, positionId, 1);
    }
    p.earnedUsd += pendingUsd;
    p.lastRewardTime = block.timestamp;
    (uint256 avgARate,,) = OracleLib.getAccountingPrices(_oracle);
    if (avgARate == 0) revert CoreVault_PriceUnavailable();
    uint256 payoutA = Math.mulDiv(pendingUsd, avgARate, 1e18, Math.Rounding.Floor);
    unchecked { p.earnedYield += payoutA; fv.totalEarned += payoutA; }
    (, uint256 overflowFromClaim) = _onClaimYield(user, pendingUsd, avgARate);
    overflowUsd += overflowFromClaim;
    uint256 fee = Math.mulDiv(payoutA, GlobalConfig.FEE_BP_TOTAL, GlobalConfig.RATE_PRECISION, Math.Rounding.Floor);
    // Requirement 2.0 section 2, farming rule 1: 5% withdrawal tax = "2.5% buys FIST and injects it into the FIST staking pool" + "2.5% goes to the five mining pool nodes split equally".
    // Pitfall: use the named constants (FEE_BP_ASTAKING / FEE_BP_WALLET2) rather than a hard-coded `fee / 2` --
    //   so the split policy is traceable and separately adjustable, and stays consistent with the GlobalConfig SSOT.
    //   Numerically floor(fee × 250 / 500) is bit-for-bit equivalent to `fee / 2` and does not change existing behavior.
    uint256 toFistPool = Math.mulDiv(fee, GlobalConfig.FEE_BP_ASTAKING, GlobalConfig.FEE_BP_TOTAL, Math.Rounding.Floor);
    uint256 toFeewallet1 = fee - toFistPool;
    uint256 net = payoutA - fee;
    if (net > 0) treasury.payoutReward(user, net);
    // Requirements doc section 2: 2.5% withdrawal tax -> buy OSK->USDT->FIST and inject into the FIST staking pool (only via FIST/USDT, the deepest liquidity)
    // Pitfall: use try/catch to keep yield claiming available -- an external DEX failure should not block the user's claim; but a failure event must be emitted, not silently swallowed.
    if (toFistPool > 0) {
      try treasury.swapOskToFistAndInject(toFistPool, GlobalConfig.LP_SLIPPAGE_BP) {}
      catch { emit FistInjectFailed(toFistPool); }
    }
    // Requirement 2.0 section 2: 2.5% withdrawal tax -> equal dividend to the five mining pool nodes
    // Wiring: feewallet1 must point to the 5-node dividend distribution contract (i.e. BWalletDistributor5 of the pangu project),
    //       which splits the OSK equally among the 5 mining pool nodes; this contract only transfers out the 2.5% in the original token and does no node management.
    if (toFeewallet1 > 0 && feewallet1 != address(0)) treasury.payoutReward(feewallet1, toFeewallet1);
    // Node requirements doc section 1, entitlements: 30% of network-wide static revenue is injected into the node mining pool -> NodePoolDistributor four-pool weighting 5/5/10/10.
    // Policy (confirmed): it is an **additional** expense (1.0 "200% gross expense"), not deducted from the user's share, and **does not participate** in 3x max-out accounting.
    // Pitfall: the accrual base uses the **pendingUsd actually confirmed paid** for this claim (i.e. the value after 3x max-out trimming) --
    //   the node pool should not share revenue that was "never paid to the user", otherwise the node leg would exceed the real 30% of static revenue.
    // Implementation: **shared with the staking module** via `CoreVaultStorage::_payoutNodePoolLeg` -- to avoid the two modules' policies diverging.
    _payoutNodePoolLeg(pendingUsd, avgARate);
    // The "overflow" part of 3x max-out -> aStaking staking pool.
    // WARNING: reachability (verified 2026-09-23): this branch **only carries the difference** by which referral/team rewards were truncated by `_remaining3xCap`
    //   (i.e. the overflowFromClaim returned by `_onClaimYield`). **Static yield produces no overflow** --
    //   `_calcPendingYield` already truncates it at the 3x boundary to `principal×3 - accrued`, so here
    //   `pendingUsd <= cappedPending` always holds -> the static part contributes 0.
    //   Semantics: static yield is "interest stops at 3x", not "overflow to aStaking".
    //   Regression: test/ThreeXMaxOutAudit.t.sol's
    //     - test_Farming_3x_StaticPath_TruncatesInsteadOfOverflowing (zero static overflow)
    //     - test_Farming_3x_OverflowFromReferralTruncation        (referral-truncation overflow reachable)
    if (overflowUsd > 0 && address(treasury.aStaking()) != address(0)) {
      uint256 overflowA = Math.mulDiv(overflowUsd, avgARate, 1e18, Math.Rounding.Floor);
      treasury.payoutReward(treasury.aStaking(), overflowA);
      totalAPoolRewards += overflowA;
    }
    emit YieldClaimed(user, positionId, net);
  }

  // ── Redemption ──

  function redeemPrincipal(uint256 positionId) external {
    _guardEnter();
    _redeemPrincipalCore(msg.sender, positionId);
    _guardExit();
  }

  function redeemPrincipalActive() external {
    _guardEnter();
    _redeemPrincipalCore(msg.sender, _findActivePosition(msg.sender));
    _guardExit();
  }

  function _redeemPrincipalCore(address user, uint256 positionId) internal {
    FvUser storage fv = _fvUsers[user];
    if (positionId >= fv.positions.length) revert CoreVault_InvalidAmount();
    // Requirement 2.0 section 2: in the farming module **only the first order (pid=0) participates in the redemption mechanism**, and **the first-order entitlement is permanently exhausted**.
    //   -- Each address gets only one redemption opportunity in its lifetime; whether the first order is closed by active redemption or by 3x max-out,
    //      the entitlement never regenerates, and all subsequently rebuilt orders (pid>=1) are never redeemable. This is a hard constraint of the economic model.
    // Pitfall: do not rely on Position.flags -- that flag is only set when "redeemable amount = 0",
    //       which would let rebuilt orders silently become redeemable while yield has not exceeded 50% of principal, conflicting with "permanently exhausted".
    if (!_isFirstPosition(positionId)) revert CoreVault_NotFirstPosition(positionId);
    Position storage p = fv.positions[positionId];
    if (p.flags & 1 != 0) revert CoreVault_InvalidAmount();
    if (p.flags & 2 != 0) revert CoreVault_InvalidAmount();
    if (block.timestamp < p.depositTime + GlobalConfig.LOCKUP_MIN) revert CoreVault_InvalidAmount();
    uint256 pendingUsd = _pendingYield(p);
    if (pendingUsd > 0) {
      _processYieldPayout(user, positionId, fv, p, pendingUsd);
      if (p.flags & 1 != 0) return;
    }
    p.lastRewardTime = block.timestamp;
    uint256 totalEarnedUsd;
    unchecked {
      totalEarnedUsd = p.earnedUsd
        + (fv.earnedDirect - p.snapshotDirect) + (fv.earnedTeam - p.snapshotTeam);
      if (totalEarnedUsd >= p.principalUsd * GlobalConfig.MAX_MULTIPLIER || p.earnedUsd >= p.principalUsd) {
        p.flags |= 1; _markExited(user);
        emit PositionClosed(user, positionId, 2);
        return;
      }
    }
    uint256 redeemableUsd = YieldMath.redeemablePrincipal(p.principalUsd, totalEarnedUsd);
    if (redeemableUsd == 0) { p.flags |= 2; return; }
    p.flags |= 1;
    p.redeemableUsd = redeemableUsd;
    (,, uint256 wbnbPerUsd) = OracleLib.getAccountingPrices(_oracle);
    if (wbnbPerUsd == 0) revert CoreVault_PriceUnavailable();
    uint256 bnbAmount = Math.mulDiv(redeemableUsd, wbnbPerUsd, 1e18, Math.Rounding.Floor);
    treasury.payoutBnb(user, bnbAmount);
    emit PrincipalRedeemed(user, positionId, redeemableUsd);
  }
}
