// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Math} from "./math/Math.sol";

/// @notice Embedded multisig + timelock for Vault.
/// - signers propose/approve operations
/// - after delay + threshold approvals, contract executes via exec* functions
contract VaultMultiSigTimeLockContract {
    // ---- Config ----
    uint256 internal minDelay;
    uint256 internal threshold;

    mapping(address => bool) internal isSigner;
    uint256 internal signerCount;

    // ---- Operation storage ----
    struct Operation {
        uint64 approvals;
        uint64 eta;       // timestamp after which it can execute
        uint64 expiresAt;
        bool executed;
        bool canceled;

        address target;
        uint256 value;
        bytes data;
        bytes32 predecessor;
        bytes32 salt;
    }

    mapping(bytes32 => Operation) public ops;
    mapping(bytes32 => mapping(address => bool)) public approvedBy;

    // ---- Events ----
    event VaultMultiSigSignerUpdated(address signer, bool enabled);
    event VaultMultiSigThresholdUpdated(uint256 threshold);
    event VaultMultiSigMinDelayUpdated(uint256 minDelay);

    event VaultMultiSigOperationProposed(bytes32 indexed id,
        uint256 indexed index,
        address target,
        uint256 value,
        bytes data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay);
    event VaultMultiSigOperationApproved(bytes32 indexed id, address indexed signer, uint256 approvals);
    event VaultMultiSigOperationCanceled(bytes32 indexed id);
    event VaultMultiSigOperationExecuted(bytes32 indexed id, uint256 indexed index, address executor, address target, uint256 value, bytes data);

    // ---- Errors ----
    error VaultMultiSigPermissionDeniedError();
    error VaultMultiSigNotSigner();
    error VaultMultiSigBadThreshold();
    error VaultMultiSigBadMinDelay();
    error VaultMultiSigOpNotFound();
    error VaultMultiSigOpNotReady(uint256 eta);
    error VaultMultiSigOpAlreadyApproved();
    error VaultMultiSigOpAlreadyDone();
    error VaultMultiSigOpCanceled();
    error VaultMultiSigOpExpired(uint64 expiresAt);
    error VaultMultiSigOpExpiresAtInvalid();
    error VaultMultiSigOpAlreadyProposed();
    error VaultMultiSigZeroAddress();
    error VaultMultiFailCall();

    modifier onlySigner() {
        if (!isSigner[msg.sender]) revert VaultMultiSigNotSigner();
        _;
    }

    modifier onlyVault(){
        if (msg.sender != address(this)) revert VaultMultiSigPermissionDeniedError();
        _;
    }

    /// @dev Call from child constructor.
    function _initMultiSigTimeLock(
        address[] memory signers_,
        uint256 threshold_,
        uint256 minDelay_
    ) internal {
        if (signerCount != 0) revert VaultMultiSigOpAlreadyDone(); // reuse an existing error; or make MSIG_ALREADY_INIT
        if (signers_.length == 0) revert VaultMultiSigBadThreshold();
        if (minDelay_ == 0) revert VaultMultiSigBadMinDelay();
        if (threshold_ == 0 || threshold_ > signers_.length) revert VaultMultiSigBadThreshold();

        minDelay = minDelay_;
        emit VaultMultiSigMinDelayUpdated(minDelay_);

        for (uint256 i; i < signers_.length; i++) {
            address s = signers_[i];
            if (s == address(0)) revert VaultMultiSigZeroAddress();
            if (isSigner[s]) revert VaultMultiSigOpAlreadyDone();
            isSigner[s] = true;
            signerCount++;
            emit VaultMultiSigSignerUpdated(s, true);
        }

        threshold = threshold_;
        emit VaultMultiSigThresholdUpdated(threshold_);
    }

    function getOperationStatus(bytes32 id)
    external
    view
    returns (
        bool proposed,
        bool ready,
        bool executed,
        bool canceled,
        uint256 approvals,
        uint256 threshold_,
        uint256 eta,
        uint256 remainingDelay,
        address target,
        bytes memory data,
        bytes32 predecessor,
        bytes32 salt
    )
    {
        Operation storage op = ops[id];
        proposed = op.eta != 0;
        executed = op.executed;
        canceled = op.canceled;
        approvals = op.approvals;
        threshold_ = threshold;
        eta = op.eta;
        remainingDelay = eta > block.timestamp ? eta - block.timestamp : 0;
        ready = isOperationReady(id);

        target = op.target;
        data = op.data;
        predecessor = op.predecessor;
        salt = op.salt;
    }

    // ---------- Operation ID (binds action + exact params + nonce) ----------
    function hashOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) public view returns (bytes32) {
        return keccak256(abi.encode(address(this), block.chainid, target, value, data, predecessor, salt));
    }

    // -------- Schedule / Approve / Cancel --------
    function scheduleOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delaySeconds,
        uint256 expiresSeconds
    ) external onlySigner returns (bytes32 id) {
        id = hashOperation(target, value, data, predecessor, salt);
        if(expiresSeconds <= delaySeconds) revert VaultMultiSigOpExpiresAtInvalid();

        Operation storage op = ops[id];
        if (op.eta != 0) revert VaultMultiSigOpAlreadyProposed();

        uint256 delay = Math.max(delaySeconds, minDelay);
        uint256 eta_ = block.timestamp + delay;

        op.target = target;
        op.value = value;
        op.data = data;
        op.predecessor = predecessor;
        op.salt = salt;
        op.eta = uint64(eta_);
        op.expiresAt = uint64 (block.timestamp + expiresSeconds);

        emit VaultMultiSigOperationProposed(id, 0, target, value, data, predecessor, salt, delay);
    }

    function approveOperation(bytes32 id) external onlySigner {
        Operation storage op = ops[id];
        if (op.eta == 0) revert VaultMultiSigOpNotFound();
        if (op.executed) revert VaultMultiSigOpAlreadyDone();
        if (op.canceled) revert VaultMultiSigOpCanceled();
        if(block.timestamp >= op.expiresAt ) revert VaultMultiSigOpExpired(op.expiresAt);
        if (approvedBy[id][msg.sender]) revert VaultMultiSigOpAlreadyApproved();

        approvedBy[id][msg.sender] = true;
        op.approvals += 1;
        emit VaultMultiSigOperationApproved(id, msg.sender, op.approvals);
    }

    function cancelOperation(bytes32 id) external onlySigner {
        Operation storage op = ops[id];
        if (op.eta == 0) revert VaultMultiSigOpNotFound();
        if (op.executed) revert VaultMultiSigOpAlreadyDone();

        op.canceled = true;
        emit VaultMultiSigOperationCanceled(id);
    }

    // -------- Execute --------
    function isOperationReady(bytes32 id) public view returns (bool) {
        Operation storage op = ops[id];
        return op.eta != 0 && !op.executed && !op.canceled && op.approvals >= threshold && block.timestamp >= op.eta && block.timestamp < op.expiresAt;
    }

    function executeOperation(bytes32 id) external payable onlySigner {
        Operation storage op = ops[id];
        if (op.eta == 0) revert VaultMultiSigOpNotFound();
        if (op.canceled) revert VaultMultiSigOpCanceled();
        if (op.executed) revert VaultMultiSigOpAlreadyDone();
        if (op.approvals < threshold) revert VaultMultiSigBadThreshold();
        if (block.timestamp < op.eta) revert VaultMultiSigOpNotReady(op.eta);
        if(block.timestamp >= op.expiresAt ) revert VaultMultiSigOpExpired(op.expiresAt);

        // Optional predecessor enforcement
        if (op.predecessor != bytes32(0)) {
            Operation storage pre = ops[op.predecessor];
            if (!pre.executed) revert VaultMultiSigOpNotReady(pre.eta);
        }

        op.executed = true;

        (bool ok,) = op.target.call{value: op.value}(op.data);
        if (!ok) revert VaultMultiFailCall();

        emit VaultMultiSigOperationExecuted(id, 0, msg.sender, op.target, op.value, op.data);
    }

    // ---------- Self-governance (recommended timelocked) ----------
    function execSetSigner(address signer, bool enabled)
    external onlyVault
    {
        if (signer == address(0)) revert VaultMultiSigZeroAddress();

        if (enabled && !isSigner[signer]) {
            isSigner[signer] = true;
            signerCount++;
        } else if (!enabled && isSigner[signer]) {
            isSigner[signer] = false;
            signerCount--;
        }
        emit VaultMultiSigSignerUpdated(signer, enabled);

        // keep threshold valid
        if (threshold == 0 || threshold > signerCount) revert VaultMultiSigBadThreshold();
    }

    function execSetThreshold(uint256 newThreshold)
    external onlyVault
    {
        if (newThreshold == 0 || newThreshold > signerCount) revert VaultMultiSigBadThreshold();
        threshold = newThreshold;
        emit VaultMultiSigThresholdUpdated(newThreshold);
    }

    function execSetMinDelay(uint256 newMinDelay)
    external onlyVault
    {
        if (newMinDelay == 0) revert VaultMultiSigBadMinDelay();
        minDelay = newMinDelay;
        emit VaultMultiSigMinDelayUpdated(newMinDelay);
    }
}