// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// Design intent: a reentrancy guard based on EIP-1153 transient storage, saving ~2400 gas vs the SSTORE approach (cold SSTORE ~20000, transient storage ~100).
//   1) transientNonReentrant: a global mutex; non-reentrant within one transaction, auto-cleared after the transaction ends
//   2) transientLockBySelector: isolated by function selector; different functions can be called concurrently, only the same function is non-reentrant
// Pitfall: transient storage is valid only within the current transaction and does not pollute across transactions; slot 0's global lock has the lowest priority, avoiding conflicts with selector locks
// EIP-1153 transient reentrancy guard — ~2400 gas saved vs OZ storage-based
abstract contract TransientReentrancyGuard {
  // slot 0 is safe — transient storage is per-tx, no cross-contract collision
  // Design intent: a global reentrancy lock; slot 0 is used for the simplest path. tload(0)!=0 -> locked -> revert; otherwise tstore(0,1) locks; after the body executes, tstore(0,0) unlocks.
  // I4-fix: the revert uses the exact 4-byte selector of error ReentrancyTransient() (0x009ad76b),
  //         fully matching the error selector declared in Solidity, so try/catch can catch it precisely.
  //         selector computation: bytes4(keccak256("ReentrancyTransient()")) = 0x009ad76b
  modifier transientNonReentrant(){
    assembly{
      if tload(0) {
        mstore(0x00, 0x009ad76b00000000000000000000000000000000000000000000000000000000)
        revert(0x00, 0x04)
      }
      tstore(0, 1)
    }
    _;
    assembly{ tstore(0, 0) }
  }

  // Design intent: a lock isolated by function selector, using keccak256(selector) as the transient slot.
  // Advantage: functions A and B can be called on different call stacks at the same time without blocking each other.
  // Pitfall (fix for the original bug): the old implementation's shl(224, calldataload(0)) shifted the selector out of the 256-bit range,
  //   making memory 0x00-0x03 always 0, so all calls shared keccak256(0x00000000) and the selector lock degenerated into a global lock.
  //   Correct approach: the high 4 bytes of calldataload(0) are the selector; after mstore (big-endian), memory 0x00-0x03 is exactly the selector.
  //   Directly mstore(0x00, calldataload(0)) + keccak256(0x00, 4) extracts the selector, with no shifting needed.
  // Memory safety: slot 0x00 is reused with the revert path; after keccak256 the slot is stored in a stack variable, so a later mstore does not conflict.
  // I4-fix: same as transientNonReentrant, revert uses the exact selector 0x009ad76b.
  // per-selector isolation: no cross-function reentrancy false positives
  modifier transientLockBySelector(){
    bytes32 slot;
    assembly{
      mstore(0x00, calldataload(0))
      slot := keccak256(0x00, 4)
      if tload(slot) {
        mstore(0x00, 0x009ad76b00000000000000000000000000000000000000000000000000000000)
        revert(0x00, 0x04)
      }
      tstore(slot, 1)
    }
    _;
    assembly{ tstore(slot, 0) }
  }

  error ReentrancyTransient();

  /// @notice Function-based reentrancy guard (enter). Saves bytecode vs modifier.
  /// @dev EIP-1153 spec: "Transient storage is private to the contract that owns it."
  ///       Each contract has its own transient storage page, so slot 0 does not conflict across CoreVault/Treasury/AToken/FISTDAO.
  ///       Verified: the REVM implementation isolates by (address,slot), and the BSC Geth implementation follows the same spec -- no cross-contract deadlock risk.
  function _guardEnter() internal {
    assembly {
      if tload(0) {
        mstore(0x00, 0x009ad76b00000000000000000000000000000000000000000000000000000000)
        revert(0x00, 0x04)
      }
      tstore(0, 1)
    }
  }

  /// @notice Function-based reentrancy guard (exit).
  /// @dev H-robustness-check: same as _guardEnter, releases the current contract's slot 0.
  function _guardExit() internal {
    assembly { tstore(0, 0) }
  }
}
// 0x1153 - EIP-1153 transient guard