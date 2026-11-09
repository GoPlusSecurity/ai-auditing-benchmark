// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IAToken} from "./interfaces/IAToken.sol";
import {IBToken} from "./interfaces/IBToken.sol";
import {IPancakePair} from "./interfaces/IPancake.sol";
import {OracleLib} from "./core/OracleLib.sol";
import {Treasury} from "./core/Treasury.sol";
import {GlobalConfig} from "./core/GlobalConfig.sol";
import {IAccounting} from "./interfaces/IAccounting.sol";
import {CoreVaultStaking} from "../Contracts/CoreVaultStaking.sol";
import {CoreVaultAdmin} from "../Contracts/CoreVaultAdmin.sol";
import {CoreVaultLogicFacet} from "../Contracts/CoreVaultLogicFacet.sol";
import {CoreVaultViewFacet} from "./core/CoreVaultViewFacet.sol";

/// @title  CoreVault -- final aggregate contract (refactored version, module split)
/// @notice Inheritance chain: CoreVaultStorage -> CoreVaultAdmin -> CoreVaultReferral -> CoreVaultStaking
///         The farming module and all read-only views **have been split out into facets**, routed via this contract's wrappers using DELEGATECALL.
///
/// @dev ===== why the split (size constraint, must be understood) =====
/// The original inheritance chain (...->Staking->Farming->FarmingReferral) had runtime bytecode of **30,747 bytes**,
/// exceeding the EIP-170 limit (24,576), so it **could not be deployed** on BSC mainnet. Measured per-layer contribution:
///   Storage 948 / Admin +1,792 / Staking +14,429 / Farming +7,318 /
///   FarmingReferral +3,897 / CoreVault body +891 / read-only views 5,434
/// After splitting by "business module" each contract is well below the limit:
///   - **CoreVault** (this contract) = Storage->Admin->Referral->Staking + 31 bare-forwarding wrappers
///   - **CoreVaultLogicFacet** = Storage->Admin->Referral->Farming->FarmingReferral (farming + op dispatch)
///   - **CoreVaultViewFacet**  = Storage + all read-only views
/// Precondition for the split: **Staking and Farming do not depend on each other** (verified: both depend only on Storage/Admin/Referral).
///
/// @dev ===== why the wrappers are "bare forwarding" (pitfall) =====
/// The frontend / CoreVaultViewer / tests access via **typed calls** (e.g. `vault.getRefInfo(u)`),
/// so the compiler requires this contract to **declare** these functions -- a fallback alone cannot satisfy compile time.
/// Hence each moved function keeps an **extremely thin wrapper** in this contract: assembly forwards the raw calldata to the
/// facet, then **returns its return data as-is** (skipping abi.decode/encode) -- each is only about 80-100 bytes,
/// and **does not change** the external signature or semantics.
contract CoreVault is CoreVaultStaking, IAccounting {

  /// @dev Business logic facet (farming module + op dispatch) -- deployed at construction, immutable.
  address public immutable logicFacet;
  /// @dev View facet -- deployed at construction, immutable.
  address public immutable viewFacet;

  constructor(
    address _aToken, address _bToken, address _treasury,
    address _aOskFistPair, address _bUsdtPair,
    uint256[] memory _tierUppers_, uint256[] memory _teamThresholds_
  ) {
    aToken = IAToken(_aToken);
    bToken = IBToken(_bToken);
    treasury = Treasury(payable(_treasury));
    _oracle.aOskFistPair = IPancakePair(_aOskFistPair);
    _oracle.bUsdtPair = IPancakePair(_bUsdtPair);
    _oracle.aToken = _aToken;
    _oracle.bToken = _bToken;
    _tierUppers = _tierUppers_;
    _teamThresholds = _teamThresholds_;
    // Farming deposit bounds: default to the GlobalConfig production values -> production behavior unchanged;
    // the mainnet test build has owner call setDepositBounds to override them with small bounds (0.001 BNB / 1 USD).
    _minDepositBnb = GlobalConfig.MIN_DEPOSIT_BNB;
    _maxDepositBnb = GlobalConfig.MAX_DEPOSIT_BNB;
    _minDepositUsd = GlobalConfig.MIN_DEPOSIT_USD;
    _maxDepositUsd = GlobalConfig.MAX_DEPOSIT_USD;
    // Deploy the two facets -- avoiding an extra wiring step (no change needed for tests/scripts).
    // Pitfall: initcode = this contract + both facets' initcode combined, and must be < the EIP-3860 limit (49,152).
    address vf = address(new CoreVaultViewFacet());
    viewFacet = vf;
    logicFacet = address(new CoreVaultLogicFacet(vf));
  }

  // ---- IAccounting override (multi-base resolution) ----
  function getAPerUsd() external override(CoreVaultAdmin, IAccounting) returns (uint256 a) {
    (a,,) = OracleLib.getAccountingPrices(_oracle);
  }
  function getBPerUsd() external override(CoreVaultAdmin, IAccounting) returns (uint256 b) {
    (,b,) = OracleLib.getAccountingPrices(_oracle);
  }
  function getWbnbPerUsd() external override(CoreVaultAdmin, IAccounting) returns (uint256 w) {
    (,,w) = OracleLib.getAccountingPrices(_oracle);
  }
  /// @dev Kept in this contract (not moved to a facet): it is a required implementation of `IAccounting`;
  ///   relying only on a forwarding wrapper would leave the interface unsatisfied -> this contract becomes abstract and undeployable.
  function getSwapPrices() external view override(IAccounting)
    returns (uint256 aPerUsd, uint256 bPerUsd, uint256 wbnbPerUsd)
  { return OracleLib.getSwapPricesView(_oracle); }

  // =====================================================
  //  Admin
  // =====================================================

  function setInsurancePool(address _p) external {
    if (msg.sender != owner()) revert();
    if (_p == address(0)) revert();
    insurancePool = _p;
  }

  // =====================================================
  //  Pure BNB transfer in -> forward to insurance pool (registered users / genesis addresses only)
  // =====================================================

  /// @dev Bare BNB transfer (empty calldata) -- **explicitly rejected**.
  /// Client-confirmed on 2026-09-24: "reject bare transfers".
  ///
  /// Evidence (three items, mutually corroborating):
  ///   (1) **original implementation**: `archive/legacy-CoreVault-monolith-852-lines.sol` **has no `receive()`**, and its
  ///      `fallback()` first line is `if (msg.data.length == 0) revert CoreVault_InvalidAmount();`
  ///      => the original design was to "reject bare transfers".
  ///   (2) **neither the requirements nor the design doc has such a clause**: in the requirements the insurance pool has only **one** funding source -- the 20% deposit leg
  ///      (`development-requirements-doc-2.0.md:43`); the design doc's fund-flow diagram has **no** BNB arrow `-> CoreVault`.
  ///   (3) **no internal caller**: none of the 8 BNB send sites (Treasury/InsurancePool/SwapEngine) sends a bare
  ///      BNB transfer to CoreVault => this function's only purpose is to handle user mistakes.
  ///
  /// Behavior before the fix (WARNING: deprecated): a registered user's bare transfer was **silently forwarded to the insurance pool** -- the user opened no position, no referral relationship was recorded,
  ///   no principal was counted, no event was emitted, and the funds were **unrecoverable**. This violated Requirement L142 "all users must first lock the
  ///   relationship through the farming module", and when the insurance pool was not wired it would even silently transfer to `address(0)`.
  ///
  /// Pitfall: `receive()` **must be declared explicitly** -- if only `fallback()` were left, empty calldata would fall into
  ///   `_fwdLogic()` forwarded to LogicFacet, whose `receive()` would also revert `InvalidAmount`,
  ///   but the semantics would be unclear and it would cost an extra delegatecall. Here it rejects directly, with an error code matching the original implementation.
  /// Pitfall: force users through an **explicit entry point** -- `depositBNB(referrer)` or the fallback `op 0x01`
  ///   (both validate the referral relationship and open a position), preventing "funds entered the pool but the user has no position".
  /// Regression: test/BareBnbTransfer.fork.t.sol, test/CoreVaultFarming.t.sol
  receive() external payable {
    revert CoreVault_InvalidAmount();
  }

  // =====================================================
  //  Fallback --- op multiplexing entry forwarding (length 1/21/33)
  //  0x01 depositBNB | 0x02 claimYield | 0x03 redeemPrincipal
  // Note: these three ops' implementations depend on the farming layer (_depositBNBCore/_claimYieldCore/_redeemPrincipalCore),
  //   so they are all forwarded to LogicFacet for dispatch; standard ABI calls are handled by the wrappers above and do not reach here.
  // =====================================================

  fallback() external payable { _fwdLogic(); }

  // ════════════════════════════════════════════════════════════
  //  Bare forwarding kernel
  // ════════════════════════════════════════════════════════════

  /// @dev Forward to the business logic facet (farming module + op dispatch)
  function _fwdLogic() private {
    address f = logicFacet;
    assembly {
      calldatacopy(0, 0, calldatasize())
      let ok := delegatecall(gas(), f, 0, calldatasize(), 0, 0)
      returndatacopy(0, 0, returndatasize())
      if iszero(ok) { revert(0, returndatasize()) }
      return(0, returndatasize())
    }
  }

  /// @dev Forward to the view facet
  function _fwdView() private {
    address f = viewFacet;
    assembly {
      calldatacopy(0, 0, calldatasize())
      let ok := delegatecall(gas(), f, 0, calldatasize(), 0, 0)
      returndatacopy(0, 0, returndatasize())
      if iszero(ok) { revert(0, returndatasize()) }
      return(0, returndatasize())
    }
  }

  // ════════════════════════════════════════════════════════════
  //  Farming module wrappers (implementations in CoreVaultLogicFacet)
  // ════════════════════════════════════════════════════════════

  function depositBNB(address) external payable { _fwdLogic(); }
  function depositFIST(address, uint256) external { _fwdLogic(); }
  function claimYield(uint256) external { _fwdLogic(); }
  function claimYieldActive() external { _fwdLogic(); }
  function redeemPrincipal(uint256) external { _fwdLogic(); }
  function redeemPrincipalActive() external { _fwdLogic(); }

  // ════════════════════════════════════════════════════════════
  //  View wrappers (implementations in CoreVaultViewFacet)
  // ════════════════════════════════════════════════════════════

  function activeOrder(address, uint8) external returns (uint256, uint256, uint8) { _fwdView(); }
  function getModValues(address) external returns (
    uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256
  ) { _fwdView(); }
  function totalEarnedAllStaking(address) external returns (uint256) { _fwdView(); }
  function getTotalPoolA() external returns (uint256) { _fwdView(); }
  function getTotalPoolB() external returns (uint256) { _fwdView(); }
  function getTotalDonated(uint8) external returns (uint256) { _fwdView(); }
  function getTotalRedirected(uint8) external returns (uint256) { _fwdView(); }
  function getPoolReserve(uint8) external returns (uint256) { _fwdView(); }
  function isStakingRightsClosed(address, uint8) external returns (bool) { _fwdView(); }
  function getStakingDynamicEarned(address, uint8) external returns (uint256) { _fwdView(); }
  function getPendingStaticYield(address, uint8) external returns (uint256) { _fwdView(); }
  function getStakingMaxOutProgress(address, uint8) external returns (uint256, uint256) { _fwdView(); }
  function getThreeSectorStatus(address) external returns (
    bool, bool, bool, uint256, uint256, uint256, uint8, uint8, uint8, uint8
  ) { _fwdView(); }
  function getRefInfo(address) external returns (address, uint8, uint8, uint8) { _fwdView(); }
  function positionCount(address) external returns (uint256) { _fwdView(); }
  function getDirectReferralAt(address, uint256) external returns (address) { _fwdView(); }
  function getDirectReferralsCount(address) external returns (uint256) { _fwdView(); }
  function getFarmingRaw(address) external returns (
    uint256, uint256, uint256, uint256, uint256
  ) { _fwdView(); }
  function getPositionRaw(address, uint256) external returns (
    uint256, uint256, uint256, uint256
  ) { _fwdView(); }
  function getPositionFlags(address, uint256) external returns (uint8) { _fwdView(); }
  function getPositionDepositToken(address, uint256) external returns (uint8) { _fwdView(); }
  function getFirstRedeemStatus(address) external returns (bool, bool, uint8) { _fwdView(); }
  function totalFarmingEarned(address) external returns (uint256) { _fwdView(); }
  function getEffectiveLevel(address) external returns (uint8) { _fwdView(); }
  function getFvUserMaxAndFlags(address) external returns (uint256, uint8) { _fwdView(); }
  function getDirectReferralSummary(address, uint256, uint256) external returns (
    address[] memory, uint256[] memory, uint256[] memory, uint256[] memory, uint256[] memory
  ) { _fwdView(); }
}