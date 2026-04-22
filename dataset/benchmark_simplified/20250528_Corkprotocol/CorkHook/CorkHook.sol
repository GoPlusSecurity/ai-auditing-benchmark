// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {LiquidityMath} from "./lib/LiquidityMath.sol";
import {SwapMath} from "./lib/SwapMath.sol";
import {SenderSlot} from "./lib/SenderSlot.sol";
import "./interfaces/ILiquidityToken.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IERC20Metadata.sol";
import "./interfaces/IERC20Burnable.sol";
import "./interfaces/IERC20Minimal.sol";
import "./interfaces/IExpiry.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IErrors.sol";
import "./interfaces/ICorkHook.sol";
import "./interfaces/CorkSwapCallback.sol";

// NOTE: `./lib/State.sol` and `./lib/Calls.sol` are inlined below to avoid pulling in `v4-periphery` imports.

// ------------------------------------------------------------------------------------------
// Inlined project-local dependencies (flattened from `Cork-Hook/src`)
// ------------------------------------------------------------------------------------------

library Constants {
    // we will use our own fee, no need for uni v4 fee
    uint24 internal constant FEE = 0;
    // default tick spacing since we don't actually use it, so we just set it to 1
    int24 internal constant TICK_SPACING = 1;
    // default sqrt price, we don't really use this one either
    uint160 internal constant SQRT_PRICE_1_1 = 79228162514264337593543950336;
}

// ------------------------------------------------------------------------------------------
// Inlined OpenZeppelin dependencies (flattened from `openzeppelin-contracts/contracts`)
// Minimal subset needed by this file (Ownable/Clones/Strings/SafeERC20 + dependencies).
// ------------------------------------------------------------------------------------------

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

library Errors {
    error InsufficientBalance(uint256 balance, uint256 needed);
    error FailedCall();
    error FailedDeployment();
    error MissingPrecompile(address);
}

library Create2 {
    error Create2EmptyBytecode();

    function deploy(uint256 amount, bytes32 salt, bytes memory bytecode) internal returns (address addr) {
        if (address(this).balance < amount) {
            revert Errors.InsufficientBalance(address(this).balance, amount);
        }
        if (bytecode.length == 0) {
            revert Create2EmptyBytecode();
        }
        assembly ("memory-safe") {
            addr := create2(amount, add(bytecode, 0x20), mload(bytecode), salt)
            if and(iszero(addr), not(iszero(returndatasize()))) {
                let p := mload(0x40)
                returndatacopy(p, 0, returndatasize())
                revert(p, returndatasize())
            }
        }
        if (addr == address(0)) {
            revert Errors.FailedDeployment();
        }
    }

    function computeAddress(bytes32 salt, bytes32 bytecodeHash) internal view returns (address) {
        return computeAddress(salt, bytecodeHash, address(this));
    }

    function computeAddress(bytes32 salt, bytes32 bytecodeHash, address deployer) internal pure returns (address addr) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(add(ptr, 0x40), bytecodeHash)
            mstore(add(ptr, 0x20), salt)
            mstore(ptr, deployer)
            let start := add(ptr, 0x0b)
            mstore8(start, 0xff)
            addr := and(keccak256(start, 85), 0xffffffffffffffffffffffffffffffffffffffff)
        }
    }
}

library Clones {
    error CloneArgumentsTooLong();

    function clone(address implementation) internal returns (address instance) {
        return clone(implementation, 0);
    }

    function clone(address implementation, uint256 value) internal returns (address instance) {
        if (address(this).balance < value) {
            revert Errors.InsufficientBalance(address(this).balance, value);
        }
        assembly ("memory-safe") {
            mstore(0x00, or(shr(0xe8, shl(0x60, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            mstore(0x20, or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3))
            instance := create(value, 0x09, 0x37)
        }
        if (instance == address(0)) {
            revert Errors.FailedDeployment();
        }
    }

    function cloneDeterministic(address implementation, bytes32 salt) internal returns (address instance) {
        return cloneDeterministic(implementation, salt, 0);
    }

    function cloneDeterministic(
        address implementation,
        bytes32 salt,
        uint256 value
    ) internal returns (address instance) {
        if (address(this).balance < value) {
            revert Errors.InsufficientBalance(address(this).balance, value);
        }
        assembly ("memory-safe") {
            mstore(0x00, or(shr(0xe8, shl(0x60, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            mstore(0x20, or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3))
            instance := create2(value, 0x09, 0x37, salt)
        }
        if (instance == address(0)) {
            revert Errors.FailedDeployment();
        }
    }

    function predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(add(ptr, 0x38), deployer)
            mstore(add(ptr, 0x24), 0x5af43d82803e903d91602b57fd5bf3ff)
            mstore(add(ptr, 0x14), implementation)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73)
            mstore(add(ptr, 0x58), salt)
            mstore(add(ptr, 0x78), keccak256(add(ptr, 0x0c), 0x37))
            predicted := and(keccak256(add(ptr, 0x43), 0x55), 0xffffffffffffffffffffffffffffffffffffffff)
        }
    }

    function predictDeterministicAddress(address implementation, bytes32 salt) internal view returns (address predicted) {
        return predictDeterministicAddress(implementation, salt, address(this));
    }

    function cloneWithImmutableArgs(address implementation, bytes memory args) internal returns (address instance) {
        return cloneWithImmutableArgs(implementation, args, 0);
    }

    function cloneWithImmutableArgs(
        address implementation,
        bytes memory args,
        uint256 value
    ) internal returns (address instance) {
        if (address(this).balance < value) {
            revert Errors.InsufficientBalance(address(this).balance, value);
        }
        bytes memory bytecode = _cloneCodeWithImmutableArgs(implementation, args);
        assembly ("memory-safe") {
            instance := create(value, add(bytecode, 0x20), mload(bytecode))
        }
        if (instance == address(0)) {
            revert Errors.FailedDeployment();
        }
    }

    function cloneDeterministicWithImmutableArgs(
        address implementation,
        bytes memory args,
        bytes32 salt
    ) internal returns (address instance) {
        return cloneDeterministicWithImmutableArgs(implementation, args, salt, 0);
    }

    function cloneDeterministicWithImmutableArgs(
        address implementation,
        bytes memory args,
        bytes32 salt,
        uint256 value
    ) internal returns (address instance) {
        bytes memory bytecode = _cloneCodeWithImmutableArgs(implementation, args);
        return Create2.deploy(value, salt, bytecode);
    }

    function predictDeterministicAddressWithImmutableArgs(
        address implementation,
        bytes memory args,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        bytes memory bytecode = _cloneCodeWithImmutableArgs(implementation, args);
        return Create2.computeAddress(salt, keccak256(bytecode), deployer);
    }

    function predictDeterministicAddressWithImmutableArgs(
        address implementation,
        bytes memory args,
        bytes32 salt
    ) internal view returns (address predicted) {
        return predictDeterministicAddressWithImmutableArgs(implementation, args, salt, address(this));
    }

    function fetchCloneArgs(address instance) internal view returns (bytes memory) {
        bytes memory result = new bytes(instance.code.length - 45);
        assembly ("memory-safe") {
            extcodecopy(instance, add(result, 32), 45, mload(result))
        }
        return result;
    }

    function _cloneCodeWithImmutableArgs(
        address implementation,
        bytes memory args
    ) private pure returns (bytes memory) {
        if (args.length > 24531) revert CloneArgumentsTooLong();
        return
            abi.encodePacked(
                hex"61",
                uint16(args.length + 45),
                hex"3d81600a3d39f3363d3d373d3d3d363d73",
                implementation,
                hex"5af43d82803e903d91602b57fd5bf3",
                args
            );
    }
}

library Strings {
    bytes16 private constant _HEX_DIGITS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    error StringsInsufficientHexLength(uint256 value, uint256 length);

    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, _log256(value) + 1);
        }
    }

    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        uint256 localValue = value;
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_DIGITS[localValue & 0xf];
            localValue >>= 4;
        }
        if (localValue != 0) {
            revert StringsInsufficientHexLength(value, length);
        }
        return string(buffer);
    }

    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }

    function _log256(uint256 x) private pure returns (uint256 r) {
        if (x >> 128 > 0) {
            x >>= 128;
            r += 16;
        }
        if (x >> 64 > 0) {
            x >>= 64;
            r += 8;
        }
        if (x >> 32 > 0) {
            x >>= 32;
            r += 4;
        }
        if (x >> 16 > 0) {
            x >>= 16;
            r += 2;
        }
        if (x >> 8 > 0) {
            r += 1;
        }
    }
}

library SafeERC20 {
    error SafeERC20FailedOperation(address token);

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") {
            let success := call(gas(), token, 0, add(data, 0x20), mload(data), 0, 0x20)
            if iszero(success) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
            returnSize := returndatasize()
            returnValue := mload(0)
        }
        if (returnSize == 0 ? address(token).code.length == 0 : returnValue != 1) {
            revert SafeERC20FailedOperation(address(token));
        }
    }
}

abstract contract Ownable is Context {
    address private _owner;

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() internal view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    // function renounceOwnership() public virtual onlyOwner {
    //     _transferOwnership(address(0));
    // }

    // function transferOwnership(address newOwner) public virtual onlyOwner {
    //     if (newOwner == address(0)) {
    //         revert OwnableInvalidOwner(address(0));
    //     }
    //     _transferOwnership(newOwner);
    // }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// ------------------------------------------------------------------------------------------
// Inlined Depeg-swap dependencies (flattened from `Cork-Hook/lib/Depeg-swap`)
// ------------------------------------------------------------------------------------------

library TransferHelper {
    uint8 internal constant TARGET_DECIMALS = 18;

    function normalizeDecimals(uint256 amount, uint8 decimalsBefore, uint8 decimalsAfter)
        internal
        pure
        returns (uint256)
    {
        if (decimalsBefore > decimalsAfter) {
            amount = amount / 10 ** (decimalsBefore - decimalsAfter);
        } else if (decimalsBefore < decimalsAfter) {
            amount = amount * 10 ** (decimalsAfter - decimalsBefore);
        }
        return amount;
    }

    function tokenNativeDecimalsToFixed(uint256 amount, IERC20Metadata token) internal view returns (uint256) {
        uint8 decimals = token.decimals();
        return normalizeDecimals(amount, decimals, TARGET_DECIMALS);
    }

    function tokenNativeDecimalsToFixed(uint256 amount, address token) internal view returns (uint256) {
        return tokenNativeDecimalsToFixed(amount, IERC20Metadata(token));
    }

    function fixedToTokenNativeDecimals(uint256 amount, IERC20Metadata token) internal view returns (uint256) {
        uint8 decimals = token.decimals();
        return normalizeDecimals(amount, TARGET_DECIMALS, decimals);
    }

    function fixedToTokenNativeDecimals(uint256 amount, address token) internal view returns (uint256) {
        return fixedToTokenNativeDecimals(amount, IERC20Metadata(token));
    }

    function transferNormalize(IERC20 token, address _to, uint256 _amount) internal returns (uint256 amount) {
        amount = fixedToTokenNativeDecimals(_amount, token);
        SafeERC20.safeTransfer(token, _to, amount);
    }

    function transferNormalize(address token, address _to, uint256 _amount) internal returns (uint256 amount) {
        return transferNormalize(IERC20(token), _to, _amount);
    }

    function transferFromNormalize(IERC20 token, address _from, uint256 _amount) internal returns (uint256 amount) {
        amount = fixedToTokenNativeDecimals(_amount, token);
        SafeERC20.safeTransferFrom(token, _from, address(this), amount);
    }

    function transferFromNormalize(address token, address _from, uint256 _amount) internal returns (uint256 amount) {
        return transferFromNormalize(IERC20(token), _from, _amount);
    }

    function burnNormalize(IERC20Burnable token, uint256 _amount) internal returns (uint256 amount) {
        amount = fixedToTokenNativeDecimals(_amount, token);
        token.burn(amount);
    }

    function burnNormalize(address token, uint256 _amount) internal returns (uint256 amount) {
        return burnNormalize(IERC20Burnable(token), _amount);
    }
}

// ------------------------------------------------------------------------------------------
// Inlined Uniswap v4-periphery / v4-core dependencies (flattened from `Cork-Hook/lib/v4-periphery`)
// ------------------------------------------------------------------------------------------

/// @title Library for reverting with custom errors efficiently
/// @notice Contains functions for reverting with custom errors with different argument types efficiently
/// @dev To use this library, declare `using CustomRevert for bytes4;` and replace `revert CustomError()` with
/// `CustomError.selector.revertWith()`
/// @dev The functions may tamper with the free memory pointer but it is fine since the call context is exited immediately
library CustomRevert {
    /// @dev ERC-7751 error for wrapping bubbled up reverts
    error WrappedError(address target, bytes4 selector, bytes reason, bytes details);

    /// @dev Reverts with the selector of a custom error in the scratch space
    function revertWith(bytes4 selector) internal pure {
        assembly ("memory-safe") {
            mstore(0, selector)
            revert(0, 0x04)
        }
    }

    /// @dev Reverts with a custom error with an address argument in the scratch space
    function revertWith(bytes4 selector, address addr) internal pure {
        assembly ("memory-safe") {
            mstore(0, selector)
            mstore(0x04, and(addr, 0xffffffffffffffffffffffffffffffffffffffff))
            revert(0, 0x24)
        }
    }

    /// @dev Reverts with a custom error with an int24 argument in the scratch space
    function revertWith(bytes4 selector, int24 value) internal pure {
        assembly ("memory-safe") {
            mstore(0, selector)
            mstore(0x04, signextend(2, value))
            revert(0, 0x24)
        }
    }

    /// @dev Reverts with a custom error with a uint160 argument in the scratch space
    function revertWith(bytes4 selector, uint160 value) internal pure {
        assembly ("memory-safe") {
            mstore(0, selector)
            mstore(0x04, and(value, 0xffffffffffffffffffffffffffffffffffffffff))
            revert(0, 0x24)
        }
    }

    /// @dev Reverts with a custom error with two int24 arguments
    function revertWith(bytes4 selector, int24 value1, int24 value2) internal pure {
        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(fmp, selector)
            mstore(add(fmp, 0x04), signextend(2, value1))
            mstore(add(fmp, 0x24), signextend(2, value2))
            revert(fmp, 0x44)
        }
    }

    /// @dev Reverts with a custom error with two uint160 arguments
    function revertWith(bytes4 selector, uint160 value1, uint160 value2) internal pure {
        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(fmp, selector)
            mstore(add(fmp, 0x04), and(value1, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(fmp, 0x24), and(value2, 0xffffffffffffffffffffffffffffffffffffffff))
            revert(fmp, 0x44)
        }
    }

    /// @dev Reverts with a custom error with two address arguments
    function revertWith(bytes4 selector, address value1, address value2) internal pure {
        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(fmp, selector)
            mstore(add(fmp, 0x04), and(value1, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(fmp, 0x24), and(value2, 0xffffffffffffffffffffffffffffffffffffffff))
            revert(fmp, 0x44)
        }
    }

    /// @notice bubble up the revert message returned by a call and revert with a wrapped ERC-7751 error
    /// @dev this method can be vulnerable to revert data bombs
    function bubbleUpAndRevertWith(
        address revertingContract,
        bytes4 revertingFunctionSelector,
        bytes4 additionalContext
    ) internal pure {
        bytes4 wrappedErrorSelector = WrappedError.selector;
        assembly ("memory-safe") {
            // Ensure the size of the revert data is a multiple of 32 bytes
            let encodedDataSize := mul(div(add(returndatasize(), 31), 32), 32)

            let fmp := mload(0x40)

            // Encode wrapped error selector, address, function selector, offset, additional context, size, revert reason
            mstore(fmp, wrappedErrorSelector)
            mstore(add(fmp, 0x04), and(revertingContract, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(
                add(fmp, 0x24),
                and(revertingFunctionSelector, 0xffffffff00000000000000000000000000000000000000000000000000000000)
            )
            // offset revert reason
            mstore(add(fmp, 0x44), 0x80)
            // offset additional context
            mstore(add(fmp, 0x64), add(0xa0, encodedDataSize))
            // size revert reason
            mstore(add(fmp, 0x84), returndatasize())
            // revert reason
            returndatacopy(add(fmp, 0xa4), 0, returndatasize())
            // size additional context
            mstore(add(fmp, add(0xa4, encodedDataSize)), 0x04)
            // additional context
            mstore(
                add(fmp, add(0xc4, encodedDataSize)),
                and(additionalContext, 0xffffffff00000000000000000000000000000000000000000000000000000000)
            )
            revert(fmp, add(0xe4, encodedDataSize))
        }
    }
}

/// @notice Parses bytes returned from hooks and the byte selector used to check return selectors from hooks.
/// @dev parseSelector also is used to parse the expected selector
/// For parsing hook returns, note that all hooks return either bytes4 or (bytes4, 32-byte-delta) or (bytes4, 32-byte-delta, uint24).
library ParseBytes {
    function parseSelector(bytes memory result) internal pure returns (bytes4 selector) {
        // equivalent: (selector,) = abi.decode(result, (bytes4, int256));
        assembly ("memory-safe") {
            selector := mload(add(result, 0x20))
        }
    }

    function parseFee(bytes memory result) internal pure returns (uint24 lpFee) {
        // equivalent: (,, lpFee) = abi.decode(result, (bytes4, int256, uint24));
        assembly ("memory-safe") {
            lpFee := mload(add(result, 0x60))
        }
    }

    function parseReturnDelta(bytes memory result) internal pure returns (int256 hookReturn) {
        // equivalent: (, hookReturnDelta) = abi.decode(result, (bytes4, int256));
        assembly ("memory-safe") {
            hookReturn := mload(add(result, 0x40))
        }
    }
}

/// @notice Library of helper functions for a pools LP fee
library LPFeeLibrary {
    using LPFeeLibrary for uint24;
    using CustomRevert for bytes4;

    /// @notice Thrown when the static or dynamic fee on a pool exceeds 100%.
    error LPFeeTooLarge(uint24 fee);

    /// @notice An lp fee of exactly 0b1000000... signals a dynamic fee pool. This isn't a valid static fee as it is > MAX_LP_FEE
    uint24 public constant DYNAMIC_FEE_FLAG = 0x800000;

    /// @notice the second bit of the fee returned by beforeSwap is used to signal if the stored LP fee should be overridden in this swap
    // only dynamic-fee pools can return a fee via the beforeSwap hook
    uint24 public constant OVERRIDE_FEE_FLAG = 0x400000;

    /// @notice mask to remove the override fee flag from a fee returned by the beforeSwaphook
    uint24 public constant REMOVE_OVERRIDE_MASK = 0xBFFFFF;

    /// @notice the lp fee is represented in hundredths of a bip, so the max is 100%
    uint24 public constant MAX_LP_FEE = 1000000;

    /// @notice returns true if a pool's LP fee signals that the pool has a dynamic fee
    /// @param self The fee to check
    /// @return bool True of the fee is dynamic
    function isDynamicFee(uint24 self) internal pure returns (bool) {
        return self == DYNAMIC_FEE_FLAG;
    }

    /// @notice returns true if an LP fee is valid, aka not above the maximum permitted fee
    /// @param self The fee to check
    /// @return bool True of the fee is valid
    function isValid(uint24 self) internal pure returns (bool) {
        return self <= MAX_LP_FEE;
    }

    /// @notice validates whether an LP fee is larger than the maximum, and reverts if invalid
    /// @param self The fee to validate
    function validate(uint24 self) internal pure {
        if (!self.isValid()) LPFeeTooLarge.selector.revertWith(self);
    }

    /// @notice gets and validates the initial LP fee for a pool. Dynamic fee pools have an initial fee of 0.
    /// @dev if a dynamic fee pool wants a non-0 initial fee, it should call `updateDynamicLPFee` in the afterInitialize hook
    /// @param self The fee to get the initial LP from
    /// @return initialFee 0 if the fee is dynamic, otherwise the fee (if valid)
    function getInitialLPFee(uint24 self) internal pure returns (uint24) {
        // the initial fee for a dynamic fee pool is 0
        if (self.isDynamicFee()) return 0;
        self.validate();
        return self;
    }

    /// @notice returns true if the fee has the override flag set (2nd highest bit of the uint24)
    /// @param self The fee to check
    /// @return bool True of the fee has the override flag set
    function isOverride(uint24 self) internal pure returns (bool) {
        return self & OVERRIDE_FEE_FLAG != 0;
    }

    /// @notice returns a fee with the override flag removed
    /// @param self The fee to remove the override flag from
    /// @return fee The fee without the override flag set
    function removeOverrideFlag(uint24 self) internal pure returns (uint24) {
        return self & REMOVE_OVERRIDE_MASK;
    }

    /// @notice Removes the override flag and validates the fee (reverts if the fee is too large)
    /// @param self The fee to remove the override flag from, and then validate
    /// @return fee The fee without the override flag set (if valid)
    function removeOverrideFlagAndValidate(uint24 self) internal pure returns (uint24 fee) {
        fee = self.removeOverrideFlag();
        fee.validate();
    }
}

/// @title Safe casting methods
/// @notice Contains methods for safely casting between types
library SafeCast {
    using CustomRevert for bytes4;

    error SafeCastOverflow();

    /// @notice Cast a uint256 to a uint160, revert on overflow
    /// @param x The uint256 to be downcasted
    /// @return y The downcasted integer, now type uint160
    function toUint160(uint256 x) internal pure returns (uint160 y) {
        y = uint160(x);
        if (y != x) SafeCastOverflow.selector.revertWith();
    }

    /// @notice Cast a uint256 to a uint128, revert on overflow
    /// @param x The uint256 to be downcasted
    /// @return y The downcasted integer, now type uint128
    function toUint128(uint256 x) internal pure returns (uint128 y) {
        y = uint128(x);
        if (x != y) SafeCastOverflow.selector.revertWith();
    }

    /// @notice Cast a int128 to a uint128, revert on overflow or underflow
    /// @param x The int128 to be casted
    /// @return y The casted integer, now type uint128
    function toUint128(int128 x) internal pure returns (uint128 y) {
        if (x < 0) SafeCastOverflow.selector.revertWith();
        y = uint128(x);
    }

    /// @notice Cast a int256 to a int128, revert on overflow or underflow
    /// @param x The int256 to be downcasted
    /// @return y The downcasted integer, now type int128
    function toInt128(int256 x) internal pure returns (int128 y) {
        y = int128(x);
        if (y != x) SafeCastOverflow.selector.revertWith();
    }

    /// @notice Cast a uint256 to a int256, revert on overflow
    /// @param x The uint256 to be casted
    /// @return y The casted integer, now type int256
    function toInt256(uint256 x) internal pure returns (int256 y) {
        y = int256(x);
        if (y < 0) SafeCastOverflow.selector.revertWith();
    }

    /// @notice Cast a uint256 to a int128, revert on overflow
    /// @param x The uint256 to be downcasted
    /// @return The downcasted integer, now type int128
    function toInt128(uint256 x) internal pure returns (int128) {
        if (x >= 1 << 127) SafeCastOverflow.selector.revertWith();
        return int128(int256(x));
    }
}

type Currency is address;

using {greaterThan as >, lessThan as <, greaterThanOrEqualTo as >=, equals as ==} for Currency global;
using CurrencyLibrary for Currency global;

function equals(Currency currency, Currency other) pure returns (bool) {
    return Currency.unwrap(currency) == Currency.unwrap(other);
}

function greaterThan(Currency currency, Currency other) pure returns (bool) {
    return Currency.unwrap(currency) > Currency.unwrap(other);
}

function lessThan(Currency currency, Currency other) pure returns (bool) {
    return Currency.unwrap(currency) < Currency.unwrap(other);
}

function greaterThanOrEqualTo(Currency currency, Currency other) pure returns (bool) {
    return Currency.unwrap(currency) >= Currency.unwrap(other);
}

/// @title CurrencyLibrary
/// @dev This library allows for transferring and holding native tokens and ERC20 tokens
library CurrencyLibrary {
    /// @notice Additional context for ERC-7751 wrapped error when a native transfer fails
    error NativeTransferFailed();

    /// @notice Additional context for ERC-7751 wrapped error when an ERC20 transfer fails
    error ERC20TransferFailed();

    /// @notice A constant to represent the native currency
    Currency public constant ADDRESS_ZERO = Currency.wrap(address(0));

    function transfer(Currency currency, address to, uint256 amount) internal {
        bool success;
        if (currency.isAddressZero()) {
            assembly ("memory-safe") {
                success := call(gas(), to, amount, 0, 0, 0, 0)
            }
            if (!success) {
                CustomRevert.bubbleUpAndRevertWith(to, bytes4(0), NativeTransferFailed.selector);
            }
        } else {
            assembly ("memory-safe") {
                let fmp := mload(0x40)
                mstore(fmp, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
                mstore(add(fmp, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff))
                mstore(add(fmp, 36), amount)

                success :=
                    and(
                        or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                        call(gas(), currency, 0, fmp, 68, 0, 32)
                    )

                mstore(fmp, 0)
                mstore(add(fmp, 0x20), 0)
                mstore(add(fmp, 0x40), 0)
            }
            if (!success) {
                CustomRevert.bubbleUpAndRevertWith(
                    Currency.unwrap(currency), IERC20Minimal.transfer.selector, ERC20TransferFailed.selector
                );
            }
        }
    }

    function balanceOfSelf(Currency currency) internal view returns (uint256) {
        if (currency.isAddressZero()) {
            return address(this).balance;
        } else {
            return IERC20Minimal(Currency.unwrap(currency)).balanceOf(address(this));
        }
    }

    function balanceOf(Currency currency, address owner) internal view returns (uint256) {
        if (currency.isAddressZero()) {
            return owner.balance;
        } else {
            return IERC20Minimal(Currency.unwrap(currency)).balanceOf(owner);
        }
    }

    function isAddressZero(Currency currency) internal pure returns (bool) {
        return Currency.unwrap(currency) == Currency.unwrap(ADDRESS_ZERO);
    }

    function toId(Currency currency) internal pure returns (uint256) {
        return uint160(Currency.unwrap(currency));
    }

    function fromId(uint256 id) internal pure returns (Currency) {
        return Currency.wrap(address(uint160(id)));
    }
}

type PoolId is bytes32;

/// @notice Library for computing the ID of a pool
library PoolIdLibrary {
    /// @notice Returns value equal to keccak256(abi.encode(poolKey))
    function toId(PoolKey memory poolKey) internal pure returns (PoolId poolId) {
        assembly ("memory-safe") {
            poolId := keccak256(poolKey, 0xa0)
        }
    }
}

/// @notice V4 decides whether to invoke specific hooks by inspecting the least significant bits
/// of the address that the hooks contract is deployed to.
/// See the Hooks library for the full spec.
/// @dev Should only be callable by the v4 PoolManager.
interface IHooks {
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        PoolManagerSwapParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4, BeforeSwapDelta, uint24);
}

/// @notice Returns the key for identifying a pool
struct PoolKey {
    Currency currency0;
    Currency currency1;
    uint24 fee;
    int24 tickSpacing;
    IHooks hooks;
}

using PoolIdLibrary for PoolKey global;

/// @dev Two `int128` values packed into a single `int256` where the upper 128 bits represent the amount0
/// and the lower 128 bits represent the amount1.
type BalanceDelta is int256;

using {add as +, sub as -, eq as ==, neq as !=} for BalanceDelta global;
using BalanceDeltaLibrary for BalanceDelta global;
using SafeCast for int256;

function toBalanceDelta(int128 _amount0, int128 _amount1) pure returns (BalanceDelta balanceDelta) {
    assembly ("memory-safe") {
        balanceDelta := or(shl(128, _amount0), and(sub(shl(128, 1), 1), _amount1))
    }
}

function add(BalanceDelta a, BalanceDelta b) pure returns (BalanceDelta) {
    int256 res0;
    int256 res1;
    assembly ("memory-safe") {
        let a0 := sar(128, a)
        let a1 := signextend(15, a)
        let b0 := sar(128, b)
        let b1 := signextend(15, b)
        res0 := add(a0, b0)
        res1 := add(a1, b1)
    }
    return toBalanceDelta(res0.toInt128(), res1.toInt128());
}

function sub(BalanceDelta a, BalanceDelta b) pure returns (BalanceDelta) {
    int256 res0;
    int256 res1;
    assembly ("memory-safe") {
        let a0 := sar(128, a)
        let a1 := signextend(15, a)
        let b0 := sar(128, b)
        let b1 := signextend(15, b)
        res0 := sub(a0, b0)
        res1 := sub(a1, b1)
    }
    return toBalanceDelta(res0.toInt128(), res1.toInt128());
}

function eq(BalanceDelta a, BalanceDelta b) pure returns (bool) {
    return BalanceDelta.unwrap(a) == BalanceDelta.unwrap(b);
}

function neq(BalanceDelta a, BalanceDelta b) pure returns (bool) {
    return BalanceDelta.unwrap(a) != BalanceDelta.unwrap(b);
}

/// @notice Library for getting the amount0 and amount1 deltas from the BalanceDelta type
library BalanceDeltaLibrary {
    BalanceDelta public constant ZERO_DELTA = BalanceDelta.wrap(0);

    function amount0(BalanceDelta balanceDelta) internal pure returns (int128 _amount0) {
        assembly ("memory-safe") {
            _amount0 := sar(128, balanceDelta)
        }
    }

    function amount1(BalanceDelta balanceDelta) internal pure returns (int128 _amount1) {
        assembly ("memory-safe") {
            _amount1 := signextend(15, balanceDelta)
        }
    }
}

// Return type of the beforeSwap hook.
// Upper 128 bits is the delta in specified tokens. Lower 128 bits is delta in unspecified tokens (to match the afterSwap hook)
type BeforeSwapDelta is int256;

function toBeforeSwapDelta(int128 deltaSpecified, int128 deltaUnspecified)
    pure
    returns (BeforeSwapDelta beforeSwapDelta)
{
    assembly ("memory-safe") {
        beforeSwapDelta := or(shl(128, deltaSpecified), and(sub(shl(128, 1), 1), deltaUnspecified))
    }
}

/// @notice Library for getting the specified and unspecified deltas from the BeforeSwapDelta type
library BeforeSwapDeltaLibrary {
    BeforeSwapDelta public constant ZERO_DELTA = BeforeSwapDelta.wrap(0);

    function getSpecifiedDelta(BeforeSwapDelta delta) internal pure returns (int128 deltaSpecified) {
        assembly ("memory-safe") {
            deltaSpecified := sar(128, delta)
        }
    }

    function getUnspecifiedDelta(BeforeSwapDelta delta) internal pure returns (int128 deltaUnspecified) {
        assembly ("memory-safe") {
            deltaUnspecified := signextend(15, delta)
        }
    }
}

/// @notice Interface for the callback executed when an address unlocks the pool manager
interface IUnlockCallback {
    function unlockCallback(bytes calldata data) external returns (bytes memory);
}

/// @notice Interface for functions to access any storage slot in a contract
interface IExtsload {
    function extsload(bytes32 slot) external view returns (bytes32 value);
    function extsload(bytes32 startSlot, uint256 nSlots) external view returns (bytes32[] memory values);
    function extsload(bytes32[] calldata slots) external view returns (bytes32[] memory values);
}

/// @notice Interface for functions to access any transient storage slot in a contract
interface IExttload {
    function exttload(bytes32 slot) external view returns (bytes32 value);
    function exttload(bytes32[] calldata slots) external view returns (bytes32[] memory values);
}

/// @notice Interface for claims over a contract balance, wrapped as a ERC6909
interface IERC6909Claims {
    event OperatorSet(address indexed owner, address indexed operator, bool approved);
    event Approval(address indexed owner, address indexed spender, uint256 indexed id, uint256 amount);
    event Transfer(address caller, address indexed from, address indexed to, uint256 indexed id, uint256 amount);
    function balanceOf(address owner, uint256 id) external view returns (uint256 amount);
    function allowance(address owner, address spender, uint256 id) external view returns (uint256 amount);
    function isOperator(address owner, address spender) external view returns (bool approved);
    function transfer(address receiver, uint256 id, uint256 amount) external returns (bool);
    function transferFrom(address sender, address receiver, uint256 id, uint256 amount) external returns (bool);
    function approve(address spender, uint256 id, uint256 amount) external returns (bool);
    function setOperator(address operator, bool approved) external returns (bool);
}

/// @notice Interface for all protocol-fee related functions in the pool manager
interface IProtocolFees {
    error ProtocolFeeTooLarge(uint24 fee);
    error InvalidCaller();
    error ProtocolFeeCurrencySynced();
    event ProtocolFeeControllerUpdated(address indexed protocolFeeController);
    event ProtocolFeeUpdated(PoolId indexed id, uint24 protocolFee);
    function protocolFeesAccrued(Currency currency) external view returns (uint256 amount);
    function setProtocolFee(PoolKey memory key, uint24 newProtocolFee) external;
    function setProtocolFeeController(address controller) external;
    function collectProtocolFees(address recipient, Currency currency, uint256 amount)
        external
        returns (uint256 amountCollected);
    function protocolFeeController() external view returns (address);
}

struct PoolManagerModifyLiquidityParams {
    int24 tickLower;
    int24 tickUpper;
    int256 liquidityDelta;
    bytes32 salt;
}

struct PoolManagerSwapParams {
    bool zeroForOne;
    int256 amountSpecified;
    uint160 sqrtPriceLimitX96;
}

/// @notice Interface for the PoolManager
interface IPoolManager is IProtocolFees, IERC6909Claims, IExtsload, IExttload {
    error CurrencyNotSettled();
    error PoolNotInitialized();
    error AlreadyUnlocked();
    error ManagerLocked();
    error TickSpacingTooLarge(int24 tickSpacing);
    error TickSpacingTooSmall(int24 tickSpacing);
    error CurrenciesOutOfOrderOrEqual(address currency0, address currency1);
    error UnauthorizedDynamicLPFeeUpdate();
    error SwapAmountCannotBeZero();
    error NonzeroNativeValue();
    error MustClearExactPositiveDelta();

    event Initialize(
        PoolId indexed id,
        Currency indexed currency0,
        Currency indexed currency1,
        uint24 fee,
        int24 tickSpacing,
        IHooks hooks,
        uint160 sqrtPriceX96,
        int24 tick
    );

    event ModifyLiquidity(
        PoolId indexed id, address indexed sender, int24 tickLower, int24 tickUpper, int256 liquidityDelta, bytes32 salt
    );

    event Swap(
        PoolId indexed id,
        address indexed sender,
        int128 amount0,
        int128 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick,
        uint24 fee
    );

    event Donate(PoolId indexed id, address indexed sender, uint256 amount0, uint256 amount1);

    function unlock(bytes calldata data) external returns (bytes memory);
    function initialize(PoolKey memory key, uint160 sqrtPriceX96) external returns (int24 tick);

    function modifyLiquidity(PoolKey memory key, PoolManagerModifyLiquidityParams memory params, bytes calldata hookData)
        external
        returns (BalanceDelta callerDelta, BalanceDelta feesAccrued);

    function swap(PoolKey memory key, PoolManagerSwapParams memory params, bytes calldata hookData)
        external
        returns (BalanceDelta swapDelta);

    function donate(PoolKey memory key, uint256 amount0, uint256 amount1, bytes calldata hookData)
        external
        returns (BalanceDelta);

    function sync(Currency currency) external;
    function take(Currency currency, address to, uint256 amount) external;
    function settle() external payable returns (uint256 paid);
    function settleFor(address recipient) external payable returns (uint256 paid);
    function clear(Currency currency, uint256 amount) external;
    function mint(address to, uint256 id, uint256 amount) external;
    function burn(address from, uint256 id, uint256 amount) external;
    function updateDynamicLPFee(PoolKey memory key, uint24 newDynamicLPFee) external;
}

/// @title IImmutableState
/// @notice Interface for the ImmutableState contract
interface IImmutableState {
    function poolManager() external view returns (IPoolManager);
}

/// @title Immutable State
/// @notice A collection of immutable state variables, commonly used across multiple contracts
contract ImmutableState is IImmutableState {
    IPoolManager public immutable poolManager;

    constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
    }
}

/// @title Safe Callback
/// @notice A contract that only allows the Uniswap v4 PoolManager to call the unlockCallback
abstract contract SafeCallback is ImmutableState, IUnlockCallback {
    /// @notice Thrown when calling unlockCallback where the caller is not PoolManager
    error NotPoolManager();

    constructor(IPoolManager _poolManager) ImmutableState(_poolManager) {}

    /// @notice Only allow calls from the PoolManager contract
    modifier onlyPoolManager() {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        _;
    }

    /// @inheritdoc IUnlockCallback
    /// @dev We force the onlyPoolManager modifier by exposing a virtual function after the onlyPoolManager check.
    function unlockCallback(bytes calldata data) external onlyPoolManager returns (bytes memory) {
        return _unlockCallback(data);
    }

    /// @dev to be implemented by the child contract, to safely guarantee the logic is only executed by the PoolManager
    function _unlockCallback(bytes calldata data) internal virtual returns (bytes memory);
}

/// @notice Library used to interact with PoolManager.sol to settle any open deltas.
library CurrencySettler {
    function settle(Currency currency, IPoolManager manager, address payer, uint256 amount, bool burn) internal {
        if (burn) {
            manager.burn(payer, currency.toId(), amount);
        } else if (currency.isAddressZero()) {
            manager.settle{value: amount}();
        } else {
            manager.sync(currency);
            if (payer != address(this)) {
                IERC20Minimal(Currency.unwrap(currency)).transferFrom(payer, address(manager), amount);
            } else {
                IERC20Minimal(Currency.unwrap(currency)).transfer(address(manager), amount);
            }
            manager.settle();
        }
    }

    function take(Currency currency, IPoolManager manager, address recipient, uint256 amount, bool claims) internal {
        claims ? manager.mint(recipient, currency.toId(), amount) : manager.take(currency, recipient, amount);
    }
}

/// @notice V4 decides whether to invoke specific hooks by inspecting the least significant bits
/// of the address that the hooks contract is deployed to.
library Hooks {
    uint160 internal constant ALL_HOOK_MASK = uint160((1 << 14) - 1);

    uint160 internal constant BEFORE_INITIALIZE_FLAG = 1 << 13;
    uint160 internal constant AFTER_INITIALIZE_FLAG = 1 << 12;

    uint160 internal constant BEFORE_ADD_LIQUIDITY_FLAG = 1 << 11;
    uint160 internal constant AFTER_ADD_LIQUIDITY_FLAG = 1 << 10;

    uint160 internal constant BEFORE_REMOVE_LIQUIDITY_FLAG = 1 << 9;
    uint160 internal constant AFTER_REMOVE_LIQUIDITY_FLAG = 1 << 8;

    uint160 internal constant BEFORE_SWAP_FLAG = 1 << 7;
    uint160 internal constant AFTER_SWAP_FLAG = 1 << 6;

    uint160 internal constant BEFORE_DONATE_FLAG = 1 << 5;
    uint160 internal constant AFTER_DONATE_FLAG = 1 << 4;

    uint160 internal constant BEFORE_SWAP_RETURNS_DELTA_FLAG = 1 << 3;
    uint160 internal constant AFTER_SWAP_RETURNS_DELTA_FLAG = 1 << 2;
    uint160 internal constant AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG = 1 << 1;
    uint160 internal constant AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG = 1 << 0;

    struct Permissions {
        bool beforeInitialize;
        bool afterInitialize;
        bool beforeAddLiquidity;
        bool afterAddLiquidity;
        bool beforeRemoveLiquidity;
        bool afterRemoveLiquidity;
        bool beforeSwap;
        bool afterSwap;
        bool beforeDonate;
        bool afterDonate;
        bool beforeSwapReturnDelta;
        bool afterSwapReturnDelta;
        bool afterAddLiquidityReturnDelta;
        bool afterRemoveLiquidityReturnDelta;
    }

    error HookAddressNotValid(address hooks);

    function validateHookPermissions(IHooks self, Permissions memory permissions) internal pure {
        if (
            permissions.beforeInitialize != self.hasPermission(BEFORE_INITIALIZE_FLAG)
                || permissions.afterInitialize != self.hasPermission(AFTER_INITIALIZE_FLAG)
                || permissions.beforeAddLiquidity != self.hasPermission(BEFORE_ADD_LIQUIDITY_FLAG)
                || permissions.afterAddLiquidity != self.hasPermission(AFTER_ADD_LIQUIDITY_FLAG)
                || permissions.beforeRemoveLiquidity != self.hasPermission(BEFORE_REMOVE_LIQUIDITY_FLAG)
                || permissions.afterRemoveLiquidity != self.hasPermission(AFTER_REMOVE_LIQUIDITY_FLAG)
                || permissions.beforeSwap != self.hasPermission(BEFORE_SWAP_FLAG)
                || permissions.afterSwap != self.hasPermission(AFTER_SWAP_FLAG)
                || permissions.beforeDonate != self.hasPermission(BEFORE_DONATE_FLAG)
                || permissions.afterDonate != self.hasPermission(AFTER_DONATE_FLAG)
                || permissions.beforeSwapReturnDelta != self.hasPermission(BEFORE_SWAP_RETURNS_DELTA_FLAG)
                || permissions.afterSwapReturnDelta != self.hasPermission(AFTER_SWAP_RETURNS_DELTA_FLAG)
                || permissions.afterAddLiquidityReturnDelta != self.hasPermission(AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG)
                || permissions.afterRemoveLiquidityReturnDelta
                    != self.hasPermission(AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG)
        ) {
            revert HookAddressNotValid(address(self));
        }
    }

    function hasPermission(IHooks self, uint160 flag) internal pure returns (bool) {
        return uint160(address(self)) & flag != 0;
    }
}

/// @title Base Hook
/// @notice abstract contract for hook implementations
abstract contract BaseHook is IHooks, SafeCallback {
    error NotSelf();
    error InvalidPool();
    error LockFailure();
    error HookNotImplemented();

    constructor(IPoolManager _manager) SafeCallback(_manager) {
        validateHookAddress(this);
    }

    modifier selfOnly() {
        if (msg.sender != address(this)) revert NotSelf();
        _;
    }

    modifier onlyValidPools(IHooks hooks) {
        if (hooks != this) revert InvalidPool();
        _;
    }

    function getHookPermissions() internal pure virtual returns (Hooks.Permissions memory);

    function validateHookAddress(BaseHook _this) internal pure virtual {
        Hooks.validateHookPermissions(_this, getHookPermissions());
    }

    function _unlockCallback(bytes calldata data) internal virtual override returns (bytes memory) {
        (bool success, bytes memory returnData) = address(this).call(data);
        if (success) return returnData;
        if (returnData.length == 0) revert LockFailure();
        assembly ("memory-safe") {
            revert(add(returnData, 32), mload(returnData))
        }
    }
}

// ------------------------------------------------------------------------------------------
// Inlined project-local dependencies that previously imported v4-periphery (State.sol, Calls.sol)
// ------------------------------------------------------------------------------------------

enum Action {
    AddLiquidity,
    RemoveLiquidity,
    Swap
}

struct AddLiquidtyParams {
    address token0;
    uint256 amount0;
    address token1;
    uint256 amount1;
    address sender;
}

struct RemoveLiquidtyParams {
    address token0;
    address token1;
    uint256 liquidityAmount;
    address sender;
}

struct SwapParams {
    // for flashswap
    bytes swapData;
    PoolManagerSwapParams params;
    PoolKey poolKey;
    address sender;
    uint256 amountOut;
    uint256 amountIn;
}

/// @notice amm id,
type AmmId is bytes32;

function toAmmId(address ra, address ct) pure returns (AmmId) {
    (address token0, address token1) = sort(ra, ct);
    return AmmId.wrap(keccak256(abi.encodePacked(token0, token1)));
}

function toAmmId(Currency _ra, Currency _ct) pure returns (AmmId) {
    (address ra, address ct) = (Currency.unwrap(_ra), Currency.unwrap(_ct));
    return toAmmId(ra, ct);
}

struct SortResult {
    address token0;
    address token1;
    uint256 amount0;
    uint256 amount1;
}

function sort(address a, address b) pure returns (address, address) {
    return a < b ? (a, b) : (b, a);
}

function reverseSortWithAmount(address a, address b, address token0, address token1, uint256 amount0, uint256 amount1)
    pure
    returns (address, address, uint256, uint256)
{
    if (a == token0 && b == token1) {
        return (token0, token1, amount0, amount1);
    } else if (a == token1 && b == token0) {
        return (token1, token0, amount1, amount0);
    } else {
        revert IErrors.InvalidToken();
    }
}

function sort(address a, address b, uint256 amountA, uint256 amountB)
    pure
    returns (address, address, uint256, uint256)
{
    return a < b ? (a, b, amountA, amountB) : (b, a, amountB, amountA);
}

function sortPacked(address a, address b, uint256 amountA, uint256 amountB) pure returns (SortResult memory) {
    (address token0, address token1, uint256 amount0, uint256 amount1) = sort(a, b, amountA, amountB);
    return SortResult(token0, token1, amount0, amount1);
}

function sortPacked(address a, address b) pure returns (SortResult memory) {
    (address token0, address token1) = sort(a, b);
    return SortResult(token0, token1, 0, 0);
}

/// @notice settle tokens from the pool manager, all numbers are fixed point 18 decimals on the hook
function settleNormalized(Currency currency, IPoolManager manager, address payer, uint256 amount, bool burn) {
    amount = TransferHelper.fixedToTokenNativeDecimals(amount, Currency.unwrap(currency));
    CurrencySettler.settle(currency, manager, payer, amount, burn);
}

function settle(Currency currency, IPoolManager manager, address payer, uint256 amount, bool burn) {
    CurrencySettler.settle(currency, manager, payer, amount, burn);
}

/// @notice take tokens from the pool manager, all numbers are fixed point 18 decimals on the hook
function takeNormalized(Currency currency, IPoolManager manager, address recipient, uint256 amount, bool claims) {
    amount = TransferHelper.fixedToTokenNativeDecimals(amount, Currency.unwrap(currency));
    CurrencySettler.take(currency, manager, recipient, amount, claims);
}

function take(Currency currency, IPoolManager manager, address recipient, uint256 amount, bool claims) {
    CurrencySettler.take(currency, manager, recipient, amount, claims);
}

function normalize(SortResult memory result) view returns (SortResult memory) {
    return SortResult(
        result.token0,
        result.token1,
        TransferHelper.tokenNativeDecimalsToFixed(result.amount0, result.token0),
        TransferHelper.tokenNativeDecimalsToFixed(result.amount1, result.token1)
    );
}

function normalize(address token, uint256 amount) view returns (uint256) {
    return TransferHelper.tokenNativeDecimalsToFixed(amount, token);
}

function normalize(Currency _token, uint256 amount) view returns (uint256) {
    address token = Currency.unwrap(_token);
    return TransferHelper.tokenNativeDecimalsToFixed(amount, token);
}

function toNative(Currency _token, uint256 amount) view returns (uint256) {
    address token = Currency.unwrap(_token);
    return TransferHelper.fixedToTokenNativeDecimals(amount, token);
}

function toNative(address token, uint256 amount) view returns (uint256) {
    return TransferHelper.fixedToTokenNativeDecimals(amount, token);
}

/// @notice Pool state
struct PoolState {
    /// @notice reserve of token0, in the native decimals
    uint256 reserve0;
    /// @notice reserve of token1, in the native decimals
    uint256 reserve1;
    address token0;
    address token1;
    ILiquidityToken liquidityToken;
    uint256 fee;
    uint256 startTimestamp;
    uint256 endTimestamp;
    uint256 treasurySplitPercentage;
}

library PoolStateLibrary {
    uint256 internal constant MAX_FEE = 100e18;
    uint256 internal constant MINIMUM_LIQUIDITY = 1e4;

    function ensureLiquidityEnoughAsNative(PoolState storage state, uint256 amountOut, address token) internal view {
        amountOut = TransferHelper.fixedToTokenNativeDecimals(amountOut, token);

        if (token == state.token0 && state.reserve0 < amountOut) {
            revert IErrors.NotEnoughLiquidity();
        } else if (token == state.token1 && state.reserve1 < amountOut) {
            revert IErrors.NotEnoughLiquidity();
        } else {
            return;
        }
    }

    function updateReserves(PoolState storage state, address token, uint256 amount, bool minus) internal {
        if (token == state.token0) {
            state.reserve0 = minus ? state.reserve0 - amount : state.reserve0 + amount;
        } else if (token == state.token1) {
            state.reserve1 = minus ? state.reserve1 - amount : state.reserve1 + amount;
        } else {
            revert IErrors.InvalidToken();
        }
    }

    function updateReservesAsNative(PoolState storage state, address token, uint256 amount, bool minus) internal {
        amount = TransferHelper.fixedToTokenNativeDecimals(amount, token);
        updateReserves(state, token, amount, minus);
    }

    function updateFee(PoolState storage state, uint256 fee) internal {
        if (fee >= MAX_FEE) {
            revert IErrors.InvalidFee();
        }
        state.fee = fee;
    }

    function getToken0(PoolState storage state) internal view returns (Currency) {
        return Currency.wrap(state.token0);
    }

    function getToken1(PoolState storage state) internal view returns (Currency) {
        return Currency.wrap(state.token1);
    }

    function initialize(PoolState storage state, address _token0, address _token1, address _liquidityToken) internal {
        state.token0 = _token0;
        state.token1 = _token1;
        state.liquidityToken = ILiquidityToken(_liquidityToken);
    }

    function isInitialized(PoolState storage state) internal view returns (bool) {
        return state.token0 != address(0);
    }

    function tryAddLiquidity(
        PoolState storage state,
        uint256 amount0,
        uint256 amount1,
        uint256 amount0min,
        uint256 amount1min
    )
        internal
        returns (uint256 reserve0, uint256 reserve1, uint256 mintedLp, uint256 amount0Used, uint256 amount1Used)
    {
        reserve0 = TransferHelper.tokenNativeDecimalsToFixed(state.reserve0, state.token0);
        reserve1 = TransferHelper.tokenNativeDecimalsToFixed(state.reserve1, state.token1);

        (amount0Used, amount1Used) =
            LiquidityMath.inferOptimalAmount(reserve0, reserve1, amount0, amount1, amount0min, amount1min);

        (reserve0, reserve1, mintedLp) =
            LiquidityMath.addLiquidity(reserve0, reserve1, state.liquidityToken.totalSupply(), amount0, amount1);

        reserve0 = TransferHelper.fixedToTokenNativeDecimals(reserve0, state.token0);
        reserve1 = TransferHelper.fixedToTokenNativeDecimals(reserve1, state.token1);

        if (state.reserve0 == 0 && state.reserve1 == 0) {
            mintedLp -= MINIMUM_LIQUIDITY;
        }
    }

    function addLiquidity(
        PoolState storage state,
        uint256 amount0,
        uint256 amount1,
        address sender,
        uint256 amount0min,
        uint256 amount1min
    )
        internal
        returns (uint256 reserve0, uint256 reserve1, uint256 mintedLp, uint256 amount0Used, uint256 amount1Used)
    {
        (reserve0, reserve1, mintedLp, amount0Used, amount1Used) =
            tryAddLiquidity(state, amount0, amount1, amount0min, amount1min);

        if (state.reserve0 == 0 && state.reserve1 == 0) {
            state.liquidityToken.mint(address(0xd3ad), MINIMUM_LIQUIDITY);
        }

        state.reserve0 = reserve0;
        state.reserve1 = reserve1;
        state.liquidityToken.mint(sender, mintedLp);
    }

    function tryRemoveLiquidity(PoolState storage state, uint256 liquidityAmount)
        internal
        returns (uint256 amount0, uint256 amount1, uint256 reserve0, uint256 reserve1)
    {
        (amount0, amount1, reserve0, reserve1) = LiquidityMath.removeLiquidity(
            state.reserve0, state.reserve1, state.liquidityToken.totalSupply(), liquidityAmount
        );
    }

    function removeLiquidity(PoolState storage state, uint256 liquidityAmount, address sender)
        internal
        returns (uint256 amount0, uint256 amount1, uint256 reserve0, uint256 reserve1)
    {
        (amount0, amount1, reserve0, reserve1) = tryRemoveLiquidity(state, liquidityAmount);

        state.reserve0 = reserve0;
        state.reserve1 = reserve1;
        state.liquidityToken.burnFrom(sender, liquidityAmount);
    }
}

interface IHookForwarder {
    function initializePool(address token0, address token1) external;
    function swap(SwapParams calldata params) external;

    function forwardToken(Currency _in, Currency out, uint256 amountIn, uint256 amountOut) external;
    function getCurrentSender() external view returns (address);
    function forwardTokenUncheked(Currency out, uint256 amountOut) external;

    function CorkCall(address sender, bytes calldata data, uint256 paymentAmount, address paymentToken, address pm)
        external;
}



contract CorkHook is BaseHook, Ownable, ICorkHook {
    using Clones for address;
    using PoolStateLibrary for PoolState;
    using PoolIdLibrary for PoolKey;
    using CurrencySettler for Currency;

    /// @notice Pool state
    mapping(AmmId => PoolState) internal pool;

    // we will deploy proxy to this address for each pool
    address internal immutable lpBase;
    IHookForwarder internal immutable forwarder;

    constructor(IPoolManager _poolManager, ILiquidityToken _lpBase, address owner, IHookForwarder _forwarder)
        BaseHook(_poolManager)
        Ownable(owner)
    {
        lpBase = address(_lpBase);
        forwarder = _forwarder;
    }

    modifier onlyInitialized(address a, address b) {
        AmmId ammId = toAmmId(a, b);
        PoolState storage self = pool[ammId];

        if (!self.isInitialized()) {
            revert IErrors.NotInitialized();
        }
        _;
    }

    function getHookPermissions() internal pure virtual override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true, // deploy lp tokens for this pool
            afterInitialize: false,
            beforeAddLiquidity: true, // override, only allow adding liquidity from the hook
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true, // override, only allow removing liquidity from the hook
            afterRemoveLiquidity: false,
            beforeSwap: true, // override, use our price curve
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true, // override, use our price curve
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function _ensureValidAmount(uint256 amount0, uint256 amount1) internal pure {
        if (amount0 == 0 && amount1 == 0) {
            revert IErrors.InvalidAmount();
        }

        if (amount0 != 0 && amount1 != 0) {
            revert IErrors.InvalidAmount();
        }
    }

    // we default to exact out swap, since it's easier to do flash swap this way
    // only support flash swap where the user pays with the other tokens
    // for paying with the same token, use "take" and "settle" directly in the pool manager
    function swap(address ra, address ct, uint256 amountRaOut, uint256 amountCtOut, bytes calldata data)
        external
        onlyInitialized(ra, ct)
        returns (uint256 amountIn)
    {
        SortResult memory sortResult = sortPacked(ra, ct, amountRaOut, amountCtOut);
        sortResult = normalize(sortResult);

        _ensureValidAmount(sortResult.amount0, sortResult.amount1);

        // if the amount1 is zero, then we swap token0 to token1, and vice versa
        bool zeroForOne = sortResult.amount0 <= 0;
        uint256 out = zeroForOne ? sortResult.amount1 : sortResult.amount0;

        {
            PoolState storage self = pool[toAmmId(sortResult.token0, sortResult.token1)];
            (amountIn,) = _getAmountIn(self, zeroForOne, out);
        }

        // turn the amount back to the original token decimals for user returns and accountings
        {
            amountIn = toNative(zeroForOne ? sortResult.token0 : sortResult.token1, amountIn);
            out = toNative(zeroForOne ? sortResult.token1 : sortResult.token0, out);
        }

        bytes memory swapData;
        PoolManagerSwapParams memory ammSwapParams;
        ammSwapParams = PoolManagerSwapParams(zeroForOne, int256(out), Constants.SQRT_PRICE_1_1);

        SwapParams memory params;
        PoolKey memory key = getPoolKey(sortResult.token0, sortResult.token1);

        params = SwapParams(data, ammSwapParams, key, msg.sender, out, amountIn);
        swapData = abi.encode(Action.Swap, params);

        poolManager.unlock(swapData);
    }

    function _initSwap(SwapParams memory params) internal {
        // trf user token to forwarder
        address token0 = Currency.unwrap(params.poolKey.currency0);
        address token1 = Currency.unwrap(params.poolKey.currency1);

        // regular swap, the user already has the token, so we directly transfer the token to the forwarder
        // if it has data, then its a flash swap, user usually doesn't have the token to pay, so we skip this step
        // and let the user pay on the callback directly to pool manager
        if (params.swapData.length == 0) {
            if (params.params.zeroForOne) {
                IERC20(token0).transferFrom(params.sender, address(forwarder), params.amountIn);
            } else {
                IERC20(token1).transferFrom(params.sender, address(forwarder), params.amountIn);
            }
        }

        forwarder.swap(params);
    }

    function _addLiquidity(PoolState storage self, uint256 amount0, uint256 amount1, address sender) internal {
        // we can safely insert 0 here since we have checked for validity at the start
        self.addLiquidity(amount0, amount1, sender, 0, 0);

        Currency token0 = self.getToken0();
        Currency token1 = self.getToken1();

        // settle claims token
        settleNormalized(token0, poolManager, sender, amount0, false);
        settleNormalized(token1, poolManager, sender, amount1, false);

        // take the tokens
        takeNormalized(token0, poolManager, address(this), amount0, true);
        takeNormalized(token1, poolManager, address(this), amount1, true);
    }

    function _removeLiquidity(PoolState storage self, uint256 liquidityAmount, address sender) internal {
        (uint256 amount0, uint256 amount1,,) = self.removeLiquidity(liquidityAmount, sender);

        Currency token0 = self.getToken0();
        Currency token1 = self.getToken1();

        // burn claims token
        settle(token0, poolManager, address(this), amount0, true);
        settle(token1, poolManager, address(this), amount1, true);

        // send back the tokens
        take(token0, poolManager, sender, amount0, false);
        take(token1, poolManager, sender, amount1, false);
    }

    function _unlockCallback(bytes calldata data) internal virtual override returns (bytes memory) {
        Action action = abi.decode(data, (Action));

        if (action == Action.AddLiquidity) {
            (, AddLiquidtyParams memory params) = abi.decode(data, (Action, AddLiquidtyParams));

            _addLiquidity(pool[toAmmId(params.token0, params.token1)], params.amount0, params.amount1, params.sender);
            return "";
        }

        if (action == Action.RemoveLiquidity) {
            (, RemoveLiquidtyParams memory params) = abi.decode(data, (Action, RemoveLiquidtyParams));

            _removeLiquidity(pool[toAmmId(params.token0, params.token1)], params.liquidityAmount, params.sender);
            return "";
        }

        if (action == Action.Swap) {
            (, SwapParams memory params) = abi.decode(data, (Action, SwapParams));

            _initSwap(params);
        }

        return "";
    }


    function beforeSwap(
        address sender,
        PoolKey calldata key,
        PoolManagerSwapParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4, BeforeSwapDelta delta, uint24) {
        PoolState storage self = pool[toAmmId(Currency.unwrap(key.currency0), Currency.unwrap(key.currency1))];
        // kinda packed, avoid stack too deep

        delta = toBeforeSwapDelta(-int128(params.amountSpecified), int128(_beforeSwap(self, params, hookData, sender)));

        // TODO: do we really need to specify the fee here?
        return (this.beforeSwap.selector, delta, 0);
    }

    // logically the flow is
    // 1. the hook settle the output token first, to create a debit. this enable flash swap
    // 2. token is transferred to the user using forwarder or router
    // 3 the user/router settle(pay) the input token
    // 4. the hook take the input token
    function _beforeSwap(
        PoolState storage self,
        PoolManagerSwapParams calldata params,
        bytes calldata hookData,
        address sender
    ) internal returns (int256 unspecificiedAmount) {
        bool exactIn = (params.amountSpecified < 0);
        uint256 amountIn;
        uint256 amountOut;
        // the fee here will always refer to the input token
        uint256 fee;

        (Currency input, Currency output) = _getInputOutput(self, params.zeroForOne);

        // we calculate how much they must pay
        if (exactIn) {
            amountIn = uint256(-params.amountSpecified);
            amountIn = normalize(input, amountIn);
            (amountOut, fee) = _getAmountOut(self, params.zeroForOne, amountIn);
        } else {
            amountOut = uint256(params.amountSpecified);
            amountOut = normalize(output, amountOut);
            (amountIn, fee) = _getAmountIn(self, params.zeroForOne, amountOut);
        }

        // if exact in, the hook must goes into "debt" equal to amount out
        // since at that point, the user specifies how much token they wanna swap. you can think of it like
        //
        // EXACT IN :
        // specifiedDelta : unspecificiedDelta =  how much input token user want to swap : how much the hook must give
        //
        // EXACT OUT :
        // unspecificiedDelta : specifiedDelta =  how much output token the user wants : how much input token user must pay
        unspecificiedAmount = exactIn ? -int256(toNative(output, amountOut)) : int256(toNative(input, amountIn));

        self.ensureLiquidityEnoughAsNative(amountOut, Currency.unwrap(output));

        // update reserve
        self.updateReservesAsNative(Currency.unwrap(output), amountOut, true);

        // we transfer their tokens, i.e we settle the output token first so that the user can take the input token
        settleNormalized(output, poolManager, address(this), amountOut, true);

        // there is data, means flash swap
        if (hookData.length > 0) {
            // will 0 if user pay with the same token
            unspecificiedAmount = _executeFlashSwap(self, hookData, input, output, amountIn, amountOut, sender, exactIn);
            // no data, means normal swap
        } else {
            // update reserve
            self.updateReservesAsNative(Currency.unwrap(input), amountIn, false);

            // settle swap, i.e we take the input token from the pool manager, the debt will be payed by the user
            takeNormalized(input, poolManager, address(this), amountIn, true);

            // forward token to user if caller is forwarder
            if (sender == address(forwarder)) {
                forwarder.forwardToken(input, output, amountIn, amountOut);
            }
        }

        // IMPORTANT: we won't compare K right now since the K amount will never be the same and have slight imprecision.
        // but this is fine since the hook knows how much tokens it should receive and give based on the balance delta which it calculate from the invariants

        // split fee from input token
        _splitFee(self, fee, input);

        {
            // the true caller, we try to infer this by checking if the sender is the forwarder, we can get the true caller from
            // the forwarder transient slot
            // if not then we fallback to whoever is the sender
            address actualSender = sender == address(forwarder) ? forwarder.getCurrentSender() : sender;

            (uint256 baseFeePercentage, uint256 actualFeePercentage) = _getFee(self);

            emit ICorkHook.Swapped(
                Currency.unwrap(input),
                Currency.unwrap(output),
                toNative(input, amountIn),
                toNative(output, amountOut),
                actualSender,
                baseFeePercentage,
                actualFeePercentage,
                fee
            );
        }
    }

    function _splitFee(PoolState storage self, uint256 fee, Currency _token) internal {
        address token = Currency.unwrap(_token);
        
        // split fee
        uint256 treasuryAttributed = SwapMath.calculatePercentage(fee, self.treasurySplitPercentage);
        self.updateReservesAsNative(token, treasuryAttributed, true);

        // take and settle fee token from manager
        settleNormalized(_token, poolManager, address(this), treasuryAttributed, true);
        takeNormalized(_token, poolManager, address(this), treasuryAttributed, false);
        
        // send fee to treasury
        ITreasury config = ITreasury(owner());
        address treasury = config.treasury();

        TransferHelper.transferNormalize(token, treasury, treasuryAttributed);
    }


    function _getFee(PoolState storage self)
        internal
        view
        returns (uint256 baseFeePercentage, uint256 actualFeePercentage)
    {
        baseFeePercentage = self.fee;

        (uint256 start, uint256 end) = _getIssuedAndMaturationTime(self);
        actualFeePercentage = SwapMath.getFeePercentage(baseFeePercentage, start, end, block.timestamp);
    }

    function _executeFlashSwap(
        PoolState storage self,
        bytes calldata hookData,
        Currency input,
        Currency output,
        uint256 amountIn,
        uint256 amountOut,
        address sender,
        bool exactIn
    ) internal returns (int256 unspecificiedAmount) {
        // exact in doesn't make sense on flash swap
        if (exactIn) {
            revert IErrors.NoExactIn();
        }

        {
            // send funds to the user
            try forwarder.forwardTokenUncheked(output, amountOut) {}
            // if failed then the user directly calls pool manager to flash swap, in that case we must send their token directly here
            catch {
                takeNormalized(input, poolManager, sender, amountIn, false);
            }

            // we expect user to use exact output swap when dealing with flash swap
            // so we use amountIn as the payment amount cause they they have to pay with the other token
            (uint256 paymentAmount, address paymentToken) = (amountIn, Currency.unwrap(input));

            // we convert the payment amount to the native decimals, fso that integrator contract can use it directly
            paymentAmount = toNative(paymentToken, paymentAmount);

            // call the callback
            CorkSwapCallback(sender).CorkCall(sender, hookData, paymentAmount, paymentToken, address(poolManager));
        }

        // process repayments

        // update reserve
        self.updateReservesAsNative(Currency.unwrap(input), amountIn, false);

        // settle swap, i.e we take the input token from the pool manager, the debt will be payed by the user, at this point, the user should've created a debit on the PM
        takeNormalized(input, poolManager, address(this), amountIn, true);

        // this is similar to normal swap, the unspecified amount is the other tokens
        // if exact in, the hook must goes into "debt" equal to amount out
        // since at that point, the user specifies how much token they wanna swap. you can think of it like
        //
        // EXACT IN :
        // specifiedDelta : unspecificiedDelta =  how much input token user want to swap : how much the hook must give
        //
        // EXACT OUT :
        // unspecificiedDelta : specifiedDelta =  how much output token the user wants : how much input token user must pay
        //
        // since in this case, exact in swap doesn't really make sense, we just return the amount in
        unspecificiedAmount = int256(toNative(input, amountIn));
    }

    function _getAmountIn(PoolState storage self, bool zeroForOne, uint256 amountOut)
        internal
        view
        returns (uint256 amountIn, uint256 fee)
    {
        if (amountOut <= 0) {
            revert IErrors.InvalidAmount();
        }

        (uint256 reserveIn, uint256 reserveOut) =
            zeroForOne ? (self.reserve0, self.reserve1) : (self.reserve1, self.reserve0);

        (Currency input, Currency output) = _getInputOutput(self, zeroForOne);

        reserveIn = normalize(input, reserveIn);
        reserveOut = normalize(output, reserveOut);

        if (reserveIn <= 0 || reserveOut <= 0) {
            revert IErrors.NotEnoughLiquidity();
        }

        uint256 oneMinusT = _1MinT(self);
        (amountIn, fee) = SwapMath.getAmountIn(amountOut, reserveIn, reserveOut, oneMinusT, self.fee);
    }


    function _getAmountOut(PoolState storage self, bool zeroForOne, uint256 amountIn)
        internal
        view
        returns (uint256 amountOut, uint256 fee)
    {
        if (amountIn <= 0) {
            revert IErrors.InvalidAmount();
        }

        (uint256 reserveIn, uint256 reserveOut) =
            zeroForOne ? (self.reserve0, self.reserve1) : (self.reserve1, self.reserve0);

        (Currency input, Currency output) = _getInputOutput(self, zeroForOne);

        reserveIn = normalize(input, reserveIn);
        reserveOut = normalize(output, reserveOut);

        if (reserveIn <= 0 || reserveOut <= 0) {
            revert IErrors.NotEnoughLiquidity();
        }

        uint256 oneMinusT = _1MinT(self);
        (amountOut, fee) = SwapMath.getAmountOut(amountIn, reserveIn, reserveOut, oneMinusT, self.fee);
    }


    function _getInputOutput(PoolState storage self, bool zeroForOne)
        internal
        view
        returns (Currency input, Currency output)
    {
        (address _input, address _output) = zeroForOne ? (self.token0, self.token1) : (self.token1, self.token0);
        return (Currency.wrap(_input), Currency.wrap(_output));
    }

    function _getIssuedAndMaturationTime(PoolState storage self) internal view returns (uint256 start, uint256 end) {
        return (self.startTimestamp, self.endTimestamp);
    }

    function _1MinT(PoolState storage self) internal view returns (uint256) {
        (uint256 start, uint256 end) = _getIssuedAndMaturationTime(self);
        return SwapMath.oneMinusT(start, end, block.timestamp);
    }

    function getPoolKey(address ra, address ct) internal view returns (PoolKey memory) {
        (address token0, address token1) = sort(ra, ct);
        return PoolKey(
            Currency.wrap(token0), Currency.wrap(token1), Constants.FEE, Constants.TICK_SPACING, IHooks(address(this))
        );
    }

}
