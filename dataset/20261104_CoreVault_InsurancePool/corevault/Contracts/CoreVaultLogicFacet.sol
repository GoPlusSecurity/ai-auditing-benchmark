// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {CoreVaultFarmingReferral} from "./CoreVaultFarmingReferral.sol";

/// @title  CoreVaultLogicFacet -- CoreVault's **business logic facet** (farming module + op dispatch)
/// @notice Called by `CoreVault` via `DELEGATECALL`. The inheritance chain
///         `CoreVaultStorage -> Admin -> Referral -> Staking -> Farming -> FarmingReferral`
///         means the **storage layout is identical to CoreVault**, so it reads and writes CoreVault's storage slots.
///
/// @dev ===== this file is a 3rd generation (facet split version) **rewrite** -- evidence and limitations =====
/// This file **does not exist** in the 2nd generation (it was still monolithic then), nor does it appear in `archive/cgbb1_diff.txt`
/// (`git diff HEAD` does not include untracked new files -- ironclad evidence: the diff's added lines reference
/// `src/interfaces/IFISTDAO.sol` yet it was never created). So it is rewritten here from the following evidence:
///   (1) the **construction and forwarding contract** of `src/CoreVault.sol`:
///      `logicFacet = address(new CoreVaultLogicFacet(vf))` -- the constructor argument is the viewFacet address;
///      `fallback() external payable { _fwdLogic(); }` -- the raw calldata is delegatecalled in full to this contract;
///      plus 6 "farming module wrappers" (`depositBNB` / `depositFIST` / `claimYield` /
///      `claimYieldActive` / `redeemPrincipal` / `redeemPrincipalActive`) that also forward to this contract.
///   (2) the top comment of `src/CoreVault.sol` states this contract's responsibility:
///      "CoreVaultLogicFacet = Storage->Admin->Referral->Farming->FarmingReferral (farming + op dispatch)".
///   (3) the on-chain 9/21 deployment's **measured function selectors**: `logicFacet()` (72f70be2) / `viewFacet()` (30becb34)
///      hit; `depositFIST(address,uint256)` (30d931f1) / `setDepositBounds(...)` (92736b07) hit.
///   (4) the **op multiplexing** implementation of the 2nd generation `src/CoreVault.sol`'s `fallback()` (byte-for-byte reconstructed version) --
///      this file's op semantics are equivalent to it, only swapping the implementation bodies such as `_depositBNBCore` for the versions **inherited** by this contract.
/// WARNING: therefore this file is **not** a verbatim copy of the original 3rd generation source, but a "reconstruction under evidence constraints".
///    The original 3rd generation real source must still be retrieved from an external source before it can serve as an audit baseline.
contract CoreVaultLogicFacet is CoreVaultFarmingReferral {

  /// @dev View facet address (passed in at CoreVault construction time) -- exposed externally to preserve the construction contract and verifiability.
  ///      This contract **does not forward** view calls: CoreVault's view wrappers call `_fwdView()` directly to the viewFacet,
  ///      bypassing this contract; so it merely holds the address and does not participate in routing.
  address public immutable viewFacet;

  constructor(address vf) {
    viewFacet = vf;
  }

  // ════════════════════════════════════════════════════════════
  //  Farming module entry points (depositBNB / depositFIST / claimYield /
  //  claimYieldActive / redeemPrincipal / redeemPrincipalActive)
  // ════════════════════════════════════════════════════════════
  // Note: these 6 functions are provided by the inheritance chain (`CoreVaultFarming`) and are all `external` --
  //   CoreVault's same-named wrappers delegatecall the raw calldata in full, with selectors matching one to one,
  //   so **no redeclaration is needed** here (redeclaring would instead conflict with the inherited definitions).

  // ════════════════════════════════════════════════════════════
  //  Fallback -- op multiplexing entry point
  //  length 1  : op byte only
  //  length 21 : op + address(referrer)
  //  length 33 : op + uint256(positionId)
  //  0x01 = depositBNB | 0x02 = claimYield | 0x03 = redeemPrincipal
  // ════════════════════════════════════════════════════════════
  // Design intent: a gas-cheap compact call format -- the frontend can complete a deposit with 1 byte of calldata,
  //   without an ABI-encoded 4-byte selector + 32-byte aligned arguments.
  // Pitfall: standard ABI calls **do not** reach here -- CoreVault's named wrappers already capture those selectors.
  // Pitfall: all three ops' implementations depend on the farming layer (_depositBNBCore/_claimYieldCore/_redeemPrincipalCore),
  //   which is exactly why "the farming module must be placed in the same facet as op dispatch": if placed in viewFacet or CoreVault,
  //   it would pull the entire Farming layer back, losing the slimming benefit.
  fallback() external payable {
    if (msg.data.length == 0) revert CoreVault_InvalidAmount();
    uint8 op = uint8(msg.data[0]);
    _guardEnter();
    if (op == 0x02) {
      // claimYield: when BNB is attached, forward it to the insurance pool as well -- **deliberate design** (client-confirmed on 2026-09-24).
      //   WARNING: different from a "bare transfer": a bare transfer is a **mistaken operation with no calldata** (now rejected);
      //      while op 0x02/0x03 carrying BNB is a **call that explicitly carries business intent** --
      //      the caller has specified the op, and the attached BNB is treated as a donation/injection to the insurance pool, forwarded by this function.
      //   Pitfall: do not change it to revert along with the "bare transfer" -- that would break this business path.
      //   Zero-address protection: `_forwardBnbToInsurancePool` explicitly reverts when not wired (avoiding a fund black hole).
      _forwardBnbToInsurancePool();
      uint256 pid = msg.data.length >= 33
        ? uint256(bytes32(msg.data[1:33]))
        : _findActivePosition(msg.sender);
      _claimYieldCore(msg.sender, pid);
    } else if (op == 0x03) {
      // redeemPrincipal: same as above -- a call explicitly carrying an op; attached BNB is forwarded to the insurance pool
      _forwardBnbToInsurancePool();
      uint256 pid = msg.data.length >= 33
        ? uint256(bytes32(msg.data[1:33]))
        : _findActivePosition(msg.sender);
      _redeemPrincipalCore(msg.sender, pid);
    } else if (op == 0x01) {
      // depositBNB: referrer resolution and validation -- equivalent item by item to the 2nd generation
      address referrer;
      if (msg.data.length >= 21) referrer = address(bytes20(msg.data[1:21]));
      if (referrer == msg.sender) { _guardExit(); revert CoreVault_SelfReferral(); }
      if (referrer == address(0)) {
        if (!isRegistered(msg.sender) && _hasUsers) { _guardExit(); revert CoreVault_NoReferrer(); }
        referrer = _refs[msg.sender].referrer;
      } else {
        if (_hasUsers && !isRegistered(msg.sender) && !isRegistered(referrer)) { _guardExit(); revert CoreVault_NoReferrer(); }
      }
      _depositBNBCore(msg.sender, msg.value, referrer);
    } else {
      _guardExit();
      revert CoreVault_UnknownOp(op);
    }
    _guardExit();
  }

  // ════════════════════════════════════════════════════════════
  //  Bare BNB rejection
  // ════════════════════════════════════════════════════════════
  // Design intent: this contract **should not** directly hold BNB -- all its entry points go through CoreVault's DELEGATECALL,
  //   where `address(this)` is CoreVault, the funds belong to CoreVault, and this contract's address is irrelevant.
  //   If someone sends BNB directly to this contract's address, it is a mistaken operation; revert explicitly to avoid funds lingering at an unmanaged address.
  // Note: with a payable fallback but no receive, empty calldata goes to the fallback and reverts due to
  //   `msg.data.length == 0`; declaring receive explicitly here writes that semantics into the ABI layer.
  receive() external payable {
    revert CoreVault_InvalidAmount();
  }

  /// @dev Forward BNB attached to an op call to the insurance pool -- **a deliberate business path** (client-confirmed on 2026-09-24).
  ///   Semantics: the caller has explicitly expressed business intent via `op`; the attached BNB is treated as an injection into the insurance pool, forwarded by this function.
  ///   WARNING: distinguished from a "bare transfer" (empty calldata): the latter is a **mistaken operation with no intent**, already changed to
  ///      an explicit rejection in `CoreVault.receive()`; this path **keeps** forwarding.
  /// Pitfall: when `insurancePool` is not wired, **revert explicitly** rather than silently swallowing -- otherwise the BNB would linger in CoreVault
  ///   with no accounting, a fund black hole.
  function _forwardBnbToInsurancePool() private {
    if (msg.value == 0) return;
    address ip = insurancePool;
    if (ip == address(0)) revert CoreVault_ZeroAddress();
    (bool ok,) = payable(ip).call{value: msg.value}("");
    if (!ok) revert CoreVault_InvalidAmount();
  }
}
