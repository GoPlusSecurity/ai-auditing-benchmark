// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAToken} from "../src/interfaces/IAToken.sol";
import {IBToken} from "../src/interfaces/IBToken.sol";
import {YieldMath} from "../src/lib/YieldMath.sol";
import {IPancakePair} from "../src/interfaces/IPancake.sol";
import {Treasury} from "../src/core/Treasury.sol";
import {OracleLib} from "../src/core/OracleLib.sol";
import {GlobalConfig} from "../src/core/GlobalConfig.sol";
import {Auth} from "../src/access/Auth.sol";
import {TransientReentrancyGuard} from "../src/access/TransientReentrancyGuard.sol";

/// @title  CoreVaultStorage -- storage base class
/// @notice All state variables, structs, events and custom errors are defined here. The private->internal migration only affects compile-time visibility, not storage slot allocation.
/// @dev Inheriting Auth+TransientReentrancyGuard makes onlyOwner/_guardEnter/_guardExit available across the whole refactor chain.
///
/// @dev ===== WARNING: this file is the "3rd generation" rewritten version, please read carefully =====
/// Provenance: this repo's `Contracts/` is entirely missing for the 3rd generation (facet split version). It is rewritten here from the following **verifiable evidence**:
///   (1) the intermediate generation (2nd generation) version -- **byte-for-byte reconstructed** from the upstream base version `D:\code\cgbb1\code` + `archive/cgbb1_diff.txt`
///      via `git apply` (blob 11/11 match). See `_recovered/lineage-and-generations.md`.
///   (2) the **function selector set** of the on-chain 2026-09-21 mainnet test deployment (`0xf540c915...`) --
///      used to determine which external functions truly exist/do not exist in the 3rd generation (e.g. `swapEngine()` does not exist).
///   (3) the **actual references** of `src/CoreVault.sol` / `src/core/CoreVaultViewFacet.sol` to this contract.
///   (4) the change list in `docs/03-deploy/mainnet-test-deployment-guide.md`.
/// WARNING: therefore this file is **not** a verbatim copy of the original 3rd generation source, but a "reconstruction under evidence constraints".
///    The real 3rd generation source must still be retrieved from an external source before it can serve as an audit baseline.
abstract contract CoreVaultStorage is Auth, TransientReentrancyGuard {
  using SafeERC20 for IERC20;

  enum TokenType { A, B }

  // ════════════════════════════════════════════════════════════
  //  3rd generation change 1: the three main dependencies changed from immutable to **storage**
  // ════════════════════════════════════════════════════════════
  // Reason (hard constraint): facets are called via **DELEGATECALL**, while immutable values are compiled into **code**
  //   and do not exist in storage. If kept immutable, CoreVaultViewFacet / CoreVaultLogicFacet would read
  //   **their own** immutable values (unconstructed -> all 0), not CoreVault's real dependencies.
  // On-chain confirmation: the 9/21 deployment has the three public getters `aToken()` / `bToken()` / `treasury()`.
  // WARNING: storage layout: the three go from "not occupying a slot" to "occupying slots 0/1/2", shifting all subsequent variable slot numbers.
  //   This contract is **non-upgradeable** and the 3rd generation was redeployed anyway, so there is no migration issue;
  //   and since the 3rd generation already changed `getFarmingRaw` from "hard-coded slot 45" to **reading the mapping directly**
  //   (see src/core/CoreVaultViewFacet.sol), the shifted slot numbers no longer cause a mismatch.
  IAToken   public aToken;
  IBToken   public bToken;
  Treasury  public treasury;

  OracleLib.OracleState internal _oracle;

  struct RefInfo {
    address referrer;
    uint8   teamLevel;
    uint8   validDirectCount;
    // flags bit definitions (Requirement 2.0):
    //   bit0 (1) = registered
    //   bit1 (2) = first valid deposit completed (_markFirstInvest)
    //   bit2 (4) = **OSK(A) staking** dynamic yield entitlement closed -- set after this pool's dynamic yield reaches 3x principal and maxes out,
    //              and only rebuilding a new order in this pool (staking A again) clears it and restores the entitlement.
    //   bit3 (8) = **FIST(B) staking** dynamic yield entitlement closed -- same as above, independent of bit2.
    // Pitfall: OSK and FIST staking are two independent mechanisms (performance computed independently, max-out does not affect the other), so each has its own flag bit.
    //       If the two pools shared one bit, an OSK pool max-out would also close the FIST pool entitlement -- a cross-module unauthorized closure.
    uint8   flags;
  }
  mapping(address => RefInfo) internal _refs;
  mapping(address => address[]) internal _directReferrals;

  struct Order {
    uint256 principal;
    uint256 startTime;
    uint256 endTime;
    uint8   flags;
  }
  struct StakeState {
    Order   active;
    Order   ready;
    uint256 totalEarned;
    // Requirement 2.0: **static yield** deferred at 3x max-out.
    //   Max-out rule: orders are closed + principal is not refunded, but this pool's already-generated static yield **must not be destroyed**;
    //   it is deferred here, to be paid out to the user in one go when they **rebuild a new position in this pool**.
    // Pitfall (severe): do not delete it along with the orders at max-out -- that would destroy the user's already-generated static yield,
    //   violating "static yield is triggered to the user when a new position is created".
    // Pitfall: per-pool independent -- pool A's deferred value must not affect pool B.
    // WARNING: storage layout: StakeState sits in a mapping value position, so new fields do not occupy additional top-level slots
    //   (_aStakes/_bStakes each always occupy 1 slot), thus not affecting other state variables' slots; but the struct layout inside existing mapping entries
    //   does change, requiring a full redeployment (this contract was non-upgradeable anyway).
      uint256 pendingStaticYield;
      // Design doc section 7.3 "order-stacking rule": on rebuilding after max-out, the new order amount must be **>= the principal of the last order before max-out**.
      //   This field is that baseline (active is deleted at max-out, so it must be retained separately).
      // Pitfall: do not use `s.active.principal` instead -- at max-out active is zeroed along with the deleted orders.
      // Pitfall: update it on every successful order creation (including full-cycle rebuilds), so the baseline moves forward with the latest order.
      uint256 lastPrincipal;
    }
  mapping(address => StakeState) internal _aStakes;
  mapping(address => StakeState) internal _bStakes;

  uint256 internal _totalPoolA;
  uint256 internal _totalPoolB;

  struct ModValues {
    uint256 teamUsd;
    uint256 directUsd;
    uint256 maxUsd;
  }
  mapping(address => ModValues) internal _modA;
  mapping(address => ModValues) internal _modB;

  mapping(address => uint256) internal _modEarnedDirect;
  mapping(address => uint256) internal _modEarnedTeam;

  bool internal _hasUsers;

  struct Position {
    uint256 principalUsd;
    uint256 principalA;
    uint256 earnedYield;
    uint256 earnedUsd;
    uint256 lastRewardTime;
    uint256 depositTime;
    uint8   flags;
    uint256 redeemableUsd;
    uint256 snapshotDirect;
    uint256 snapshotTeam;
    // Requirement 2.0 section 2: deposit token flag -- 0 = BNB, 1 = FIST.
    // Design intent: one farming mechanism supports both BNB and FIST deposits; the two channels share the same yield/3x max-out/redemption formulas,
    //           differing only in "deposit token" and "fund allocation path", so a single flag field suffices to distinguish them.
    // Pitfall: redemption is always settled in BNB (Requirement 2.0 section 2: "regardless of whether farming used bnb or fist, redemption is always settled to the user in BNB"),
    //       so this field does not participate in redemption amount computation and is only for indexing/audit and frontend display differentiation.
    // WARNING: storage layout warning (measured): this field changes the Position element stride from 10 slots -> 11 slots.
    //   Consequence: the address of _fvUsers[u].positions[i] differs from the old layout (i × 10),
    //        so **every array element of existing on-chain positions would be read misaligned**, with principal/yield/snapshot fields all shifted.
    //   Conclusion: this change **requires a full redeployment of CoreVault**; in-place upgrade on a deployed instance is forbidden (this contract is non-upgradeable, no Proxy).
    //   Pitfall: if Position needs to be extended again in the future, first change it to "append at the end + reserve a gap" or use a separate mapping,
    //        to avoid shifting the whole array again.
    uint8   depositToken;
  }
  struct FvUser {
    Position[] positions;
    uint256 totalInvestedUsd;
    uint256 totalEarned;
    uint256 totalTeamUsd;
    uint256 totalDirectUsd;
    uint256 earnedDirect;
    uint256 earnedTeam;
    uint256 pendingDirect;
    uint256 pendingTeam;
    uint8   flags;
    uint256 maxUsd;
  }
  mapping(address => FvUser) internal _fvUsers;

  uint256[] internal _tierUppers;
  uint256[] internal _teamThresholds;

  address public feewallet1;
  address public bPool;
  address public aPool;

  uint256 public totalAPoolRewards;
  uint256 public totalBPoolRewards;

  // ════════════════════════════════════════════════════════════
  //  3rd generation change 2: removed `address public swapEngine;`
  // ════════════════════════════════════════════════════════════
  // Evidence: the on-chain 9/21 deployment **does not have** the `swapEngine()` selector (f183cf14 miss),
  //   and `setSwapEngine(address)` (60f3b696) also misses => the 3rd generation fully removed this variable and setter.
  //   In the 2nd generation it was used only by the "deprecated withdrawal-tax -> swapEngine distribution" path, which has moved to
  //   `treasury.swapOskToFistAndInject`, so there is no dangling reference after removal.

  // ════════════════════════════════════════════════════════════
  //  Requirement 2.0 sections 3/4, 3x max-out: per-pool dynamic yield accounting (new storage)
  // ════════════════════════════════════════════════════════════
  // Pitfall (severe): dynamic yield must be measured **separately per pool** -- if the cross-pool aggregate values _modEarnedDirect/_modEarnedTeam
  //   were used in the max-out determination, dynamic yield generated by pool A would also mark pool B's orders as maxed out
  //   (double confiscation of principal), an irreversible fund error.
  //   Note: _modEarnedDirect/_modEarnedTeam remain as cross-pool aggregates, used only for view/audit display, not in the max-out determination.
  mapping(address => mapping(TokenType => uint256)) internal _modEarnedDirectByPool;
  mapping(address => mapping(TokenType => uint256)) internal _modEarnedTeamByPool;

  // ════════════════════════════════════════════════════════════
  //  Requirement 2.0 sections 3/4, mining pool source (1): donation from any external address (new storage)
  // ════════════════════════════════════════════════════════════
  // Design intent: the requirement "any external address may inject FIST / inject OSK" --
  //   a donation directly increases this contract's token balance, thereby strengthening that pool's reward redemption capacity.
  // Pitfall: donations are **not counted into** _totalPoolA/_totalPoolB -- the latter means "unsettled principal pool (USD denominated)",
  //   while a donation is an extra redemption reserve rather than principal; mixing it in would overstate pool accounting and distort semantics.
  uint256 internal _totalDonatedA; // cumulative OSK donated to the pool (measured in the original token)
  uint256 internal _totalDonatedB; // cumulative FIST donated to the pool (measured in the original token)

  // ════════════════════════════════════════════════════════════
  //  3rd generation change 3: insurance pool address + farming deposit bounds (appended storage)
  // ════════════════════════════════════════════════════════════
  // Evidence: the "change list" section of docs/03-deploy/mainnet-test-deployment-guide.md explicitly records
  //   - `Contracts/CoreVaultStorage.sol` added the `DepositBoundsUpdated` event
  //   - `Contracts/CoreVaultAdmin.sol` added the `setDepositBounds()` + `depositBounds()` views
  //   - 4 new variables **appended after all existing state variables** (after _totalDonatedB), not shifting existing slots
  // On-chain confirmation: `insurancePool()` (ab2adc00) / `depositBounds()` (562705dc) /
  //   `setDepositBounds(uint256,uint256,uint256,uint256)` (92736b07) all hit.
  // Design intent: production takes the GlobalConfig production values by default; the mainnet test build has owner call setDepositBounds
  //   to override them with small bounds (e.g. 0.001 BNB / 1 USD), enabling small end-to-end verification on the real chain.
  // Pitfall: use storage rather than constant -- otherwise the test build and the production build must be compiled and deployed separately, unable to share bytecode.
  address public insurancePool;

  uint256 internal _minDepositBnb;
  uint256 internal _maxDepositBnb;
  uint256 internal _minDepositUsd;
  uint256 internal _maxDepositUsd;

  // ════════════════════════════════════════════════════════════
  //  Node mining pool 30% dividend wiring (appended storage)
  // ════════════════════════════════════════════════════════════
  // Source: `node-requirements-doc.txt` section 1, entitlements -- "5%/5%/10%/10% of network-wide static revenue is injected into the node mining pool and split equally",
  //   totaling 30% of static revenue -> four-pool weighting (founder 5 / co-founder 5 / sponsor 10 / operation 10, sum = 30).
  // Policy (1.0, confirmed): farming **gross expense** = user 100% + referral 20% + team 50% + node 30% = 200%
  //   (all **pre-tax**). That is, the node leg is an **additional** expense, not deducted from the user's share.
  //   -> implemented in `Contracts/CoreVaultFarming.sol::_processYieldPayout`.
  // Difference from the withdrawal-tax route (two **independent** node dividends):
  //   - this variable (30% static revenue) -> `NodePoolDistributor` -> A/B/E/D **weighted 5/5/10/10**;
  //   - `feewallet1` (2.5% withdrawal tax) -> `BWalletDistributor5` -> A/B/C/D/E **split equally 5 ways**.
  //   Both are denominated in OSK, but their sources and allocation methods differ and must not be mixed up.
  // On-chain confirmation: the 9/21 deployment has the two selectors `nodePoolDistributor()` (b691b3ee) /
  //   `setNodePoolDistributor(address)` (3b00b729) -- this variable and
  //   `CoreVaultAdmin::setNodePoolDistributor` are exactly their restoration (see Contracts/README.md section 3.3).
  // WARNING: storage layout: appended **after all existing state variables** (after `_maxDepositUsd`), not shifting existing slots.
  //   Same convention as the `insurancePool` block. This contract is non-upgradeable, and the 3rd generation was redeployed anyway.
  // Pitfall: when not wired (address(0)) the node leg is **silently skipped** -- same policy as `feewallet1`;
  //   it must never revert, otherwise a single unconfigured external address would block yield claiming for all users.
  address public nodePoolDistributor;

  // ════════════════════════════════════════════════════════════
  //  Staking dynamic yield "valid stake" gating (added 2026-09-26)
  // ════════════════════════════════════════════════════════════
  // Requirement: an upline must have a **valid stake** in this pool to claim this pool's (OSK/FIST) dynamic yield --
  //   uplines who have not staked (farming only) / have maxed out (3x max-out clears orders) receive nothing, and their amount is **retained in this pool**
  //   to strengthen redemption capacity (no longer passed further up).
  // Design intent: two independent counters measuring, per pool, "rewards retained in this pool because the upline had no valid stake" --
  //   strictly distinguished from `_totalDonatedA/B` (external donations): the two have different sources and must not be merged.
  // Pitfall: this counter is **measured in the original token** (OSK 18 decimals / FIST 6 decimals, each its own precision), with no USD conversion --
  //   conversion would require reading the oracle, a state change, which cannot be done on a pure accounting path.
  // Pitfall: the retained amount does not enter `_totalPoolA/B` -- the latter means "unsettled principal pool (USD denominated)",
  //   and mixing it in would overstate pool accounting and distort semantics (same policy as _totalDonatedA/B).
  // WARNING: storage layout: appended after all existing state variables (after `nodePoolDistributor`), not shifting existing slots.
  uint256 internal _redirectedToPoolA;
  uint256 internal _redirectedToPoolB;

  event Staked(address indexed user, uint256 amount, uint256 endTime, TokenType t);
  event Unlocked(address indexed user, uint256 principal, uint256 reward, TokenType t);
  event DirectRewardAccrued(address indexed referrer, address indexed user, uint256 amount, uint8 gen);
  event TeamRewardAccrued(address indexed upline, address indexed user, uint256 amount, uint8 level);
  event TeamLevelUp(address indexed user, uint8 newLevel);
  event BnbDeposited(address indexed user, uint256 bnbAmount, uint256 usdAmount, uint256 positionId);
  // Requirement 2.0 section 2, "FIST on-chain mining mechanism 2": FIST deposit opens a position
  event FistDeposited(address indexed user, uint256 fistAmount, uint256 usdAmount, uint256 positionId);
  // Requirement 2.0 sections 3/4, staking rule 2: the 2% staking fuel fee (deducted additionally from the wallet) has been handled per destination.
  //   t = **the fuel fee's own token**: B (FIST, from OSK staking or FIST staking) -> transfer to treasury to form OSK/FIST LP -> insurance pool.
  //   WARNING: 2026-09-26 change: the FIST staking fuel fee changed from "opposite OSK" to "same-token FIST", so stakeB is also B.
  //       Currently only stakeA's FIST fuel **stays directly in this contract** = FIST staking mining pool reserve (bypassing the treasury).
  //   If fuel fee injection fails the whole stake reverts; a successful stake call only ever emits injected=true.
  event StakeFeeInjected(address indexed user, uint256 feeAmount, TokenType t, bool injected);
  // Requirement 2.0 sections 3/4, mining pool source (1): donation from any external address to the staking mining pool
  event PoolDonated(address indexed donor, TokenType t, uint256 amount);
  event YieldClaimed(address indexed user, uint256 positionId, uint256 amount);
  event PositionClosed(address indexed user, uint256 positionId, uint256 reason);
  event PrincipalRedeemed(address indexed user, uint256 positionId, uint256 amount);
  event ReferralRegistered(address indexed user, address indexed referrer);
  // Requirement 2.0 sections 3/4: a V1+ user's dynamic yield reaches 3x principal -> max-out closes orders, principal not refunded
  event StakingMaxOut(address indexed user, TokenType t, uint256 principal, uint256 dynamicEarned);
  // Requirement 2.0 sections 3/4: rebuilding a new order -> dynamic yield entitlement restored
  event StakingRightsRestored(address indexed user, TokenType t);
  // Requirement 2.0 sections 3/4: static yield deferred at max-out (paid when a new position is rebuilt)
  event StakingYieldDeferred(address indexed user, TokenType t, uint256 amount);
  // Requirement 2.0 sections 3/4: new position rebuilt -> deferred static yield paid out to the user
  event StakingYieldPaid(address indexed user, TokenType t, uint256 amount);
  // Staking dynamic yield "valid stake" gating: the upline has no valid stake in this pool -> the amount that would have gone to them is retained in this pool.
  //   kind: 0 = direct referral reward, 1 = team differential; amount is the **original-token** amount (gross before tax).
  event StakingRewardRedirected(address indexed upline, address indexed user, uint256 amount, TokenType t, uint8 kind);
  // 3rd generation: farming deposit bounds adjusted by owner (change trace, for auditing the bound differences between the test and production builds)
  event DepositBoundsUpdated(uint256 minBnb, uint256 maxBnb, uint256 minUsd, uint256 maxUsd);
  // Node mining pool 30% dividend target adjusted by owner (wiring trace; the companion event of on-chain setNodePoolDistributor)
  event NodePoolDistributorSet(address indexed nodePoolDistributor);
  // On yield claim, 30% of static revenue is transferred out to the node mining pool (additional expense, not part of 3x max-out accounting)
  //   usdAmount = accrual base (USD, pre-tax); oskAmount = actual OSK amount transferred out
  event NodePoolYieldPaid(address indexed nodePool, uint256 usdAmount, uint256 oskAmount);
  // Emergency withdrawal trace (onlyOwner). No token restriction, full-amount withdrawal allowed -- client-confirmed on 2026-09-25.
  event EmergencyWithdrawn(address indexed token, address indexed to, uint256 amount);

  error CoreVault_ZeroAddress();
  error CoreVault_ZeroPrice();
  error CoreVault_InvalidAmount();
  error CoreVault_PriceUnavailable();
  error CoreVault_Shortfall(uint256 n, uint256 a);
  error CoreVault_UnknownOp(uint8 op);
  error CoreVault_NoReferrer();
  error CoreVault_SelfReferral();
  error CoreVault_ActivePositionExists(uint256 activePosId);
  error CoreVault_NoActivePosition();
  // Requirement 2.0 section 2: in the farming module only the first order (pid=0) participates in the redemption mechanism; orders rebuilt after 3x max-out are not redeemable.
  error CoreVault_NotFirstPosition(uint256 positionId);

  // ── Pure data helper functions ──

  function isRegistered(address u) internal view returns (bool) { return _refs[u].flags & 1 != 0; }

  /// @dev Requirement 2.0: whether the staking dynamic yield entitlement is closed (set after 3x max-out)
  /// WARNING: must be judged **per pool** -- OSK staking and FIST staking are two independent mechanisms (performance computed independently),
  ///    and an OSK pool max-out must never also close the FIST pool entitlement. Each occupies its own flag bit.
  function _stakingRightsClosed(address u, TokenType t) internal view returns (bool) {
    return _refs[u].flags & _stakeRightsBit(t) != 0;
  }

  /// @dev Entitlement-closed flag bit: A(OSK) = bit2, B(FIST) = bit3
  ///      Pitfall: do not reuse the same bit -- reuse would let one pool's max-out contaminate the other (cross-module unauthorized closure).
  function _stakeRightsBit(TokenType t) internal pure returns (uint8) {
    return t == TokenType.A ? 4 : 8;
  }

  /// @dev This pool's total dynamic yield (direct referral reward + team differential), used only in the 3x max-out determination
  ///      Pitfall: must be read per pool -- a cross-pool total would let pool A's yield trigger pool B's max-out.
  function _dynamicEarnedByPool(address u, TokenType t) internal view returns (uint256) {
    return _modEarnedDirectByPool[u][t] + _modEarnedTeamByPool[u][t];
  }

  /// @dev Whether the user has a **valid stake** in this pool -- the precondition for claiming staking dynamic yield (direct referral/team).
  ///      Valid = this pool has an unsettled order (active or ready), i.e. the principal is still locked in this contract.
  /// Policy (client-confirmed on 2026-09-26):
  ///   - not staked (farming only)      -> false, may not claim this pool's dynamic yield;
  ///   - maxed out (3x max-out clears orders) -> false (orders have been deleted), may not claim;
  ///   - full cycle elapsed without restaking -> true -- the principal is still locked in the contract, which counts as a "valid stake";
  ///   - rebuilt a new position in this pool after max-out -> true -- rebuilding restores this pool's entitlement (see _stakeCore).
  /// Pitfall: must be judged **per pool** -- a valid stake in pool A must not make pool B's rewards claimable (the two pools' performance is independent and max-out is not intertwined).
  function _hasValidStake(address u, TokenType t) internal view returns (bool) {
    StakeState storage s = (t == TokenType.A) ? _aStakes[u] : _bStakes[u];
    return (s.active.flags & 1) != 0 || (s.ready.flags & 1) != 0;
  }

  /// @dev A single order's **static yield** (staking yield, Requirement 2.0 sections 3/4: 0.7% daily × 10 days/cycle = 7%/cycle)
  ///      Policy: returns 0 before a full cycle (per-cycle, no overtime accrual); after a full cycle it is always "principal × FIXED_RATE_BP".
  ///      Design intent: extracted into a shared base function -- max-out deferral (CoreVaultReferral) and unlock settlement (CoreVaultStaking)
  ///                must use the **same** yield formula, otherwise the deferred value and the settlement value would diverge.
  function _orderStaticYield(uint256 principal, uint256 endTime) internal view returns (uint256) {
    if (principal == 0 || block.timestamp < endTime) return 0;
    return Math.mulDiv(principal, GlobalConfig.FIXED_RATE_BP, GlobalConfig.RATE_PRECISION, Math.Rounding.Floor);
  }

  /// @dev Node mining pool 30% dividend leg (system 2, "30% of network-wide static revenue") -- **farming and staking share the same implementation**.
  ///      Source: `node-requirements-doc.txt` section 1, entitlements "5%/5%/10%/10% of network-wide static revenue is injected into the node mining pool and split equally".
  ///      Policy (client-confirmed on 2026-09-23; extended to the staking module the same day):
  ///        - all three modules (farming / OSK staking / FIST staking) accrue static revenue;
  ///        - gross expense = user 100% + direct referral 20% + team 50% + node 30% = 200% (pre-tax);
  ///        - the node leg is an **additional** expense, not deducted from the user's share, and **does not participate** in 3x max-out accounting.
  ///      Design intent for extracting into a shared base function: the two modules must use the **same** accrual policy,
  ///        otherwise there would be a divergence of "farming 30% / staking X%".
  /// @param baseUsd  accrual base (USD denominated). For farming, pass this claim's **confirmed paid** pendingUsd (after 3x trimming);
  ///                 for staking, pass the USD equivalent of this static yield (OSK pool: reward×avgARate; FIST pool: reward×avgBRate).
  /// @param avgARate OSK's USD conversion rate (how many OSK per 1 USD).
  ///                 The node pool (`NodePoolDistributor`) is **single-token immutable = OSK**, so it is always paid out in OSK --
  ///                 the FIST staking pool's static yield must first be converted by value into OSK (see the call site in CoreVaultReferral).
  /// Pitfall: when not wired (address(0)) **silently skip**, never revert -- same policy as `feewallet1`;
  ///       a single unconfigured external address must not block yield claiming/unlocking for all users.
  /// Pitfall: the event records the **actual received amount**, not the requested amount -- `payoutReward` silently truncates when the treasury balance is insufficient.
  function _payoutNodePoolLeg(uint256 baseUsd, uint256 avgARate) internal {
    if (baseUsd == 0 || nodePoolDistributor == address(0) || avgARate == 0) return;
    uint256 nodePoolUsd = Math.mulDiv(baseUsd, GlobalConfig.NODE_POOL_BP, GlobalConfig.RATE_PRECISION, Math.Rounding.Floor);
    if (nodePoolUsd == 0) return;
    uint256 nodePoolA = Math.mulDiv(nodePoolUsd, avgARate, 1e18, Math.Rounding.Floor);
    if (nodePoolA == 0) return;
    uint256 paid = treasury.payoutReward(nodePoolDistributor, nodePoolA);
    emit NodePoolYieldPaid(nodePoolDistributor, nodePoolUsd, paid);
  }

  /// @dev Requirement 2.0 section 2: **first-order redemption entitlement** determination in the farming module -- "only the first order (pid=0) participates in the redemption mechanism".
  /// @notice Rule (confirmed): **the first-order entitlement is permanently exhausted**.
  ///   Meaning: each address gets only one redemption opportunity in its lifetime. Whether the first order is closed by
  ///         (a) the user's **active redemption**, or
  ///         (b) a **3x max-out** (principal not refunded),
  ///         the entitlement is **never regenerated** -- all subsequently rebuilt orders (pid>=1) are never redeemable.
  /// Pitfall: do not change this to rely on Position.flags -- that flag is only set when "redeemable amount = 0",
  ///       which would let rebuilt orders silently become redeemable while yield has not exceeded 50% of principal, conflicting with "permanently exhausted".
  function _isFirstPosition(uint256 positionId) internal pure returns (bool) {
    return positionId == 0;
  }

  /// @dev First-order redemption entitlement status (structural determination, for frontend/indexer use)
  /// @return used       whether the first-order redemption entitlement is exhausted (redeemed or maxed out)
  /// @return redeemable whether redemption can be executed immediately right now
  /// @return flags      the flags of the first position (bit0 = closed, bit1 = not redeemable)
  /// Pitfall: this function **only does a structural determination** and does not compute the redeemable amount --
  ///       the amount depends on pending yield and updating the TWAP is a state change, which cannot be done in a view.
  function _firstRedeemStatus(address user) internal view returns (bool used, bool redeemable, uint8 flags) {
    FvUser storage fv = _fvUsers[user];
    if (fv.positions.length == 0) return (false, false, 0);
    Position storage p = fv.positions[0];
    flags = p.flags;
    if (flags & 1 != 0) return (true, false, flags);  // first order closed -> entitlement permanently exhausted
    if (flags & 2 != 0) return (true, false, flags);  // not-redeemable flag set -> entitlement exhausted
    if (block.timestamp < p.depositTime + GlobalConfig.LOCKUP_MIN) return (false, false, flags);
    return (false, true, flags);
  }

  function _register(address user, address referrer) internal {
    RefInfo storage r = _refs[user];
    if (r.flags & 1 != 0) return;
    if (user != address(0) && user == referrer) revert CoreVault_SelfReferral();
    address _ref = (referrer == address(0) || _refs[referrer].flags & 1 == 0) ? address(0) : referrer;
    r.referrer = _ref;
    // Pitfall: use |= rather than = -- preserves any existing bit1 (first deposit) / bit2 (entitlement closed) flags, avoiding an accidental clear.
    r.flags |= 1;
    if (!_hasUsers) _hasUsers = true;
    if (_ref != address(0)) _directReferrals[_ref].push(user);
    emit ReferralRegistered(user, _ref);
  }

  function _requireValidReferrer(address referrer) internal view {
    if (referrer == msg.sender) revert CoreVault_SelfReferral();
    if (referrer == address(0)) {
      if (!isRegistered(msg.sender) && _hasUsers)
        revert CoreVault_NoReferrer();
    } else {
      if (_hasUsers && !isRegistered(msg.sender) && !isRegistered(referrer))
        revert CoreVault_NoReferrer();
    }
  }

  function _markFirstInvest(address user) internal returns (bool) {
    RefInfo storage r = _refs[user];
    if (r.flags & 2 != 0) return false;
    r.flags |= 2;
    return true;
  }

  function _incValidDirects(address user) internal {
    RefInfo storage r = _refs[user];
    if (r.validDirectCount < 9) r.validDirectCount++;
  }

  function _syncLevel(address user, uint8 nl) internal {
    RefInfo storage r = _refs[user];
    if (nl > 9) nl = 9;
    if (nl > r.teamLevel) { r.teamLevel = nl; emit TeamLevelUp(user, nl); }
  }

  /// @dev Compute the level (0..9) from a **single module's** team performance
  function _levelFromTtu(uint256 ttu) internal view returns (uint8) {
    uint8 nl = 0;
    uint256[] storage thresholds = _teamThresholds;
    unchecked {
      for (uint8 l = 0; l < 10 && l < thresholds.length;) {
        if (ttu >= thresholds[l]) { nl = l; l++; }
        else break;
      }
    }
    return nl;
  }

  /// @dev Requirement 2.0: the three modules (farming / OSK staking / FIST staking) compute levels **independently**, and only the highest is synced.
  /// Pitfall (severe): do not add A+B staking performance together -- the requirement states "the three performances are all computed independently,
  ///   only the level is synced to the highest level". Adding them would let a user who **fails the threshold in each module individually** level up out of thin air,
  ///   and then claim excess team differential (fund leakage).
  function _effectiveLevel(address user) internal view returns (uint8) {
    uint8 lvFarm = _levelFromTtu(_fvUsers[user].totalTeamUsd);
    uint8 lvA    = _levelFromTtu(_modA[user].teamUsd);
    uint8 lvB    = _levelFromTtu(_modB[user].teamUsd);
    uint8 nl = lvFarm;
    if (lvA > nl) nl = lvA;
    if (lvB > nl) nl = lvB;
    return nl;
  }

  /// @dev The three modules' respective levels (for views/audits to verify independence)
  function _levelBreakdown(address user) internal view returns (uint8 lvFarm, uint8 lvA, uint8 lvB) {
    lvFarm = _levelFromTtu(_fvUsers[user].totalTeamUsd);
    lvA    = _levelFromTtu(_modA[user].teamUsd);
    lvB    = _levelFromTtu(_modB[user].teamUsd);
  }
}
