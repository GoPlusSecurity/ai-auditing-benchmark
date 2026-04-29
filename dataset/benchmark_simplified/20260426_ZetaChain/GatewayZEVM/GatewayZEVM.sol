// SPDX-License-Identifier: MIT
pragma solidity =0.8.26 ^0.8.20;

// --- Revert & call options (required by `call` and `Called` event) ---

/// @notice Revert options (same fields as full protocol; only used for event payload here).
struct RevertOptions {
    address revertAddress;
    bool callOnRevert;
    address abortAddress;
    bytes revertMessage;
    uint256 onRevertGasLimit;
}

/// @notice Call options for cross-chain call.
struct CallOptions {
    uint256 gasLimit;
    bool isArbitraryCall;
}

// --- ZRC20 surface used by `call` / `_call` ---

/// @title IZRC20 (minimal for `call` call tree)
interface IZRC20 {
    function withdrawGasFeeWithGasLimit(uint256 gasLimit) external view returns (address, uint256);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

// --- Gateway events / errors / interface (only `call` entry) ---

/// @title IGatewayZEVMEvents
interface IGatewayZEVMEvents {
    event Called(
        address indexed sender,
        address indexed zrc20,
        bytes receiver,
        bytes message,
        CallOptions callOptions,
        RevertOptions revertOptions
    );
}

/// @title IGatewayZEVMErrors
interface IGatewayZEVMErrors {
    error GasFeeTransferFailed();
    error InsufficientGasLimit();
    error MessageSizeExceeded();
}

/// @title IGatewayZEVM
/// @dev Simplified: only the cross-chain `call` entrypoint.
interface IGatewayZEVM is IGatewayZEVMErrors, IGatewayZEVMEvents {
    function call(
        bytes memory receiver,
        address zrc20,
        bytes calldata message,
        CallOptions calldata callOptions,
        RevertOptions calldata revertOptions
    )
        external;
}

// --- Implementation: `call` and `_call` only ---

/// @title GatewayZEVM
/// @notice Simplified contract: only `call()` and its private implementation `_call()`.
/// @dev Pause is represented as a single storage slot with no public toggles in this slice
/// (default unpaused), preserving the `whenNotPaused` check on the `call` path.
contract GatewayZEVM is IGatewayZEVM {
    /// @notice Error indicating a zero address was provided.
    error ZeroAddress();

    /// @dev Mirrors OpenZeppelin `Pausable` when contract is paused.
    error EnforcedPause();

    /// @notice The constant address of the protocol.
    address public constant PROTOCOL_ADDRESS = 0x735b14BB79463307AAcBED86DAf3322B1e6226aB;

    /// @notice Max size of message + revertOptions revert message.
    uint256 public constant MAX_MESSAGE_SIZE = 2880;

    /// @notice Minimum gas limit for a call.
    uint256 public constant MIN_GAS_LIMIT = 100_000;

    /// @dev Pausable state (not exposed; default false = not paused). No public pause/unpause in this simplified file.
    bool private _paused;

    modifier whenNotPaused() {
        if (_paused) {
            revert EnforcedPause();
        }
        _;
    }

    function call(
        bytes memory receiver,
        address zrc20,
        bytes calldata message,
        CallOptions calldata callOptions,
        RevertOptions calldata revertOptions
    )
        external
        whenNotPaused
    {
        if (callOptions.gasLimit < MIN_GAS_LIMIT) revert InsufficientGasLimit();
        if (message.length + revertOptions.revertMessage.length > MAX_MESSAGE_SIZE) revert MessageSizeExceeded();

        _call(receiver, zrc20, message, callOptions, revertOptions);
    }

    function _call(
        bytes memory receiver,
        address zrc20,
        bytes calldata message,
        CallOptions memory callOptions,
        RevertOptions memory revertOptions
    )
        private
    {
        if (receiver.length == 0) revert ZeroAddress();

        (address gasZRC20, uint256 gasFee) = IZRC20(zrc20).withdrawGasFeeWithGasLimit(callOptions.gasLimit);
        if (!IZRC20(gasZRC20).transferFrom(msg.sender, PROTOCOL_ADDRESS, gasFee)) {
            revert GasFeeTransferFailed();
        }

        emit Called(msg.sender, zrc20, receiver, message, callOptions, revertOptions);
    }
}
