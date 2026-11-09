// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {OracleLib} from "../src/core/OracleLib.sol";
import {GlobalConfig} from "../src/core/GlobalConfig.sol";
import {YieldMath} from "../src/lib/YieldMath.sol";
import {CoreVaultAdmin} from "./CoreVaultAdmin.sol";

/// @title  CoreVaultReferral -- referral & team system
/// @notice Contains referral registration validation, team performance tracking, level promotion, and staking referral reward distribution.
/// @dev 3rd generation (facet split version) rewritten version -- for evidence and limitations see the top note of CoreVaultStorage.sol.
///      This file is **byte-for-byte identical** to the 2nd generation (blob fa821992d...) -- on-chain selector checks found no external
///      function additions or removals in this layer, and the per-pool semantics of `_checkStakingMaxOut` match its `src/` callers exactly.
abstract contract CoreVaultReferral is CoreVaultAdmin {

  // ════════════════════════════════════════════════════════════
  //  Staking performance tracking (writes to _modA / _modB)
  // ════════════════════════════════════════════════════════════

  function _updateTeamPerf(address user, uint256 usdAmount, TokenType t) internal {
    if (!isRegistered(user) || usdAmount == 0) return;
    mapping(address => ModValues) storage mods = (t == TokenType.A) ? _modA : _modB;
    ModValues storage m = mods[user];
    if (usdAmount <= m.maxUsd) return;
    unchecked {
      uint256 delta = usdAmount - m.maxUsd;
      m.maxUsd = usdAmount;
      bool isFirst = m.maxUsd == usdAmount && usdAmount == delta;
      address _ref = _refs[user].referrer;
      // Valid-user threshold (client ruling on 2026-09-27): this pool's staking lower bound is already validated at the `stakeA` / `stakeB`
      //   entry by **token count** (`MIN_STAKE_A` / `MIN_STAKE_B`, both 100 tokens), so no USD threshold is **layered on** here.
      // Pitfall: the previous single USD constant (`VALID_USER_MIN_USDT`) test would misjudge qualifying small stakes as invalid direct referrals
      //   (a token's USD value fluctuates with price, a different dimension from the "token-count lower bound").
      if (_ref != address(0) && isFirst) {
        if (_markFirstInvest(user)) {
          if (_refs[_ref].validDirectCount < GlobalConfig.MAX_REFERRAL_GEN) _incValidDirects(_ref);
        }
      }
      address curr = _ref;
      for (uint16 d = 0; d < GlobalConfig.MAX_TEAM_DEPTH && curr != address(0); d++) {
        ModValues storage cm = mods[curr];
        cm.teamUsd += delta;
        if (d == 0) cm.directUsd += delta;
        _checkLevelUpStaking(curr);
        curr = _refs[curr].referrer;
      }
    }
  }

  function _checkLevelUpStaking(address user) internal {
    uint8 curLv = _refs[user].teamLevel;
    if (curLv >= 9) return;
    uint8 nl = _effectiveLevel(user);
    if (nl > curLv) _syncLevel(user, nl);
  }

  // ════════════════════════════════════════════════════════════
  //  Staking reward distribution (direct referral / team differential)
  // ════════════════════════════════════════════════════════════

  function _distributeStakingRewards(address user, uint256 reward, TokenType t) internal {
    if (!isRegistered(user)) return;
    uint256 taxTotal = _distributeStakingLoop(user, reward, t);
    if (taxTotal > 0) {
      if (t == TokenType.A) totalAPoolRewards += taxTotal;
      else totalBPoolRewards += taxTotal;
    }
    // ── Node mining pool 30% dividend leg (system 2) -- the staking module also accrues it ──
    // Client-confirmed on 2026-09-23: coverage was expanded from "farming only" to "farming + staking".
    //   Evidence: `node-requirements-doc.txt` uses the wording "**network-wide** static revenue" (founder 5 / co-founder 5 / sponsor 10 / operation 10),
    //         while `development-requirements-doc-2.0.md:134-140` defines team rewards as "X% of **static revenue**",
    //         confirming that staking 7%/cycle is "static revenue" -> all three modules fall under "network-wide static revenue".
    // Base: the **USD equivalent** of this static yield. Pool A (OSK) yield is in OSK, pool B (FIST) yield is in FIST.
    // Token: `NodePoolDistributor` is **single-token immutable = OSK**, so pool B must be converted by value into OSK when transferred out:
    //         rewardUsd = reward × 1e18 / rate;  nodePoolOsk = rewardUsd × 30% × avgARate / 1e18.
    // Pitfall: the standard token->USD direction is `amount × 1e18 / rate` (same form as CoreVaultStaking.sol:55);
    //       never write `amount × rate / 1e18` -- that is the reverse USD->token direction and yields an off-by-orders-of-magnitude result.
    // Policy consistent with farming: additional expense (does not consume the user's 100%), does not participate in 3x max-out accounting, silently skipped when not wired.
    //   Regression: test/StakingNodePoolLeg.t.sol
    if (reward > 0) {
      (uint256 avgARate, uint256 avgBRate,) = OracleLib.getAccountingPrices(_oracle);
      uint256 rate = (t == TokenType.A) ? avgARate : avgBRate;
      uint256 rewardUsd = Math.mulDiv(reward, 1e18, rate, Math.Rounding.Floor);
      _payoutNodePoolLeg(rewardUsd, avgARate);
    }
  }

  function _distributeStakingLoop(address user, uint256 reward, TokenType t)
    internal returns (uint256 taxTotal)
  {
    uint256 dirRem = Math.mulDiv(reward, 3000, GlobalConfig.RATE_PRECISION, Math.Rounding.Floor);
    uint256 teamPool = Math.mulDiv(reward, 7000, GlobalConfig.RATE_PRECISION, Math.Rounding.Floor);
    uint256 teamRem = teamPool;
    uint256 redirected; // amount retained in this pool because the upline has no valid stake (original token, gross before tax)
    address current = _refs[user].referrer;
    uint8 maxDL;
    unchecked {
      for (uint16 d = 0; d < GlobalConfig.MAX_TEAM_DEPTH && current != address(0) && (dirRem > 0 || teamRem > 0); d++) {
        address upline = current;
        // Requirement (2026-09-26): an upline must have a **valid stake** in this pool to claim this pool's dynamic yield.
        //   Uplines who have not staked (farming only) / have maxed out (3x max-out clears orders) receive nothing, and their amount is **retained in this pool**
        //   to strengthen redemption capacity (no longer passed further up).
        // Note: a maxed-out user's order has been deleted => _hasValidStake is always false, so no separate rightsClosed case is needed.
        // Note: their level **still** participates in the maxDL differential chain computation -- to keep higher uplines' differential base from being wrongly raised
        //   (if the level were skipped too, higher uplines would receive excess differential).
        bool eligible = _hasValidStake(upline, t);
        {
          if (d < GlobalConfig.MAX_REFERRAL_GEN && dirRem > 0 && _refs[upline].validDirectCount >= d + 1) {
            uint256 rate = YieldMath.directReferralRate(uint8(d));
            if (rate > 0) {
              uint256 rA = Math.mulDiv(reward, rate, GlobalConfig.RATE_PRECISION, Math.Rounding.Floor);
              if (rA > dirRem) rA = dirRem;
              if (eligible) {
                uint256 net = Math.mulDiv(rA, GlobalConfig.REFERRAL_NET_BP, GlobalConfig.RATE_PRECISION, Math.Rounding.Floor);
                _payoutStaking(upline, net, t);
                _modEarnedDirect[upline] += net;
                _modEarnedDirectByPool[upline][t] += net; // measured per pool, for the 3x max-out determination
                taxTotal += rA - net;
                emit DirectRewardAccrued(upline, user, rA, uint8(d + 1));
              } else {
                // no valid stake -> skip payout, amount retained in this pool (not passed further up)
                redirected += rA;
                emit StakingRewardRedirected(upline, user, rA, t, 0);
              }
              dirRem -= rA;
            }
          }
        }
        {
          uint8 myLv = _refs[upline].teamLevel;
          if (myLv > maxDL) {
            uint256 diff = YieldMath.teamRate(myLv) - YieldMath.teamRate(maxDL);
            uint256 tA = Math.mulDiv(teamPool, diff, 7000, Math.Rounding.Floor);
            if (tA > teamRem) tA = teamRem;
            if (tA > 0) {
              if (eligible) {
                uint256 net = Math.mulDiv(tA, GlobalConfig.REFERRAL_NET_BP, GlobalConfig.RATE_PRECISION, Math.Rounding.Floor);
                _payoutStaking(upline, net, t);
                _modEarnedTeam[upline] += net;
                _modEarnedTeamByPool[upline][t] += net; // measured per pool, for the 3x max-out determination
                emit TeamRewardAccrued(upline, user, tA, myLv);
                taxTotal += tA - net;
              } else {
                // no valid stake -> skip payout, amount retained in this pool (the level still advances maxDL, see above)
                redirected += tA;
                emit StakingRewardRedirected(upline, user, tA, t, 1);
              }
              teamRem -= tA;
            }
            maxDL = myLv;
          }
        }
        // Requirement 2.0 sections 3/4: when a V1-or-above user's dynamic yield reaches 3x principal -> immediate max-out
        //   Pitfall: must come after this round's distribution -- pay out first, then judge, otherwise this round's yield would be under-counted/under-paid.
        if (_refs[upline].teamLevel >= GlobalConfig.MIN_MAXOUT_TEAM_LEVEL) {
          _checkStakingMaxOut(upline, t);
        }
        current = _refs[upline].referrer;
      }
    }
    // Retained in this pool: the reward is no longer transferred out and simply stays in this contract's balance -> strengthens that pool's redemption reserve; the counter is for audit only.
    if (redirected > 0) {
      if (t == TokenType.A) _redirectedToPoolA += redirected;
      else _redirectedToPoolB += redirected;
    }
  }

  // ════════════════════════════════════════════════════════════
  //  Requirement 2.0 sections 3/4: staking 3x max-out (V1+ only)
  // ════════════════════════════════════════════════════════════

  /// @dev Determine and execute a staking max-out (**per pool, independently**)
  /// @notice Trigger conditions (both must hold):
  ///   1) team level >= MIN_MAXOUT_TEAM_LEVEL (V1) -- users without a V level are **not subject** to the 3x max-out limit;
  ///   2) this pool's dynamic yield >= this pool's unsettled order principal × MAX_MULTIPLIER.
  /// @dev Policy (client-confirmed on 2026-09-23): the requirements' "team yield" = **9-generation direct referral reward + 7-level team reward**,
  ///      so dynamic here is `_modEarnedDirectByPool + _modEarnedTeamByPool` (the sum of both),
  ///      and both are **net (80%)** -- the 20% tax does not enter the personal accumulation.
  ///      Regression: test/ThreeXMaxOutAudit.t.sol::test_Staking_3x_UsesNetDynamic.
  /// Max-out actions: close **this pool's** orders (active + ready), **principal is not refunded**, close **this pool's** dynamic yield entitlement;
  ///           **this pool's already-generated static yield is deferred**, to be paid to the user when they rebuild a new position in this pool.
  /// Pitfall (severe): only the orders and entitlements of the passed pool t may be closed --
  ///   when an OSK stake meets the max-out condition, it must not affect the FIST stake or the farming module (the three compute performance independently).
  /// Pitfall: principal not refunded = do not call _payoutStaking, keeping the funds in this contract as a redemption reserve;
  ///       but _totalPoolA/_totalPoolB must be decremented in sync -- the principal has left the user's order, and not decrementing would overstate the pool accounting.
  /// Pitfall: the principal base uses active.principal + ready.principal (all unsettled orders of this pool), not just active,
  ///       otherwise the principal in ready would become a blind spot in the max-out determination.
  function _checkStakingMaxOut(address user, TokenType t) internal returns (bool exited) {
    StakeState storage s = (t == TokenType.A) ? _aStakes[user] : _bStakes[user];
    uint256 principal = s.active.principal + s.ready.principal;
    if (principal == 0) return false;
    uint256 dynamic = _dynamicEarnedByPool(user, t);
    if (dynamic < principal * GlobalConfig.MAX_MULTIPLIER) return false;

    // ── Requirement 2.0: static yield deferral (orders are closed but yield is not destroyed; paid when a new position is rebuilt) ──
    //   Policy exactly matches _unlockReady: use the shared _orderStaticYield to avoid the deferral/settlement policies diverging.
    //   Pitfall: must be computed before delete -- after deletion all order fields are zeroed and the yield can no longer be computed.
    //   Pitfall: for an order that has not completed a full cycle, the yield is 0 under the "per-cycle" rule (consistent with the existing locked behavior).
    uint256 deferred = _orderStaticYield(s.active.principal, s.active.endTime)
                     + _orderStaticYield(s.ready.principal, s.ready.endTime);
    if (deferred > 0) {
      unchecked { s.pendingStaticYield += deferred; }
      emit StakingYieldDeferred(user, t, deferred);
    }

    // ── Max-out: principal not refunded, this pool's orders closed ──
    (uint256 avgARate, uint256 avgBRate,) = OracleLib.getAccountingPrices(_oracle);
    uint256 rate = (t == TokenType.A) ? avgARate : avgBRate;
    if (rate > 0) {
      uint256 poolUsd = Math.mulDiv(principal, 1e18, rate, Math.Rounding.Floor);
      if (t == TokenType.A) {
        if (poolUsd < _totalPoolA) _totalPoolA -= poolUsd; else _totalPoolA = 0;
      } else {
        if (poolUsd < _totalPoolB) _totalPoolB -= poolUsd; else _totalPoolB = 0;
      }
    }
    delete s.active;
    delete s.ready;
    // Only close **this pool's** entitlement bit (A->bit2 / B->bit3); the other pool's entitlement bit stays as is
    _refs[user].flags |= _stakeRightsBit(t);
    emit StakingMaxOut(user, t, principal, dynamic);
    return true;
  }
}
