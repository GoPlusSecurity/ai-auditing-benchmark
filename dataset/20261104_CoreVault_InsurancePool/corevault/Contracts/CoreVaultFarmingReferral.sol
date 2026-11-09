// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {GlobalConfig} from "../src/core/GlobalConfig.sol";
import {YieldMath} from "../src/lib/YieldMath.sol";
import {CoreVaultFarming} from "./CoreVaultFarming.sol";

/// @title  CoreVaultFarmingReferral -- farming referral distribution
/// @notice Overrides CoreVaultFarming's virtual _onClaimYield to implement farming referral/team reward distribution.
/// @dev 3rd generation (facet split version) rewritten version -- for evidence and limitations see the top note of CoreVaultStorage.sol.
///      WARNING: key difference from the 2nd generation: **all view functions** at the end of this layer in the 2nd generation (getRefInfo /
///      positionCount / getDirectReferralAt / getDirectReferralsCount / getFarmingRaw /
///      getPositionRaw / getPositionFlags / getPositionDepositToken / getFirstRedeemStatus /
///      totalFarmingEarned / getEffectiveLevel / getFvUserMaxAndFlags /
///      getDirectReferralSummary) have **been moved out entirely** in the 3rd generation to
///      `src/core/CoreVaultViewFacet.sol`.
///      Two hard reasons:
///        (1) compile-time constraint -- `src/CoreVault.sol` keeps a same-named wrapper for every moved function;
///           if this layer still declared a same-named external function it would be a **duplicate definition** and fail to compile.
///        (2) the 2nd generation's `getFarmingRaw` relied on **hard-coded slot 45**; in the 3rd generation, after `aToken/bToken/treasury`
///           changed from immutable to storage, all slot numbers shifted, so the hard-coding necessarily breaks -- hence the 3rd generation
///           changed to **reading the mapping directly** (see the note in CoreVaultViewFacet); that fix could only occur in the file after the move.
abstract contract CoreVaultFarmingReferral is CoreVaultFarming {

  // ── Farming referral distribution override ──

  function _onClaimYield(address user, uint256 yieldUsd, uint256 avgARate)
    internal override returns (uint256, uint256)
  {
    if (!isRegistered(user) || yieldUsd == 0) return (0, 0);
    uint256 totalRewards;
    uint256 overflowPoolUsd;
    address current = _refs[user].referrer;
    address aStaking_ = address(treasury.aStaking());
    uint8 maxDL;
    unchecked {
      for (uint16 d = 0; d < GlobalConfig.MAX_TEAM_DEPTH && current != address(0); d++) {
        if (d < GlobalConfig.MAX_REFERRAL_GEN && _refs[current].validDirectCount >= d + 1) {
          uint256 rate = YieldMath.directReferralRate(uint8(d));
          if (rate > 0) {
            uint256 rUsd = Math.mulDiv(yieldUsd, rate, GlobalConfig.RATE_PRECISION, Math.Rounding.Floor);
            totalRewards += rUsd;
            uint256 payout = _payoutReferral(current, rUsd, avgARate, aStaking_);
            overflowPoolUsd += rUsd - payout;
            _fvUsers[current].earnedDirect += payout;
            emit DirectRewardAccrued(current, user, rUsd, uint8(d + 1));
          }
        }
        _checkLevelUpStaking(current);
        uint8 myLv = _refs[current].teamLevel;
        if (myLv > maxDL) {
          uint256 diff = YieldMath.teamRate(myLv) - YieldMath.teamRate(maxDL);
          uint256 tUsd = Math.mulDiv(yieldUsd, diff, GlobalConfig.RATE_PRECISION, Math.Rounding.Floor);
          if (tUsd > 0) {
            totalRewards += tUsd;
            uint256 payout = _payoutReferral(current, tUsd, avgARate, aStaking_);
            overflowPoolUsd += tUsd - payout;
            _fvUsers[current].earnedTeam += payout;
            emit TeamRewardAccrued(current, user, tUsd, myLv);
          }
          maxDL = myLv;
        }
        current = _refs[current].referrer;
      }
    }
    return (totalRewards, overflowPoolUsd);
  }

  function _payoutReferral(address user, uint256 rewardUsd, uint256 avgARate, address aStaking_)
    internal returns (uint256 payoutUsd)
  {
    uint256 remaining = _remaining3xCap(user);
    if (remaining == 0) { _markExited(user); return 0; }
    payoutUsd = rewardUsd <= remaining ? rewardUsd : remaining;
    if (rewardUsd >= remaining) _markExited(user);
    if (payoutUsd > 0) {
      unchecked {
        uint256 payoutA = Math.mulDiv(payoutUsd, avgARate, 1e18, Math.Rounding.Floor);
        uint256 taxA = Math.mulDiv(payoutA, GlobalConfig.REFERRAL_TAX_BP, GlobalConfig.RATE_PRECISION, Math.Rounding.Floor);
        uint256 netA = payoutA - taxA;
        if (netA > 0) treasury.payoutReward(user, netA);
        if (taxA > 0 && aStaking_ != address(0)) {
          treasury.payoutReward(aStaking_, taxA);
          totalAPoolRewards += taxA;
        }
      }
    }
  }

  function _remaining3xCap(address user) private view returns (uint256) {
    FvUser storage fv = _fvUsers[user];
    uint256 len = fv.positions.length;
    if (len == 0) return 0;
    Position storage p = fv.positions[len - 1];
    if (p.flags & 1 != 0) return 0;
    unchecked {
      uint256 cap = p.principalUsd * GlobalConfig.MAX_MULTIPLIER;
      uint256 consumed = p.earnedUsd
        + (fv.earnedDirect - p.snapshotDirect)
        + (fv.earnedTeam - p.snapshotTeam);
      return cap > consumed ? cap - consumed : 0;
    }
  }

  // ════════════════════════════════════════════════════════════
  //  WARNING: 3rd generation: this layer's former "farming view functions" section has been **moved out entirely** to
  //     `src/core/CoreVaultViewFacet.sol` (getRefInfo / positionCount /
  //     getDirectReferralAt / getDirectReferralsCount / getFarmingRaw /
  //     getPositionRaw / getPositionFlags / getPositionDepositToken /
  //     getFirstRedeemStatus / totalFarmingEarned / getEffectiveLevel /
  //     getFvUserMaxAndFlags / getDirectReferralSummary).
  //     The reason for the move and the two hard reasons are in this file's top @dev.
  // ════════════════════════════════════════════════════════════
}
