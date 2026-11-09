// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OracleLib} from "../src/core/OracleLib.sol";
import {GlobalConfig} from "../src/core/GlobalConfig.sol";
import {CoreVaultReferral} from "./CoreVaultReferral.sol";

/// @title  CoreVaultStaking -- staking core logic
/// @notice stakeA/stakeB entry points, staking cycle management, yield calculation, unlock, fuel fee injection, donation.
/// @dev 3rd generation (facet split version) rewritten version -- for evidence and limitations see the top note of CoreVaultStorage.sol.
///      WARNING: key difference from the 2nd generation: **all staking view functions have been moved out** to
///      `src/core/CoreVaultViewFacet.sol`. Reason (compile-time hard constraint): `src/CoreVault.sol` keeps a **same-named wrapper**
///      for every moved function (`activeOrder` / `getModValues` / `getTotalPoolA` ...);
///      if this layer still kept a same-named `external` function, it would be a **duplicate definition** and fail to compile.
///      So this file keeps only "state-change logic" and declares no views at all.
abstract contract CoreVaultStaking is CoreVaultReferral {
  using SafeERC20 for IERC20;

  // ════════════════════════════════════════════════════════════
  //  Staking core
  // ════════════════════════════════════════════════════════════

  function _stakeCore(address user, uint256 amount, address referrer, TokenType t) internal {
    StakeState storage s = (t == TokenType.A) ? _aStakes[user] : _bStakes[user];
    if (t == TokenType.A) {
      if (amount < GlobalConfig.MIN_STAKE_A || amount > GlobalConfig.MAX_STAKE_A) revert CoreVault_InvalidAmount();
    } else {
      if (amount < GlobalConfig.MIN_STAKE_B || amount > GlobalConfig.MAX_STAKE_B) revert CoreVault_InvalidAmount();
    }
    bool hasActive = (s.active.flags & 1) != 0;
    if (hasActive) {
      if (block.timestamp < s.active.endTime) revert CoreVault_InvalidAmount();
      if (amount < s.active.principal) revert CoreVault_InvalidAmount();
    }
    (uint256 spotARate, uint256 spotBRate,) = OracleLib.getAllPrices(_oracle);
    (uint256 avgARate, uint256 avgBRate,) = OracleLib.getAccountingPrices(_oracle);
    if (spotARate == 0 || spotBRate == 0) revert CoreVault_PriceUnavailable();
    _register(user, referrer);
    // Requirement 2.0: rebuilding a new order in this pool restores **this pool's** dynamic yield entitlement and zeroes this pool's dynamic yield accumulation.
    // Pitfall: without zeroing, the leftover 3x dynamic yield would immediately trigger another max-out on the next distribution, and the user could not truly restore entitlements.
    // Pitfall (severe): only touch this pool's (t) entitlement bit and accumulation -- the other pool's orders/entitlements/accumulation are completely unaffected
    //   (OSK and FIST staking performance are independent, and max-out in one does not implicate the other).
    if (_stakingRightsClosed(user, t)) {
      // Design doc section 7.3 "order-stacking rule": rebuilding after max-out requires the new order amount to be **>= the principal of the last order before max-out**.
      //   Evidence: design doc section 7.3 "rebuild after max-out: check amount >= s.lastPrincipal (not cleared by delete,
      //         retains the principal of the last order before max-out)".
      // Pitfall: this check must be **before clearing the entitlement bit** -- use `_stakingRightsClosed` to judge "whether in a maxed-out state".
      // Pitfall: use `s.lastPrincipal`, not `s.active.principal` -- active has already been deleted at max-out.
      if (amount < s.lastPrincipal) revert CoreVault_InvalidAmount();
      _refs[user].flags &= ~_stakeRightsBit(t);
      _modEarnedDirectByPool[user][t] = 0;
      _modEarnedTeamByPool[user][t] = 0;
      emit StakingRightsRestored(user, t);
    }
    uint256 perfRate = (t == TokenType.A) ? avgARate : avgBRate;
    if (perfRate == 0) revert CoreVault_PriceUnavailable();
    unchecked {
      uint256 usdVal = Math.mulDiv(amount, 1e18, perfRate, Math.Rounding.Floor);
      if (t == TokenType.A) _totalPoolA += usdVal; else _totalPoolB += usdVal;
      _updateTeamPerf(user, usdVal, t);
    }
    bool hasReady = false;
    if (hasActive) {
      if ((s.ready.flags & 1) != 0) _unlockReady(user, s, t);
      s.ready = s.active; s.active.flags = 0; hasReady = true;
    }
    s.active = Order({principal: amount, startTime: block.timestamp, endTime: block.timestamp + GlobalConfig.CYCLE, flags: 1});
    // Design doc section 7.3: record this order's principal as the amount baseline for **the next rebuild after max-out**.
    //   Updated on every successful order creation (including full-cycle rebuilds), so the baseline moves forward with the latest order.
    s.lastPrincipal = amount;
    emit Staked(user, amount, block.timestamp + GlobalConfig.CYCLE, t);
    if (hasReady) _unlockReady(user, s, t);
    // Requirement 2.0: static yield deferred at max-out is paid out to the user when a **new position is rebuilt**.
    // Pitfall: must come after all state changes (CEI) -- it contains an external token transfer internally.
    // Pitfall: pay per pool -- only this pool's (t) deferred value is paid; the other pool's deferred value is unaffected.
    _payPendingStaticYield(user, s, t);
  }

  /// @dev Pay out static yield deferred at max-out
  /// @notice Called only when a **new position is rebuilt** in this pool (Requirement 2.0: static yield is triggered to the user on creating a new position).
  /// Pitfall: zero first, then transfer (CEI) -- prevents reentrancy-caused duplicate payouts.
  /// Pitfall: on insufficient balance **revert explicitly** rather than silently skipping -- the user's static yield must not be lost;
  ///       better to fail this stake and expose the reserve problem than to silently swallow user assets.
  function _payPendingStaticYield(address user, StakeState storage s, TokenType t) internal {
    uint256 pending = s.pendingStaticYield;
    if (pending == 0) return;
    s.pendingStaticYield = 0;
    _payoutStaking(user, pending, t);
    emit StakingYieldPaid(user, t, pending);
  }

  function _calcReward(uint256 principal, uint256 end) private view returns (uint256) {
    // Per-cycle yield = principal × 7% (requirements doc: daily yield 0.7% × 10 days/cycle)
    // [Confirmed] Staking is per-cycle and accrues no interest beyond the cycle: returns 0 before a full cycle; after a full cycle the yield is always 7%,
    //           not accrued per day for overtime, and no compounding. Not reading elapsed here is the implementation guarantee of that rule.
    // Pitfall: the denominator is uniformly RATE_PRECISION (1e4), bit-for-bit equivalent to the old implementation mulDiv(p,7000,100000).
    // Pitfall: delegate uniformly to the shared base _orderStaticYield -- max-out deferral and unlock settlement must use the same policy,
    //       otherwise the deferred value could differ from the settlement value (policy divergence).
    return _orderStaticYield(principal, end);
  }

  function _unlockReady(address user, StakeState storage s, TokenType t) internal {
    Order memory r = s.ready;
    if (block.timestamp < r.endTime) revert CoreVault_InvalidAmount();
    uint256 reward = _calcReward(r.principal, r.endTime);
    uint256 total = r.principal + reward;
    s.totalEarned += reward;
    (uint256 avgARate, uint256 avgBRate,) = OracleLib.getAccountingPrices(_oracle);
    unchecked {
      uint256 poolUsd = Math.mulDiv(r.principal, 1e18,
        t == TokenType.A ? avgARate : avgBRate, Math.Rounding.Floor);
      if (t == TokenType.A) {
        if (poolUsd < _totalPoolA) _totalPoolA -= poolUsd; else _totalPoolA = 0;
      } else {
        if (poolUsd < _totalPoolB) _totalPoolB -= poolUsd; else _totalPoolB = 0;
      }
    }
    delete s.ready;
    emit Unlocked(user, r.principal, reward, t);
    _payoutStaking(user, total, t);
    if (reward > 0) _distributeStakingRewards(user, reward, t);
  }

  // ════════════════════════════════════════════════════════════
  //  Staking external entry points
  // ════════════════════════════════════════════════════════════

  /// @notice OSK staking (Requirement 2.0 section 4)
  /// @dev Fuel fee policy (Requirement 2.0 section 4, staking rule 2 "2% of the staking amount in FIST is injected into the FIST staking mining pool"):
  ///      charged at 2% in the **opposite token** (FIST) by USD equivalent, and **deducted additionally from the user's wallet** -- the staking principal is untouched.
  ///      Destination: FIST is injected into the FIST staking mining pool on receipt (this contract's bToken balance is that pool's redemption reserve).
  ///      Word-for-word consistent with sections 7.1/7.2 of the design doc `docs/02-design/fund-flow-and-implementation-details.md`.
  /// Pitfall: a farming position must already exist to count as **having locked the relationship through farming**; checking only the referrer cannot stop the first user from staking directly.
  ///       The gate is placed before transferFrom to avoid invalid approvals and transfers (Requirement 2.0 section 5).
  /// Pitfall: the principal (OSK) and the fuel (FIST) are **two different tokens**, so two transferFrom calls are needed and the user must approve each separately --
  ///       they cannot be merged into one (the old implementation merged them as the same token, the opposite of the requirement policy).
  function stakeA(uint256 amount) external {
    _guardEnter();
    if (_fvUsers[msg.sender].positions.length == 0) revert CoreVault_NoReferrer();
    _requireValidReferrer(_refs[msg.sender].referrer);
    if (amount < GlobalConfig.MIN_STAKE_A || amount > GlobalConfig.MAX_STAKE_A) revert CoreVault_InvalidAmount();
    uint256 fee = _stakeFeeInOpposite(amount); // charged in FIST
    IERC20(address(aToken)).safeTransferFrom(msg.sender, address(this), amount);
    IERC20(address(bToken)).safeTransferFrom(msg.sender, address(this), fee);
    // CEI: settle all staking state and reward distribution first, then do the fuel fee injection's external interaction
    _stakeCore(msg.sender, amount, _refs[msg.sender].referrer, TokenType.A);
    _injectStakeFeeToFistPool(msg.sender, fee);
    _guardExit();
  }

  /// @notice FIST staking (Requirement 2.0 section 3)
  /// @dev Fuel fee policy (**client change on 2026-09-26**): charged at 2% in the **staking token itself** (FIST),
  ///      deducted additionally from the user's wallet -- the staking principal is untouched (staking 100 FIST deducts another 2 FIST).
  ///      Destination: transfer to treasury -> half of the FIST is swapped to OSK -> remaining FIST + obtained OSK form OSK/FIST LP -> insurance pool.
  ///      Policy **differs** from stakeA: stakeA is still charged in the opposite token (FIST), while stakeB is charged in the same token,
  ///      so stakeB **needs no oracle conversion** (pure token count × 2%).
  /// Pitfall: same gate as stakeA -- validate the referral relationship before pulling funds.
  /// Pitfall: principal and fuel are both FIST, merged into a single transferFrom(amount + fee) -- no need for two approvals/two transfers.
  function stakeB(uint256 amount) external {
    _guardEnter();
    if (_fvUsers[msg.sender].positions.length == 0) revert CoreVault_NoReferrer();
    _requireValidReferrer(_refs[msg.sender].referrer);
    if (amount < GlobalConfig.MIN_STAKE_B || amount > GlobalConfig.MAX_STAKE_B) revert CoreVault_InvalidAmount();
    uint256 fee = _stakeFeeSame(amount); // charged at 2% in FIST
    IERC20(address(bToken)).safeTransferFrom(msg.sender, address(this), amount + fee);
    // CEI: settle all staking state and reward distribution first, then do the fuel fee injection's external interaction
    _stakeCore(msg.sender, amount, _refs[msg.sender].referrer, TokenType.B);
    _injectStakeFeeToOskLp(msg.sender, fee);
    _guardExit();
  }

  /// @dev Client change on 2026-09-26: the FIST staking fuel fee is changed to be charged at 2% in the **same token** (FIST).
  ///      Policy: fee = amount × STAKE_FEE_BP / RATE_PRECISION (pure token count, no oracle conversion).
  /// Pitfall: do not go through `_stakeFeeInOpposite` again -- that would charge in the opposite token (OSK), the opposite of the changed policy;
  ///       when OSK is very cheap, that opposite-token fuel fee balloons to thousands of times the principal (measured ~3093 OSK / 1 FIST).
  function _stakeFeeSame(uint256 amount) internal pure returns (uint256) {
    return Math.mulDiv(amount, GlobalConfig.STAKE_FEE_BP, GlobalConfig.RATE_PRECISION, Math.Rounding.Floor);
  }

  /// @dev Requirement 2.0 section 4, staking rule 2: the fuel fee for OSK(A) staking = 2% of the staking amount, charged in the **opposite token** (FIST).
  ///      Conversion policy (USD equivalent, same source as `_stakeCore`'s performance pricing, see design doc section 7.2):
  ///        stakeA(OSK) -> FIST : fee = amount × STAKE_FEE_BP/1e4 × avgBRate / avgARate
  ///      where avgARate = how many OSK per 1 USD, avgBRate = how many FIST per 1 USD.
  ///      Derivation: amount / avgRate = USD value; × 2% = fuel USD; × opposite avgRate = opposite token count.
  /// Note: only stakeA uses this function; stakeB was changed on 2026-09-26 to charge in the same token (see `_stakeFeeSame`).
  /// Pitfall: a **unit/dimension conversion** is required rather than using amount directly -- the requirement prices in the opposite token, and OSK has 18 decimals
  ///       while FIST has 6, so the two cannot be mixed (using it directly would make the fuel fee off by 1e12 times).
  /// Pitfall: when either price is 0, **revert explicitly** -- never treat 0 as a price, otherwise it would silently compute a 0 fuel fee and undercharge.
  function _stakeFeeInOpposite(uint256 amount) internal returns (uint256 fee) {
    (uint256 avgARate, uint256 avgBRate,) = OracleLib.getAccountingPrices(_oracle);
    if (avgARate == 0 || avgBRate == 0) revert CoreVault_PriceUnavailable();
    uint256 feeSame = Math.mulDiv(amount, GlobalConfig.STAKE_FEE_BP, GlobalConfig.RATE_PRECISION, Math.Rounding.Floor);
    fee = Math.mulDiv(feeSame, avgBRate, avgARate, Math.Rounding.Floor);
  }

  // ════════════════════════════════════════════════════════════
  //  Requirement 2.0 sections 3/4, mining pool source (1): donation from any external address
  // ════════════════════════════════════════════════════════════

  /// @notice Any address injects OSK into the **OSK staking mining pool** (Requirement 2.0 section 4, mining pool source (1))
  /// @dev Requirement text: "mining pool source: 1; any external address may inject OSK".
  /// Design intent: **no permission gate** -- any address may call it, and the donation goes directly into this contract's balance,
  ///           strengthening the redemption capacity of OSK staking rewards. It is not a privilege: the caller can only **give up** assets and has no withdrawal capability.
  /// Pitfall: measure by "balance delta" rather than trusting the input parameter -- if the token charges a transfer tax, the input would exceed the actual received amount,
  ///       and adding it directly would overstate _totalDonatedA and distort the audit data (same idea as Treasury's baseline sweep).
  /// Pitfall: not counted into _totalPoolA -- the latter means "unsettled principal pool (USD denominated)", while a donation is an extra redemption reserve,
  ///       and mixing it in would overstate the pool accounting. See the storage comments in CoreVaultStorage.
  function donateOskPool(uint256 amount) external {
    _guardEnter();
    if (amount == 0) revert CoreVault_InvalidAmount();
    _donateCore(msg.sender, amount, TokenType.A);
    _guardExit();
  }

  /// @notice Any address injects FIST into the **FIST staking mining pool** (Requirement 2.0 section 3, mining pool source (1))
  /// @dev Requirement text: "mining pool source: 1; any external address may inject FIST". Semantics are symmetric to donateOskPool.
  function donateFistPool(uint256 amount) external {
    _guardEnter();
    if (amount == 0) revert CoreVault_InvalidAmount();
    _donateCore(msg.sender, amount, TokenType.B);
    _guardExit();
  }

  /// @dev Shared donation pipeline: pull tokens -> record by balance delta -> emit event
  /// Pitfall: doing transferFrom before state changes is **intentional** -- the delta can only be measured after the transfer;
  ///       if transferFrom fails the whole call reverts, state included, so there is no half-completed state.
  /// Pitfall: revert explicitly when received == 0 -- prevents a misleading event of "claiming a donation but receiving zero".
  function _donateCore(address donor, uint256 amount, TokenType t) internal {
    IERC20 token = (t == TokenType.A) ? IERC20(address(aToken)) : IERC20(address(bToken));
    uint256 balBefore = token.balanceOf(address(this));
    token.safeTransferFrom(donor, address(this), amount);
    uint256 received = token.balanceOf(address(this)) - balBefore;
    if (received == 0) revert CoreVault_InvalidAmount();
    unchecked {
      if (t == TokenType.A) _totalDonatedA += received;
      else _totalDonatedB += received;
    }
    emit PoolDonated(donor, t, received);
  }

  // ════════════════════════════════════════════════════════════
  //  Requirement 2.0 sections 3/4, staking rule 2: destination of the 2% staking fuel fee (opposite token)
  // ════════════════════════════════════════════════════════════

  /// @dev Fuel fee (FIST) of **stakeA (OSK staking)** -> **FIST staking mining pool**
  /// Requirement 2.0 section 4, rule 2 text: "2% of the staking amount in FIST is injected into the FIST staking mining pool".
  /// Design intent: the FIST staking mining pool's redemption reserve **is exactly this contract's bToken balance** -- staking principal and rewards are both redeemed from that balance,
  ///           so the fuel fee is **already injected on receipt**, requiring no swap or transfer. Only an event is emitted here for audit cross-checking.
  /// Pitfall: **do not** transfer it to the Treasury to swap into FIST -- the fuel is already FIST, and an extra swap would only waste
  ///       0.25% fee plus slippage, and violate the literal policy of "inject into the FIST staking mining pool".
  function _injectStakeFeeToFistPool(address user, uint256 fee) internal {
    if (fee == 0) return;
    emit StakeFeeInjected(user, fee, TokenType.B, true);
  }

  /// @dev Fuel fee (FIST) of **stakeB (FIST staking)** -> **OSK LP base pool**
  /// Client change on 2026-09-26: the fuel fee is charged in the **staking token itself** (FIST), and the destination is still OSK/FIST LP.
  /// Design intent: swapping and LP formation are centralized in the treasury layer (CoreVault holds no router dependency);
  ///           `Treasury.injectFistToOskLp` is exactly that policy -- split in half -> half the FIST is swapped to OSK
  ///           -> remaining FIST + obtained OSK form OSK/FIST LP -> insurance pool.
  /// Pitfall: when not wired or the LP path fails, the whole call must revert. The user must not be allowed to complete FIST staking
  ///       while the fuel fee stays in CoreVault/Treasury without forming LP.
  function _injectStakeFeeToOskLp(address user, uint256 fee) internal {
    if (fee == 0) return;
    address t = address(treasury);
    if (t.code.length == 0) revert CoreVault_ZeroAddress();
    IERC20(address(bToken)).safeTransfer(t, fee);
    treasury.injectFistToOskLp(fee, GlobalConfig.LP_SLIPPAGE_BP);
    emit StakeFeeInjected(user, fee, TokenType.B, true);
  }

  // ════════════════════════════════════════════════════════════
  //  WARNING: 3rd generation: this layer's former "staking view functions" section has been **moved out entirely** to
  //     `src/core/CoreVaultViewFacet.sol` (activeOrder / getModValues /
  //     totalEarnedAllStaking / getTotalPoolA / getTotalPoolB / getTotalDonated /
  //     getPoolReserve / isStakingRightsClosed / getStakingDynamicEarned /
  //     getPendingStaticYield / getStakingMaxOutProgress / getThreeSectorStatus).
  //     The reason for the move and the hard constraint are in this file's top @dev.
  // ════════════════════════════════════════════════════════════
}
