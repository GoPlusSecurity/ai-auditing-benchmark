pragma solidity ^0.8.0;

// lib/accounts-v2/src/libraries/AssetValuationLib.sol
/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

// Struct with risk and valuation related information for a certain asset.
struct AssetValueAndRiskFactors {
    // The value of the asset.
    uint256 assetValue;
    // The collateral factor of the asset, for a given creditor.
    uint256 collateralFactor;
    // The liquidation factor of the asset, for a given creditor.
    uint256 liquidationFactor;
}

/**
 * @title Asset Valuation Library
 * @author Pragma Labs
 * @notice The Asset Valuation Library is responsible for calculating the risk weighted values of combinations of assets.
 */
library AssetValuationLib {
    /*///////////////////////////////////////////////////////////////
                        CONSTANTS
    ///////////////////////////////////////////////////////////////*/

    uint256 internal constant ONE_4 = 10_000;

    /*///////////////////////////////////////////////////////////////
                        RISK FACTORS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates the collateral value given a combination of asset values and corresponding collateral factors.
     * @param valuesAndRiskFactors Array of asset values and corresponding collateral factors.
     * @return collateralValue The collateral value of the given assets.
     */
    function _calculateCollateralValue(AssetValueAndRiskFactors[] memory valuesAndRiskFactors)
        internal
        pure
        returns (uint256 collateralValue)
    {
        for (uint256 i; i < valuesAndRiskFactors.length; ++i) {
            collateralValue += valuesAndRiskFactors[i].assetValue * valuesAndRiskFactors[i].collateralFactor;
        }
        collateralValue = collateralValue / ONE_4;
    }

    /**
     * @notice Calculates the liquidation value given a combination of asset values and corresponding liquidation factors.
     * @param valuesAndRiskFactors List of asset values and corresponding liquidation factors.
     * @return liquidationValue The liquidation value of the given assets.
     */
    function _calculateLiquidationValue(AssetValueAndRiskFactors[] memory valuesAndRiskFactors)
        internal
        pure
        returns (uint256 liquidationValue)
    {
        for (uint256 i; i < valuesAndRiskFactors.length; ++i) {
            liquidationValue += valuesAndRiskFactors[i].assetValue * valuesAndRiskFactors[i].liquidationFactor;
        }
        liquidationValue = liquidationValue / ONE_4;
    }
}

// lib/accounts-v2/lib/v4-periphery/lib/v4-core/src/libraries/BitMath.sol

/// @title BitMath
/// @dev This library provides functionality for computing bit properties of an unsigned integer
/// @author Solady (https://github.com/Vectorized/solady/blob/8200a70e8dc2a77ecb074fc2e99a2a0d36547522/src/utils/LibBit.sol)
library BitMath {
    /// @notice Returns the index of the most significant bit of the number,
    ///     where the least significant bit is at index 0 and the most significant bit is at index 255
    /// @param x the value for which to compute the most significant bit, must be greater than 0
    /// @return r the index of the most significant bit
    function mostSignificantBit(uint256 x) internal pure returns (uint8 r) {
        require(x > 0);

        assembly ("memory-safe") {
            r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            // forgefmt: disable-next-item
            r := or(r, byte(and(0x1f, shr(shr(r, x), 0x8421084210842108cc6318c6db6d54be)),
                0x0706060506020500060203020504000106050205030304010505030400000000))
        }
    }

    /// @notice Returns the index of the least significant bit of the number,
    ///     where the least significant bit is at index 0 and the most significant bit is at index 255
    /// @param x the value for which to compute the least significant bit, must be greater than 0
    /// @return r the index of the least significant bit
    function leastSignificantBit(uint256 x) internal pure returns (uint8 r) {
        require(x > 0);

        assembly ("memory-safe") {
            // Isolate the least significant bit.
            x := and(x, sub(0, x))
            // For the upper 3 bits of the result, use a De Bruijn-like lookup.
            // Credit to adhusson: https://blog.adhusson.com/cheap-find-first-set-evm/
            // forgefmt: disable-next-item
            r := shl(5, shr(252, shl(shl(2, shr(250, mul(x,
                0xb6db6db6ddddddddd34d34d349249249210842108c6318c639ce739cffffffff))),
                0x8040405543005266443200005020610674053026020000107506200176117077)))
            // For the lower 5 bits of the result, use a De Bruijn lookup.
            // forgefmt: disable-next-item
            r := or(r, byte(and(div(0xd76453e0, shr(r, x)), 0x1f),
                0x001f0d1e100c1d070f090b19131c1706010e11080a1a141802121b1503160405))
        }
    }
}

// lib/accounts-v2/lib/v4-periphery/lib/v4-core/src/libraries/CustomRevert.sol

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

// lib/accounts-v2/lib/solmate/src/tokens/ERC20.sol

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
abstract contract ERC20 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    uint8 public immutable decimals;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }
}

// lib/accounts-v2/lib/v4-periphery/lib/v4-core/src/libraries/FixedPoint96.sol

/// @title FixedPoint96
/// @notice A library for handling binary fixed point numbers, see https://en.wikipedia.org/wiki/Q_(number_format)
/// @dev Used in SqrtPriceMath.sol
library FixedPoint96 {
    uint8 internal constant RESOLUTION = 96;
    uint256 internal constant Q96 = 0x1000000000000000000000000;
}

// lib/accounts-v2/src/asset-modules/UniswapV3/libraries/FixedPoint96.sol
// https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/FixedPoint96.sol
// SPDX-License-Identifier: GPL-2.0-or-later

/// @title FixedPoint96
/// @notice A library for handling binary fixed point numbers, see https://en.wikipedia.org/wiki/Q_(number_format)
/// @dev Used in SqrtPriceMath.sol
library FixedPoint96 {
    uint8 internal constant RESOLUTION = 96;
    uint256 internal constant Q96 = 0x1000000000000000000000000;
}

// lib/accounts-v2/lib/solmate/src/utils/FixedPointMathLib.sol

/// @notice Arithmetic library with operations for fixed-point numbers.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/FixedPointMathLib.sol)
/// @author Inspired by USM (https://github.com/usmfum/USM/blob/master/contracts/WadMath.sol)
library FixedPointMathLib {
    /*//////////////////////////////////////////////////////////////
                    SIMPLIFIED FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant MAX_UINT256 = 2**256 - 1;

    uint256 internal constant WAD = 1e18; // The scalar of ETH and most ERC20s.

    function mulWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, y, WAD); // Equivalent to (x * y) / WAD rounded down.
    }

    function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, y, WAD); // Equivalent to (x * y) / WAD rounded up.
    }

    function divWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, WAD, y); // Equivalent to (x * WAD) / y rounded down.
    }

    function divWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, WAD, y); // Equivalent to (x * WAD) / y rounded up.
    }

    /*//////////////////////////////////////////////////////////////
                    LOW LEVEL FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function mulDivDown(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Equivalent to require(denominator != 0 && (y == 0 || x <= type(uint256).max / y))
            if iszero(mul(denominator, iszero(mul(y, gt(x, div(MAX_UINT256, y)))))) {
                revert(0, 0)
            }

            // Divide x * y by the denominator.
            z := div(mul(x, y), denominator)
        }
    }

    function mulDivUp(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Equivalent to require(denominator != 0 && (y == 0 || x <= type(uint256).max / y))
            if iszero(mul(denominator, iszero(mul(y, gt(x, div(MAX_UINT256, y)))))) {
                revert(0, 0)
            }

            // If x * y modulo the denominator is strictly greater than 0,
            // 1 is added to round up the division of x * y by the denominator.
            z := add(gt(mod(mul(x, y), denominator), 0), div(mul(x, y), denominator))
        }
    }

    function rpow(
        uint256 x,
        uint256 n,
        uint256 scalar
    ) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            switch x
            case 0 {
                switch n
                case 0 {
                    // 0 ** 0 = 1
                    z := scalar
                }
                default {
                    // 0 ** n = 0
                    z := 0
                }
            }
            default {
                switch mod(n, 2)
                case 0 {
                    // If n is even, store scalar in z for now.
                    z := scalar
                }
                default {
                    // If n is odd, store x in z for now.
                    z := x
                }

                // Shifting right by 1 is like dividing by 2.
                let half := shr(1, scalar)

                for {
                    // Shift n right by 1 before looping to halve it.
                    n := shr(1, n)
                } n {
                    // Shift n right by 1 each iteration to halve it.
                    n := shr(1, n)
                } {
                    // Revert immediately if x ** 2 would overflow.
                    // Equivalent to iszero(eq(div(xx, x), x)) here.
                    if shr(128, x) {
                        revert(0, 0)
                    }

                    // Store x squared.
                    let xx := mul(x, x)

                    // Round to the nearest number.
                    let xxRound := add(xx, half)

                    // Revert if xx + half overflowed.
                    if lt(xxRound, xx) {
                        revert(0, 0)
                    }

                    // Set x to scaled xxRound.
                    x := div(xxRound, scalar)

                    // If n is even:
                    if mod(n, 2) {
                        // Compute z * x.
                        let zx := mul(z, x)

                        // If z * x overflowed:
                        if iszero(eq(div(zx, x), z)) {
                            // Revert if x is non-zero.
                            if iszero(iszero(x)) {
                                revert(0, 0)
                            }
                        }

                        // Round to the nearest number.
                        let zxRound := add(zx, half)

                        // Revert if zx + half overflowed.
                        if lt(zxRound, zx) {
                            revert(0, 0)
                        }

                        // Return properly scaled zxRound.
                        z := div(zxRound, scalar)
                    }
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        GENERAL NUMBER UTILITIES
    //////////////////////////////////////////////////////////////*/

    function sqrt(uint256 x) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            let y := x // We start y at x, which will help us make our initial estimate.

            z := 181 // The "correct" value is 1, but this saves a multiplication later.

            // This segment is to get a reasonable initial estimate for the Babylonian method. With a bad
            // start, the correct # of bits increases ~linearly each iteration instead of ~quadratically.

            // We check y >= 2^(k + 8) but shift right by k bits
            // each branch to ensure that if x >= 256, then y >= 256.
            if iszero(lt(y, 0x10000000000000000000000000000000000)) {
                y := shr(128, y)
                z := shl(64, z)
            }
            if iszero(lt(y, 0x1000000000000000000)) {
                y := shr(64, y)
                z := shl(32, z)
            }
            if iszero(lt(y, 0x10000000000)) {
                y := shr(32, y)
                z := shl(16, z)
            }
            if iszero(lt(y, 0x1000000)) {
                y := shr(16, y)
                z := shl(8, z)
            }

            // Goal was to get z*z*y within a small factor of x. More iterations could
            // get y in a tighter range. Currently, we will have y in [256, 256*2^16).
            // We ensured y >= 256 so that the relative difference between y and y+1 is small.
            // That's not possible if x < 256 but we can just verify those cases exhaustively.

            // Now, z*z*y <= x < z*z*(y+1), and y <= 2^(16+8), and either y >= 256, or x < 256.
            // Correctness can be checked exhaustively for x < 256, so we assume y >= 256.
            // Then z*sqrt(y) is within sqrt(257)/sqrt(256) of sqrt(x), or about 20bps.

            // For s in the range [1/256, 256], the estimate f(s) = (181/1024) * (s+1) is in the range
            // (1/2.84 * sqrt(s), 2.84 * sqrt(s)), with largest error when s = 1 and when s = 256 or 1/256.

            // Since y is in [256, 256*2^16), let a = y/65536, so that a is in [1/256, 256). Then we can estimate
            // sqrt(y) using sqrt(65536) * 181/1024 * (a + 1) = 181/4 * (y + 65536)/65536 = 181 * (y + 65536)/2^18.

            // There is no overflow risk here since y < 2^136 after the first branch above.
            z := shr(18, mul(z, add(y, 65536))) // A mul() is saved from starting z at 181.

            // Given the worst case multiplicative error of 2.84 above, 7 iterations should be enough.
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            // If x+1 is a perfect square, the Babylonian method cycles between
            // floor(sqrt(x)) and ceil(sqrt(x)). This statement ensures we return floor.
            // See: https://en.wikipedia.org/wiki/Integer_square_root#Using_only_integer_division
            // Since the ceil is rare, we save gas on the assignment and repeat division in the rare case.
            // If you don't care whether the floor or ceil square root is returned, you can remove this statement.
            z := sub(z, lt(div(x, z), z))
        }
    }

    function unsafeMod(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Mod x by y. Note this will return
            // 0 instead of reverting if y is zero.
            z := mod(x, y)
        }
    }

    function unsafeDiv(uint256 x, uint256 y) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            // Divide x by y. Note this will return
            // 0 instead of reverting if y is zero.
            r := div(x, y)
        }
    }

    function unsafeDivUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Add 1 to x * y if x % y > 0. Note this will
            // return 0 instead of reverting if y is zero.
            z := add(gt(mod(x, y), 0), div(x, y))
        }
    }
}

// lib/accounts-v2/lib/v4-periphery/lib/v4-core/src/libraries/FullMath.sol

/// @title Contains 512-bit math functions
/// @notice Facilitates multiplication and division that can have overflow of an intermediate value without any loss of precision
/// @dev Handles "phantom overflow" i.e., allows multiplication and division where an intermediate value overflows 256 bits
library FullMath {
    /// @notice Calculates floor(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    /// @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
    function mulDiv(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = a * b
            // Compute the product mod 2**256 and mod 2**256 - 1
            // then use the Chinese Remainder Theorem to reconstruct
            // the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2**256 + prod0
            uint256 prod0 = a * b; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly ("memory-safe") {
                let mm := mulmod(a, b, not(0))
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Make sure the result is less than 2**256.
            // Also prevents denominator == 0
            require(denominator > prod1);

            // Handle non-overflow cases, 256 by 256 division
            if (prod1 == 0) {
                assembly ("memory-safe") {
                    result := div(prod0, denominator)
                }
                return result;
            }

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0]
            // Compute remainder using mulmod
            uint256 remainder;
            assembly ("memory-safe") {
                remainder := mulmod(a, b, denominator)
            }
            // Subtract 256 bit number from 512 bit number
            assembly ("memory-safe") {
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator
            // Compute largest power of two divisor of denominator.
            // Always >= 1.
            uint256 twos = (0 - denominator) & denominator;
            // Divide denominator by power of two
            assembly ("memory-safe") {
                denominator := div(denominator, twos)
            }

            // Divide [prod1 prod0] by the factors of two
            assembly ("memory-safe") {
                prod0 := div(prod0, twos)
            }
            // Shift in bits from prod1 into prod0. For this we need
            // to flip `twos` such that it is 2**256 / twos.
            // If twos is zero, then it becomes one
            assembly ("memory-safe") {
                twos := add(div(sub(0, twos), twos), 1)
            }
            prod0 |= prod1 * twos;

            // Invert denominator mod 2**256
            // Now that denominator is an odd number, it has an inverse
            // modulo 2**256 such that denominator * inv = 1 mod 2**256.
            // Compute the inverse by starting with a seed that is correct
            // correct for four bits. That is, denominator * inv = 1 mod 2**4
            uint256 inv = (3 * denominator) ^ 2;
            // Now use Newton-Raphson iteration to improve the precision.
            // Thanks to Hensel's lifting lemma, this also works in modular
            // arithmetic, doubling the correct bits in each step.
            inv *= 2 - denominator * inv; // inverse mod 2**8
            inv *= 2 - denominator * inv; // inverse mod 2**16
            inv *= 2 - denominator * inv; // inverse mod 2**32
            inv *= 2 - denominator * inv; // inverse mod 2**64
            inv *= 2 - denominator * inv; // inverse mod 2**128
            inv *= 2 - denominator * inv; // inverse mod 2**256

            // Because the division is now exact we can divide by multiplying
            // with the modular inverse of denominator. This will give us the
            // correct result modulo 2**256. Since the preconditions guarantee
            // that the outcome is less than 2**256, this is the final result.
            // We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inv;
            return result;
        }
    }

    /// @notice Calculates ceil(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    function mulDivRoundingUp(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            result = mulDiv(a, b, denominator);
            if (mulmod(a, b, denominator) != 0) {
                require(++result > 0);
            }
        }
    }
}

// lib/accounts-v2/src/asset-modules/UniswapV3/libraries/FullMath.sol
// https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/FullMath.sol
// SPDX-License-Identifier: GPL-2.0-or-later

/// @title Contains 512-bit math functions
/// @notice Facilitates multiplication and division that can have overflow of an intermediate value without any loss of precision
/// @dev Handles "phantom overflow" i.e., allows multiplication and division where an intermediate value overflows 256 bits
library FullMath {
    /// @notice Calculates floor(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    /// @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
    function mulDiv(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = a * b
            // Compute the product mod 2**256 and mod 2**256 - 1
            // then use the Chinese Remainder Theorem to reconstruct
            // the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2**256 + prod0
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(a, b, not(0))
                prod0 := mul(a, b)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division
            if (prod1 == 0) {
                require(denominator > 0);
                assembly {
                    result := div(prod0, denominator)
                }
                return result;
            }

            // Make sure the result is less than 2**256.
            // Also prevents denominator == 0
            require(denominator > prod1);

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0]
            // Compute remainder using mulmod
            uint256 remainder;
            assembly {
                remainder := mulmod(a, b, denominator)
            }
            // Subtract 256 bit number from 512 bit number
            assembly {
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator
            // Compute largest power of two divisor of denominator.
            // Always >= 1.
            uint256 twos = (type(uint256).max - denominator + 1) & denominator;
            // Divide denominator by power of two
            assembly {
                denominator := div(denominator, twos)
            }

            // Divide [prod1 prod0] by the factors of two
            assembly {
                prod0 := div(prod0, twos)
            }
            // Shift in bits from prod1 into prod0. For this we need
            // to flip `twos` such that it is 2**256 / twos.
            // If twos is zero, then it becomes one
            assembly {
                twos := add(div(sub(0, twos), twos), 1)
            }
            prod0 |= prod1 * twos;

            // Invert denominator mod 2**256
            // Now that denominator is an odd number, it has an inverse
            // modulo 2**256 such that denominator * inv = 1 mod 2**256.
            // Compute the inverse by starting with a seed that is correct
            // correct for four bits. That is, denominator * inv = 1 mod 2**4
            uint256 inv = (3 * denominator) ^ 2;
            // Now use Newton-Raphson iteration to improve the precision.
            // Thanks to Hensel's lifting lemma, this also works in modular
            // arithmetic, doubling the correct bits in each step.
            inv *= 2 - denominator * inv; // inverse mod 2**8
            inv *= 2 - denominator * inv; // inverse mod 2**16
            inv *= 2 - denominator * inv; // inverse mod 2**32
            inv *= 2 - denominator * inv; // inverse mod 2**64
            inv *= 2 - denominator * inv; // inverse mod 2**128
            inv *= 2 - denominator * inv; // inverse mod 2**256

            // Because the division is now exact we can divide by multiplying
            // with the modular inverse of denominator. This will give us the
            // correct result modulo 2**256. Since the precoditions guarantee
            // that the outcome is less than 2**256, this is the final result.
            // We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inv;
        }
        return result;
    }

    /// @notice Calculates ceil(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    function mulDivRoundingUp(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        result = mulDiv(a, b, denominator);
        if (mulmod(a, b, denominator) > 0) {
            require(result < type(uint256).max);
            result++;
        }
    }
}

// src/rebalancers/interfaces/IAccount.sol
/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */

interface IAccount {
    function flashAction(address actionTarget, bytes calldata actionData) external;
    function owner() external returns (address owner_);
}

// lib/accounts-v2/src/interfaces/IActionBase.sol
/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

// Struct with information to pass to and from the actionTarget.
struct ActionData {
    // Array of the contract addresses of the assets.
    address[] assets;
    // Array of the IDs of the assets.
    uint256[] assetIds;
    // Array with the amounts of the assets.
    uint256[] assetAmounts;
    // Array with the types of the assets.
    uint256[] assetTypes;
}

interface IActionBase {
    /**
     * @notice Calls an external target contract with arbitrary calldata.
     * @param actionTargetData A bytes object containing the encoded input for the actionTarget.
     * @return resultData An actionAssetData struct with the final balances of this actionTarget contract.
     */
    function executeAction(bytes calldata actionTargetData) external returns (ActionData memory);
}

// src/interfaces/ICLPool.sol

interface ICLPool {
    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);
}

// src/rebalancers/interfaces/ICLPool.sol

interface ICLPool {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            bool unlocked
        );

    function fee() external view returns (uint24);
}

// src/rebalancers/interfaces/ICLPositionManager.sol

/// @title Non-fungible token for positions
/// @notice Wraps Slipstream positions in a non-fungible token interface which allows for them to be transferred
/// and authorized.

interface ICLPositionManager {
    struct MintParams {
        address token0;
        address token1;
        int24 tickSpacing;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
        uint160 sqrtPriceX96;
    }

    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            int24 tickSpacing,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    function approve(address spender, uint256 tokenId) external;

    function mint(MintParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
}

// src/rebalancers/interfaces/IFactory.sol
/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */

interface IFactory {
    /**
     * @notice Checks if a contract is an Account.
     * @param account The contract address of the Account.
     * @return bool indicating if the address is an Account or not.
     */
    function isAccount(address account) external view returns (bool);
}

// lib/accounts-v2/src/interfaces/IPermit2.sol
/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */

interface IPermit2 {
    /**
     * @notice The token and amount details for a transfer signed in the permit transfer signature
     */
    struct TokenPermissions {
        // ERC20 token address
        address token;
        // the maximum amount that can be spent
        uint256 amount;
    }

    /**
     * @notice Used to reconstruct the signed permit message for multiple token transfers
     * @dev Do not need to pass in spender address as it is required that it is msg.sender
     * @dev Note that a user still signs over a spender address
     */
    struct PermitBatchTransferFrom {
        // the tokens and corresponding amounts permitted for a transfer
        TokenPermissions[] permitted;
        // a unique value for every token owner's signature to prevent signature replays
        uint256 nonce;
        // deadline on the permit signature
        uint256 deadline;
    }

    /**
     * @notice Specifies the recipient address and amount for batched transfers.
     * @dev Recipients and amounts correspond to the index of the signed token permissions array.
     * @dev Reverts if the requested amount is greater than the permitted signed amount.
     */
    struct SignatureTransferDetails {
        // recipient address
        address to;
        // spender requested amount
        uint256 requestedAmount;
    }

    /**
     * @notice Transfers multiple tokens using a signed permit message
     * @param permit The permit data signed over by the owner
     * @param owner The owner of the tokens to transfer
     * @param transferDetails Specifies the recipient and requested amount for the token transfer
     * @param signature The signature to verify
     */
    function permitTransferFrom(
        PermitBatchTransferFrom memory permit,
        SignatureTransferDetails[] calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;
}

// src/rebalancers/interfaces/IPool.sol

interface IPool {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);

    function liquidity() external view returns (uint128 liquidity);
}

// src/rebalancers/interfaces/IPositionManager.sol

struct CollectParams {
    uint256 tokenId;
    address recipient;
    uint128 amount0Max;
    uint128 amount1Max;
}

struct DecreaseLiquidityParams {
    uint256 tokenId;
    uint128 liquidity;
    uint256 amount0Min;
    uint256 amount1Min;
    uint256 deadline;
}

interface IPositionManager {
    function approve(address spender, uint256 tokenId) external;

    function collect(CollectParams calldata params) external payable returns (uint256 amount0, uint256 amount1);

    function burn(uint256 tokenId) external payable;

    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1);
}

// src/rebalancers/interfaces/IStakedSlipstreamAM.sol
/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */

interface IStakedSlipstreamAM {
    function burn(uint256 id) external returns (uint256 rewards);

    function mint(uint256 id) external returns (uint256 id_);

    function REWARD_TOKEN() external view returns (address rewardToken);
}

// src/rebalancers/interfaces/IStrategyHook.sol
/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */

interface IStrategyHook {
    function beforeRebalance(
        address account,
        address positionManager,
        uint256 oldId,
        int24 newTickLower,
        int24 newTickUpper
    ) external view;

    function afterRebalance(address account, address positionManager, uint256 oldId, uint256 newId) external;
}

// src/rebalancers/interfaces/IUniswapV3Pool.sol

interface IUniswapV3Pool {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );

    function tickSpacing() external view returns (int24 tickSpacing);
}

// src/rebalancers/interfaces/IUniswapV3PositionManager.sol

/// @title Non-fungible token for positions
/// @notice Wraps Uniswap V3 positions in a non-fungible token interface which allows for them to be transferred
/// and authorized.

interface IUniswapV3PositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    function mint(MintParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
}

// lib/accounts-v2/src/asset-modules/UniswapV3/libraries/PoolAddress.sol
// https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/PoolAddress.sol
// SPDX-License-Identifier: GPL-2.0-or-later

/// @title Provides functions for deriving a pool address from the factory, tokens, and the fee
library PoolAddress {
    bytes32 internal constant POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    /// @notice The identifying key of the pool
    struct PoolKey {
        address token0;
        address token1;
        uint24 fee;
    }

    /// @notice Deterministically computes the pool address given the factory and PoolKey
    /// @param factory The Uniswap V3 factory contract address
    /// @param token0 Contract address of token0.
    /// @param token1 Contract address of token1.
    /// @param fee The fee of the pool.
    /// @return pool The contract address of the V3 pool
    function computeAddress(address factory, address token0, address token1, uint24 fee)
        internal
        pure
        returns (address pool)
    {
        require(token0 < token1);
        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff", factory, keccak256(abi.encode(token0, token1, fee)), POOL_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }
}

// src/rebalancers/libraries/slipstream/PoolAddress.sol
// https://github.com/velodrome-finance/slipstream/blob/main/contracts/periphery/libraries/PoolAddress.sol
// SPDX-License-Identifier: GPL-2.0-or-later

/// @title Provides functions for deriving a pool address from the factory, tokens, and the tickSpacing
library PoolAddress {
    /// @notice Deterministically computes the pool address given the factory and PoolKey
    /// @param poolImplementation The contract address of the Slipstream Pool implementation.
    /// @param factory The contract address of the Slipstream factory.
    /// @param token0 Contract address of token0.
    /// @param token1 Contract address of token1.
    /// @param tickSpacing The tick spacing of the pool
    /// @return pool The contract address of the pool
    function computeAddress(
        address poolImplementation,
        address factory,
        address token0,
        address token1,
        int24 tickSpacing
    ) internal pure returns (address pool) {
        require(token0 < token1);
        pool = predictDeterministicAddress({
            master: poolImplementation,
            salt: keccak256(abi.encode(token0, token1, tickSpacing)),
            deployer: factory
        });
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(address master, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, master))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf3ff00000000000000000000000000000000)
            mstore(add(ptr, 0x38), shl(0x60, deployer))
            mstore(add(ptr, 0x4c), salt)
            mstore(add(ptr, 0x6c), keccak256(ptr, 0x37))
            predicted := keccak256(add(ptr, 0x37), 0x55)
        }
    }
}

// src/rebalancers/libraries/StakedSlipstreamLogic.sol
/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

library StakedSlipstreamLogic {
    // The contract address of the Reward Token (Aero).
    address internal constant REWARD_TOKEN = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;

    // The Staked Slipstream Asset Module contract.
    address internal constant STAKED_SLIPSTREAM_AM = 0x1Dc7A0f5336F52724B650E39174cfcbbEdD67bF1;

    // The Wrapped Staked Slipstream Asset Module contract.
    address internal constant STAKED_SLIPSTREAM_WRAPPER = 0xD74339e0F10fcE96894916B93E5Cc7dE89C98272;
}

// lib/accounts-v2/lib/v4-periphery/lib/v4-core/src/libraries/UnsafeMath.sol

/// @title Math functions that do not check inputs or outputs
/// @notice Contains methods that perform common math functions but do not do any overflow or underflow checks
library UnsafeMath {
    /// @notice Returns ceil(x / y)
    /// @dev division by 0 will return 0, and should be checked externally
    /// @param x The dividend
    /// @param y The divisor
    /// @return z The quotient, ceil(x / y)
    function divRoundingUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly ("memory-safe") {
            z := add(div(x, y), gt(mod(x, y), 0))
        }
    }

    /// @notice Calculates floor(a×b÷denominator)
    /// @dev division by 0 will return 0, and should be checked externally
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result, floor(a×b÷denominator)
    function simpleMulDiv(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        assembly ("memory-safe") {
            result := div(mul(a, b), denominator)
        }
    }
}

// src/rebalancers/interfaces/IRegistry.sol
/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */

interface IRegistry {
    function getValuesInUsd(
        address creditor,
        address[] calldata assets,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) external view returns (AssetValueAndRiskFactors[] memory valuesAndRiskFactors);
}

// src/rebalancers/libraries/SafeApprove.sol

library SafeApprove {
    /**
     * @notice Approves an amount of token for a spender.
     * @param token The contract address of the token being approved.
     * @param to The spender.
     * @param amount the amount of token being approved.
     * @dev Copied from Solady safeApproveWithRetry (MIT): https://github.com/Vectorized/solady/blob/main/src/utils/SafeTransferLib.sol
     * @dev Sets `amount` of ERC20 `token` for `to` to manage on behalf of the current contract.
     * If the initial attempt to approve fails, attempts to reset the approved amount to zero,
     * then retries the approval again (some tokens, e.g. USDT, requires this).
     * Reverts upon failure.
     */
    function safeApproveWithRetry(ERC20 token, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x14, to) // Store the `to` argument.
            mstore(0x34, amount) // Store the `amount` argument.
            mstore(0x00, 0x095ea7b3000000000000000000000000) // `approve(address,uint256)`.
            // Perform the approval, retrying upon failure.
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    or(eq(mload(0x00), 1), iszero(returndatasize())), // Returned 1 or nothing.
                    call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
                )
            ) {
                mstore(0x34, 0) // Store 0 for the `amount`.
                mstore(0x00, 0x095ea7b3000000000000000000000000) // `approve(address,uint256)`.
                pop(call(gas(), token, 0, 0x10, 0x44, codesize(), 0x00)) // Reset the approval.
                mstore(0x34, amount) // Store back the original `amount`.
                // Retry the approval, reverting upon failure.
                if iszero(
                    and(
                        or(eq(mload(0x00), 1), iszero(returndatasize())), // Returned 1 or nothing.
                        call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
                    )
                ) {
                    mstore(0x00, 0x3e3f8f73) // `ApproveFailed()`.
                    revert(0x1c, 0x04)
                }
            }
            mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
        }
    }
}

// lib/accounts-v2/lib/v4-periphery/lib/v4-core/src/libraries/SafeCast.sol

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

// lib/accounts-v2/lib/solmate/src/utils/SafeTransferLib.sol

/// @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// @dev Use with caution! Some functions in this library knowingly create dirty bits at the destination of the free memory pointer.
/// @dev Note that none of the functions in this library check that a token has code at all! That responsibility is delegated to the caller.
library SafeTransferLib {
    /*//////////////////////////////////////////////////////////////
                             ETH OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferETH(address to, uint256 amount) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Transfer the ETH and store if it succeeded or not.
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        require(success, "ETH_TRANSFER_FAILED");
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferFrom(
        ERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), and(from, 0xffffffffffffffffffffffffffffffffffffffff)) // Append and mask the "from" argument.
            mstore(add(freeMemoryPointer, 36), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // Append and mask the "to" argument.
            mstore(add(freeMemoryPointer, 68), amount) // Append the "amount" argument. Masking not required as it's a full 32 byte type.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 100 because the length of our calldata totals up like so: 4 + 32 * 3.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 100, 0, 32)
            )
        }

        require(success, "TRANSFER_FROM_FAILED");
    }

    function safeTransfer(
        ERC20 token,
        address to,
        uint256 amount
    ) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // Append and mask the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument. Masking not required as it's a full 32 byte type.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
            )
        }

        require(success, "TRANSFER_FAILED");
    }

    function safeApprove(
        ERC20 token,
        address to,
        uint256 amount
    ) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // Append and mask the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument. Masking not required as it's a full 32 byte type.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
            )
        }

        require(success, "APPROVE_FAILED");
    }
}

// src/rebalancers/libraries/FeeLogic.sol
/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

library FeeLogic {
    using SafeTransferLib for ERC20;

    /**
     * @notice Transfers the initiator fee to the initiator.
     * @param initiator The address of the initiator.
     * @param zeroToOne Bool indicating if token0 has to be swapped to token1 or opposite.
     * @param amountInitiatorFee The amount of initiator fee.
     * @param token0 The contract address of token0.
     * @param token1 The contract address of token1.
     * @param balance0 The balance of token0 before transferring the initiator fee.
     * @param balance1 The balance of token1 before transferring the initiator fee.
     * @return balance0 The balance of token0 after transferring the initiator fee.
     * @return balance1 The balance of token1 after transferring the initiator fee.
     */
    function _transfer(
        address initiator,
        bool zeroToOne,
        uint256 amountInitiatorFee,
        address token0,
        address token1,
        uint256 balance0,
        uint256 balance1
    ) internal returns (uint256, uint256) {
        unchecked {
            if (zeroToOne) {
                (balance0, amountInitiatorFee) =
                    balance0 > amountInitiatorFee ? (balance0 - amountInitiatorFee, amountInitiatorFee) : (0, balance0);
                if (amountInitiatorFee > 0) ERC20(token0).safeTransfer(initiator, amountInitiatorFee);
            } else {
                (balance1, amountInitiatorFee) =
                    balance1 > amountInitiatorFee ? (balance1 - amountInitiatorFee, amountInitiatorFee) : (0, balance1);
                if (amountInitiatorFee > 0) ERC20(token1).safeTransfer(initiator, amountInitiatorFee);
            }
            return (balance0, balance1);
        }
    }
}

// src/rebalancers/libraries/uniswap-v3/LiquidityAmounts.sol
// https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/LiquidityAmounts.sol
// SPDX-License-Identifier: GPL-2.0-or-later

/// @title Liquidity amount functions
/// @notice Provides functions for computing liquidity amounts from token amounts and prices
library LiquidityAmounts {
    /// @notice Downcasts uint256 to uint128
    /// @param x The uint258 to be downcasted
    /// @return y The passed value, downcasted to uint128
    function toUint128(uint256 x) internal pure returns (uint128 y) {
        require((y = uint128(x)) == x);
    }

    /// @notice Computes the amount of liquidity received for a given amount of token0 and price range
    /// @dev Calculates amount0 * (sqrt(upper) * sqrt(lower)) / (sqrt(upper) - sqrt(lower))
    /// @param sqrtRatioAX96 A sqrt price representing the first tick boundary
    /// @param sqrtRatioBX96 A sqrt price representing the second tick boundary
    /// @param amount0 The amount0 being sent in
    /// @return liquidity The amount of returned liquidity
    function getLiquidityForAmount0(uint160 sqrtRatioAX96, uint160 sqrtRatioBX96, uint256 amount0)
        internal
        pure
        returns (uint256 liquidity)
    {
        unchecked {
            if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
            uint256 intermediate = FullMath.mulDiv(sqrtRatioAX96, sqrtRatioBX96, FixedPoint96.Q96);
            return FullMath.mulDiv(amount0, intermediate, sqrtRatioBX96 - sqrtRatioAX96);
        }
    }

    /// @notice Computes the amount of liquidity received for a given amount of token1 and price range
    /// @dev Calculates amount1 / (sqrt(upper) - sqrt(lower)).
    /// @param sqrtRatioAX96 A sqrt price representing the first tick boundary
    /// @param sqrtRatioBX96 A sqrt price representing the second tick boundary
    /// @param amount1 The amount1 being sent in
    /// @return liquidity The amount of returned liquidity
    function getLiquidityForAmount1(uint160 sqrtRatioAX96, uint160 sqrtRatioBX96, uint256 amount1)
        internal
        pure
        returns (uint256 liquidity)
    {
        unchecked {
            if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
            return FullMath.mulDiv(amount1, FixedPoint96.Q96, sqrtRatioBX96 - sqrtRatioAX96);
        }
    }

    /// @notice Computes the maximum amount of liquidity received for a given amount of token0, token1, the current
    /// pool prices and the prices at the tick boundaries
    /// @param sqrtRatioX96 A sqrt price representing the current pool prices
    /// @param sqrtRatioAX96 A sqrt price representing the first tick boundary
    /// @param sqrtRatioBX96 A sqrt price representing the second tick boundary
    /// @param amount0 The amount of token0 being sent in
    /// @param amount1 The amount of token1 being sent in
    /// @return liquidity The maximum amount of liquidity received
    function getLiquidityForAmounts(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount0,
        uint256 amount1
    ) internal pure returns (uint128 liquidity) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        if (sqrtRatioX96 <= sqrtRatioAX96) {
            liquidity = toUint128(getLiquidityForAmount0(sqrtRatioAX96, sqrtRatioBX96, amount0));
        } else if (sqrtRatioX96 < sqrtRatioBX96) {
            uint256 liquidity0 = getLiquidityForAmount0(sqrtRatioX96, sqrtRatioBX96, amount0);
            uint256 liquidity1 = getLiquidityForAmount1(sqrtRatioAX96, sqrtRatioX96, amount1);

            liquidity = toUint128(liquidity0 < liquidity1 ? liquidity0 : liquidity1);
        } else {
            liquidity = toUint128(getLiquidityForAmount1(sqrtRatioAX96, sqrtRatioBX96, amount1));
        }
    }

    /// @notice Computes the amount of token0 for a given amount of liquidity and a price range
    /// @param sqrtRatioAX96 A sqrt price representing the first tick boundary
    /// @param sqrtRatioBX96 A sqrt price representing the second tick boundary
    /// @param liquidity The liquidity being valued
    /// @return amount0 The amount of token0
    function getAmount0ForLiquidity(uint160 sqrtRatioAX96, uint160 sqrtRatioBX96, uint128 liquidity)
        internal
        pure
        returns (uint256 amount0)
    {
        unchecked {
            if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

            return FullMath.mulDiv(
                uint256(liquidity) << FixedPoint96.RESOLUTION, sqrtRatioBX96 - sqrtRatioAX96, sqrtRatioBX96
            ) / sqrtRatioAX96;
        }
    }

    /// @notice Computes the amount of token1 for a given amount of liquidity and a price range
    /// @param sqrtRatioAX96 A sqrt price representing the first tick boundary
    /// @param sqrtRatioBX96 A sqrt price representing the second tick boundary
    /// @param liquidity The liquidity being valued
    /// @return amount1 The amount of token1
    function getAmount1ForLiquidity(uint160 sqrtRatioAX96, uint160 sqrtRatioBX96, uint128 liquidity)
        internal
        pure
        returns (uint256 amount1)
    {
        unchecked {
            if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

            return FullMath.mulDiv(liquidity, sqrtRatioBX96 - sqrtRatioAX96, FixedPoint96.Q96);
        }
    }

    /// @notice Computes the token0 and token1 value for a given amount of liquidity, the current
    /// pool prices and the prices at the tick boundaries
    /// @param sqrtRatioX96 A sqrt price representing the current pool prices
    /// @param sqrtRatioAX96 A sqrt price representing the first tick boundary
    /// @param sqrtRatioBX96 A sqrt price representing the second tick boundary
    /// @param liquidity The liquidity being valued
    /// @return amount0 The amount of token0
    /// @return amount1 The amount of token1
    function getAmountsForLiquidity(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        if (sqrtRatioX96 <= sqrtRatioAX96) {
            amount0 = getAmount0ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity);
        } else if (sqrtRatioX96 < sqrtRatioBX96) {
            amount0 = getAmount0ForLiquidity(sqrtRatioX96, sqrtRatioBX96, liquidity);
            amount1 = getAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioX96, liquidity);
        } else {
            amount1 = getAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity);
        }
    }
}

// lib/accounts-v2/lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol

/// @title Math library for computing sqrt prices from ticks and vice versa
/// @notice Computes sqrt price for ticks of size 1.0001, i.e. sqrt(1.0001^tick) as fixed point Q64.96 numbers. Supports
/// prices between 2**-128 and 2**128
library TickMath {
    using CustomRevert for bytes4;

    /// @notice Thrown when the tick passed to #getSqrtPriceAtTick is not between MIN_TICK and MAX_TICK
    error InvalidTick(int24 tick);
    /// @notice Thrown when the price passed to #getTickAtSqrtPrice does not correspond to a price between MIN_TICK and MAX_TICK
    error InvalidSqrtPrice(uint160 sqrtPriceX96);

    /// @dev The minimum tick that may be passed to #getSqrtPriceAtTick computed from log base 1.0001 of 2**-128
    /// @dev If ever MIN_TICK and MAX_TICK are not centered around 0, the absTick logic in getSqrtPriceAtTick cannot be used
    int24 internal constant MIN_TICK = -887272;
    /// @dev The maximum tick that may be passed to #getSqrtPriceAtTick computed from log base 1.0001 of 2**128
    /// @dev If ever MIN_TICK and MAX_TICK are not centered around 0, the absTick logic in getSqrtPriceAtTick cannot be used
    int24 internal constant MAX_TICK = 887272;

    /// @dev The minimum tick spacing value drawn from the range of type int16 that is greater than 0, i.e. min from the range [1, 32767]
    int24 internal constant MIN_TICK_SPACING = 1;
    /// @dev The maximum tick spacing value drawn from the range of type int16, i.e. max from the range [1, 32767]
    int24 internal constant MAX_TICK_SPACING = type(int16).max;

    /// @dev The minimum value that can be returned from #getSqrtPriceAtTick. Equivalent to getSqrtPriceAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_PRICE = 4295128739;
    /// @dev The maximum value that can be returned from #getSqrtPriceAtTick. Equivalent to getSqrtPriceAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_PRICE = 1461446703485210103287273052203988822378723970342;
    /// @dev A threshold used for optimized bounds check, equals `MAX_SQRT_PRICE - MIN_SQRT_PRICE - 1`
    uint160 internal constant MAX_SQRT_PRICE_MINUS_MIN_SQRT_PRICE_MINUS_ONE =
        1461446703485210103287273052203988822378723970342 - 4295128739 - 1;

    /// @notice Given a tickSpacing, compute the maximum usable tick
    function maxUsableTick(int24 tickSpacing) internal pure returns (int24) {
        unchecked {
            return (MAX_TICK / tickSpacing) * tickSpacing;
        }
    }

    /// @notice Given a tickSpacing, compute the minimum usable tick
    function minUsableTick(int24 tickSpacing) internal pure returns (int24) {
        unchecked {
            return (MIN_TICK / tickSpacing) * tickSpacing;
        }
    }

    /// @notice Calculates sqrt(1.0001^tick) * 2^96
    /// @dev Throws if |tick| > max tick
    /// @param tick The input tick for the above formula
    /// @return sqrtPriceX96 A Fixed point Q64.96 number representing the sqrt of the price of the two assets (currency1/currency0)
    /// at the given tick
    function getSqrtPriceAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
        unchecked {
            uint256 absTick;
            assembly ("memory-safe") {
                tick := signextend(2, tick)
                // mask = 0 if tick >= 0 else -1 (all 1s)
                let mask := sar(255, tick)
                // if tick >= 0, |tick| = tick = 0 ^ tick
                // if tick < 0, |tick| = ~~|tick| = ~(-|tick| - 1) = ~(tick - 1) = (-1) ^ (tick - 1)
                // either way, |tick| = mask ^ (tick + mask)
                absTick := xor(mask, add(mask, tick))
            }

            if (absTick > uint256(int256(MAX_TICK))) InvalidTick.selector.revertWith(tick);

            // The tick is decomposed into bits, and for each bit with index i that is set, the product of 1/sqrt(1.0001^(2^i))
            // is calculated (using Q128.128). The constants used for this calculation are rounded to the nearest integer

            // Equivalent to:
            //     price = absTick & 0x1 != 0 ? 0xfffcb933bd6fad37aa2d162d1a594001 : 0x100000000000000000000000000000000;
            //     or price = int(2**128 / sqrt(1.0001)) if (absTick & 0x1) else 1 << 128
            uint256 price;
            assembly ("memory-safe") {
                price := xor(shl(128, 1), mul(xor(shl(128, 1), 0xfffcb933bd6fad37aa2d162d1a594001), and(absTick, 0x1)))
            }
            if (absTick & 0x2 != 0) price = (price * 0xfff97272373d413259a46990580e213a) >> 128;
            if (absTick & 0x4 != 0) price = (price * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
            if (absTick & 0x8 != 0) price = (price * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
            if (absTick & 0x10 != 0) price = (price * 0xffcb9843d60f6159c9db58835c926644) >> 128;
            if (absTick & 0x20 != 0) price = (price * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
            if (absTick & 0x40 != 0) price = (price * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
            if (absTick & 0x80 != 0) price = (price * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
            if (absTick & 0x100 != 0) price = (price * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
            if (absTick & 0x200 != 0) price = (price * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
            if (absTick & 0x400 != 0) price = (price * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
            if (absTick & 0x800 != 0) price = (price * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
            if (absTick & 0x1000 != 0) price = (price * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
            if (absTick & 0x2000 != 0) price = (price * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
            if (absTick & 0x4000 != 0) price = (price * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
            if (absTick & 0x8000 != 0) price = (price * 0x31be135f97d08fd981231505542fcfa6) >> 128;
            if (absTick & 0x10000 != 0) price = (price * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
            if (absTick & 0x20000 != 0) price = (price * 0x5d6af8dedb81196699c329225ee604) >> 128;
            if (absTick & 0x40000 != 0) price = (price * 0x2216e584f5fa1ea926041bedfe98) >> 128;
            if (absTick & 0x80000 != 0) price = (price * 0x48a170391f7dc42444e8fa2) >> 128;

            assembly ("memory-safe") {
                // if (tick > 0) price = type(uint256).max / price;
                if sgt(tick, 0) { price := div(not(0), price) }

                // this divides by 1<<32 rounding up to go from a Q128.128 to a Q128.96.
                // we then downcast because we know the result always fits within 160 bits due to our tick input constraint
                // we round up in the division so getTickAtSqrtPrice of the output price is always consistent
                // `sub(shl(32, 1), 1)` is `type(uint32).max`
                // `price + type(uint32).max` will not overflow because `price` fits in 192 bits
                sqrtPriceX96 := shr(32, add(price, sub(shl(32, 1), 1)))
            }
        }
    }

    /// @notice Calculates the greatest tick value such that getSqrtPriceAtTick(tick) <= sqrtPriceX96
    /// @dev Throws in case sqrtPriceX96 < MIN_SQRT_PRICE, as MIN_SQRT_PRICE is the lowest value getSqrtPriceAtTick may
    /// ever return.
    /// @param sqrtPriceX96 The sqrt price for which to compute the tick as a Q64.96
    /// @return tick The greatest tick for which the getSqrtPriceAtTick(tick) is less than or equal to the input sqrtPriceX96
    function getTickAtSqrtPrice(uint160 sqrtPriceX96) internal pure returns (int24 tick) {
        unchecked {
            // Equivalent: if (sqrtPriceX96 < MIN_SQRT_PRICE || sqrtPriceX96 >= MAX_SQRT_PRICE) revert InvalidSqrtPrice();
            // second inequality must be >= because the price can never reach the price at the max tick
            // if sqrtPriceX96 < MIN_SQRT_PRICE, the `sub` underflows and `gt` is true
            // if sqrtPriceX96 >= MAX_SQRT_PRICE, sqrtPriceX96 - MIN_SQRT_PRICE > MAX_SQRT_PRICE - MIN_SQRT_PRICE - 1
            if ((sqrtPriceX96 - MIN_SQRT_PRICE) > MAX_SQRT_PRICE_MINUS_MIN_SQRT_PRICE_MINUS_ONE) {
                InvalidSqrtPrice.selector.revertWith(sqrtPriceX96);
            }

            uint256 price = uint256(sqrtPriceX96) << 32;

            uint256 r = price;
            uint256 msb = BitMath.mostSignificantBit(r);

            if (msb >= 128) r = price >> (msb - 127);
            else r = price << (127 - msb);

            int256 log_2 = (int256(msb) - 128) << 64;

            assembly ("memory-safe") {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(63, f))
                r := shr(f, r)
            }
            assembly ("memory-safe") {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(62, f))
                r := shr(f, r)
            }
            assembly ("memory-safe") {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(61, f))
                r := shr(f, r)
            }
            assembly ("memory-safe") {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(60, f))
                r := shr(f, r)
            }
            assembly ("memory-safe") {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(59, f))
                r := shr(f, r)
            }
            assembly ("memory-safe") {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(58, f))
                r := shr(f, r)
            }
            assembly ("memory-safe") {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(57, f))
                r := shr(f, r)
            }
            assembly ("memory-safe") {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(56, f))
                r := shr(f, r)
            }
            assembly ("memory-safe") {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(55, f))
                r := shr(f, r)
            }
            assembly ("memory-safe") {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(54, f))
                r := shr(f, r)
            }
            assembly ("memory-safe") {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(53, f))
                r := shr(f, r)
            }
            assembly ("memory-safe") {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(52, f))
                r := shr(f, r)
            }
            assembly ("memory-safe") {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(51, f))
                r := shr(f, r)
            }
            assembly ("memory-safe") {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(50, f))
            }

            int256 log_sqrt10001 = log_2 * 255738958999603826347141; // Q22.128 number

            // Magic number represents the ceiling of the maximum value of the error when approximating log_sqrt10001(x)
            int24 tickLow = int24((log_sqrt10001 - 3402992956809132418596140100660247210) >> 128);

            // Magic number represents the minimum value of the error when approximating log_sqrt10001(x), when
            // sqrtPrice is from the range (2^-64, 2^64). This is safe as MIN_SQRT_PRICE is more than 2^-64. If MIN_SQRT_PRICE
            // is changed, this may need to be changed too
            int24 tickHi = int24((log_sqrt10001 + 291339464771989622907027621153398088495) >> 128);

            tick = tickLow == tickHi ? tickLow : getSqrtPriceAtTick(tickHi) <= sqrtPriceX96 ? tickHi : tickLow;
        }
    }
}

// src/libraries/TwapLogic.sol
/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

library TwapLogic {
    // The Number of seconds in the past from which to calculate the time-weighted tick.
    uint32 public constant TWAT_INTERVAL = 5 minutes;

    /**
     * @notice Calculates the time weighted average tick over 300s.
     * @param pool The liquidity pool.
     * @return tick The time weighted average tick over 300s.
     * @dev We do not use the TWAT price to calculate the current value of the asset.
     * It is used only to ensure that the deposited Liquidity range and thus
     * the risk of exposure manipulation is acceptable.
     */
    function _getTwat(address pool) internal view returns (int24 tick) {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[1] = TWAT_INTERVAL; // We take a 5 minute time interval.

        (int56[] memory tickCumulatives,) = ICLPool(pool).observe(secondsAgos);

        tick = int24((tickCumulatives[0] - tickCumulatives[1]) / int32(TWAT_INTERVAL));
    }
}

// lib/accounts-v2/lib/v4-periphery/lib/v4-core/src/libraries/SqrtPriceMath.sol

/// @title Functions based on Q64.96 sqrt price and liquidity
/// @notice Contains the math that uses square root of price as a Q64.96 and liquidity to compute deltas
library SqrtPriceMath {
    using SafeCast for uint256;

    error InvalidPriceOrLiquidity();
    error InvalidPrice();
    error NotEnoughLiquidity();
    error PriceOverflow();

    /// @notice Gets the next sqrt price given a delta of currency0
    /// @dev Always rounds up, because in the exact output case (increasing price) we need to move the price at least
    /// far enough to get the desired output amount, and in the exact input case (decreasing price) we need to move the
    /// price less in order to not send too much output.
    /// The most precise formula for this is liquidity * sqrtPX96 / (liquidity +- amount * sqrtPX96),
    /// if this is impossible because of overflow, we calculate liquidity / (liquidity / sqrtPX96 +- amount).
    /// @param sqrtPX96 The starting price, i.e. before accounting for the currency0 delta
    /// @param liquidity The amount of usable liquidity
    /// @param amount How much of currency0 to add or remove from virtual reserves
    /// @param add Whether to add or remove the amount of currency0
    /// @return The price after adding or removing amount, depending on add
    function getNextSqrtPriceFromAmount0RoundingUp(uint160 sqrtPX96, uint128 liquidity, uint256 amount, bool add)
        internal
        pure
        returns (uint160)
    {
        // we short circuit amount == 0 because the result is otherwise not guaranteed to equal the input price
        if (amount == 0) return sqrtPX96;
        uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;

        if (add) {
            unchecked {
                uint256 product = amount * sqrtPX96;
                if (product / amount == sqrtPX96) {
                    uint256 denominator = numerator1 + product;
                    if (denominator >= numerator1) {
                        // always fits in 160 bits
                        return uint160(FullMath.mulDivRoundingUp(numerator1, sqrtPX96, denominator));
                    }
                }
            }
            // denominator is checked for overflow
            return uint160(UnsafeMath.divRoundingUp(numerator1, (numerator1 / sqrtPX96) + amount));
        } else {
            unchecked {
                uint256 product = amount * sqrtPX96;
                // if the product overflows, we know the denominator underflows
                // in addition, we must check that the denominator does not underflow
                // equivalent: if (product / amount != sqrtPX96 || numerator1 <= product) revert PriceOverflow();
                assembly ("memory-safe") {
                    if iszero(
                        and(
                            eq(div(product, amount), and(sqrtPX96, 0xffffffffffffffffffffffffffffffffffffffff)),
                            gt(numerator1, product)
                        )
                    ) {
                        mstore(0, 0xf5c787f1) // selector for PriceOverflow()
                        revert(0x1c, 0x04)
                    }
                }
                uint256 denominator = numerator1 - product;
                return FullMath.mulDivRoundingUp(numerator1, sqrtPX96, denominator).toUint160();
            }
        }
    }

    /// @notice Gets the next sqrt price given a delta of currency1
    /// @dev Always rounds down, because in the exact output case (decreasing price) we need to move the price at least
    /// far enough to get the desired output amount, and in the exact input case (increasing price) we need to move the
    /// price less in order to not send too much output.
    /// The formula we compute is within <1 wei of the lossless version: sqrtPX96 +- amount / liquidity
    /// @param sqrtPX96 The starting price, i.e., before accounting for the currency1 delta
    /// @param liquidity The amount of usable liquidity
    /// @param amount How much of currency1 to add, or remove, from virtual reserves
    /// @param add Whether to add, or remove, the amount of currency1
    /// @return The price after adding or removing `amount`
    function getNextSqrtPriceFromAmount1RoundingDown(uint160 sqrtPX96, uint128 liquidity, uint256 amount, bool add)
        internal
        pure
        returns (uint160)
    {
        // if we're adding (subtracting), rounding down requires rounding the quotient down (up)
        // in both cases, avoid a mulDiv for most inputs
        if (add) {
            uint256 quotient = (
                amount <= type(uint160).max
                    ? (amount << FixedPoint96.RESOLUTION) / liquidity
                    : FullMath.mulDiv(amount, FixedPoint96.Q96, liquidity)
            );

            return (uint256(sqrtPX96) + quotient).toUint160();
        } else {
            uint256 quotient = (
                amount <= type(uint160).max
                    ? UnsafeMath.divRoundingUp(amount << FixedPoint96.RESOLUTION, liquidity)
                    : FullMath.mulDivRoundingUp(amount, FixedPoint96.Q96, liquidity)
            );

            // equivalent: if (sqrtPX96 <= quotient) revert NotEnoughLiquidity();
            assembly ("memory-safe") {
                if iszero(gt(and(sqrtPX96, 0xffffffffffffffffffffffffffffffffffffffff), quotient)) {
                    mstore(0, 0x4323a555) // selector for NotEnoughLiquidity()
                    revert(0x1c, 0x04)
                }
            }
            // always fits 160 bits
            unchecked {
                return uint160(sqrtPX96 - quotient);
            }
        }
    }

    /// @notice Gets the next sqrt price given an input amount of currency0 or currency1
    /// @dev Throws if price or liquidity are 0, or if the next price is out of bounds
    /// @param sqrtPX96 The starting price, i.e., before accounting for the input amount
    /// @param liquidity The amount of usable liquidity
    /// @param amountIn How much of currency0, or currency1, is being swapped in
    /// @param zeroForOne Whether the amount in is currency0 or currency1
    /// @return uint160 The price after adding the input amount to currency0 or currency1
    function getNextSqrtPriceFromInput(uint160 sqrtPX96, uint128 liquidity, uint256 amountIn, bool zeroForOne)
        internal
        pure
        returns (uint160)
    {
        // equivalent: if (sqrtPX96 == 0 || liquidity == 0) revert InvalidPriceOrLiquidity();
        assembly ("memory-safe") {
            if or(
                iszero(and(sqrtPX96, 0xffffffffffffffffffffffffffffffffffffffff)),
                iszero(and(liquidity, 0xffffffffffffffffffffffffffffffff))
            ) {
                mstore(0, 0x4f2461b8) // selector for InvalidPriceOrLiquidity()
                revert(0x1c, 0x04)
            }
        }

        // round to make sure that we don't pass the target price
        return zeroForOne
            ? getNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountIn, true)
            : getNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountIn, true);
    }

    /// @notice Gets the next sqrt price given an output amount of currency0 or currency1
    /// @dev Throws if price or liquidity are 0 or the next price is out of bounds
    /// @param sqrtPX96 The starting price before accounting for the output amount
    /// @param liquidity The amount of usable liquidity
    /// @param amountOut How much of currency0, or currency1, is being swapped out
    /// @param zeroForOne Whether the amount out is currency1 or currency0
    /// @return uint160 The price after removing the output amount of currency0 or currency1
    function getNextSqrtPriceFromOutput(uint160 sqrtPX96, uint128 liquidity, uint256 amountOut, bool zeroForOne)
        internal
        pure
        returns (uint160)
    {
        // equivalent: if (sqrtPX96 == 0 || liquidity == 0) revert InvalidPriceOrLiquidity();
        assembly ("memory-safe") {
            if or(
                iszero(and(sqrtPX96, 0xffffffffffffffffffffffffffffffffffffffff)),
                iszero(and(liquidity, 0xffffffffffffffffffffffffffffffff))
            ) {
                mstore(0, 0x4f2461b8) // selector for InvalidPriceOrLiquidity()
                revert(0x1c, 0x04)
            }
        }

        // round to make sure that we pass the target price
        return zeroForOne
            ? getNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountOut, false)
            : getNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountOut, false);
    }

    /// @notice Gets the amount0 delta between two prices
    /// @dev Calculates liquidity / sqrt(lower) - liquidity / sqrt(upper),
    /// i.e. liquidity * (sqrt(upper) - sqrt(lower)) / (sqrt(upper) * sqrt(lower))
    /// @param sqrtPriceAX96 A sqrt price
    /// @param sqrtPriceBX96 Another sqrt price
    /// @param liquidity The amount of usable liquidity
    /// @param roundUp Whether to round the amount up or down
    /// @return uint256 Amount of currency0 required to cover a position of size liquidity between the two passed prices
    function getAmount0Delta(uint160 sqrtPriceAX96, uint160 sqrtPriceBX96, uint128 liquidity, bool roundUp)
        internal
        pure
        returns (uint256)
    {
        unchecked {
            if (sqrtPriceAX96 > sqrtPriceBX96) (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);

            // equivalent: if (sqrtPriceAX96 == 0) revert InvalidPrice();
            assembly ("memory-safe") {
                if iszero(and(sqrtPriceAX96, 0xffffffffffffffffffffffffffffffffffffffff)) {
                    mstore(0, 0x00bfc921) // selector for InvalidPrice()
                    revert(0x1c, 0x04)
                }
            }

            uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;
            uint256 numerator2 = sqrtPriceBX96 - sqrtPriceAX96;

            return roundUp
                ? UnsafeMath.divRoundingUp(FullMath.mulDivRoundingUp(numerator1, numerator2, sqrtPriceBX96), sqrtPriceAX96)
                : FullMath.mulDiv(numerator1, numerator2, sqrtPriceBX96) / sqrtPriceAX96;
        }
    }

    /// @notice Equivalent to: `a >= b ? a - b : b - a`
    function absDiff(uint160 a, uint160 b) internal pure returns (uint256 res) {
        assembly ("memory-safe") {
            let diff :=
                sub(and(a, 0xffffffffffffffffffffffffffffffffffffffff), and(b, 0xffffffffffffffffffffffffffffffffffffffff))
            // mask = 0 if a >= b else -1 (all 1s)
            let mask := sar(255, diff)
            // if a >= b, res = a - b = 0 ^ (a - b)
            // if a < b, res = b - a = ~~(b - a) = ~(-(b - a) - 1) = ~(a - b - 1) = (-1) ^ (a - b - 1)
            // either way, res = mask ^ (a - b + mask)
            res := xor(mask, add(mask, diff))
        }
    }

    /// @notice Gets the amount1 delta between two prices
    /// @dev Calculates liquidity * (sqrt(upper) - sqrt(lower))
    /// @param sqrtPriceAX96 A sqrt price
    /// @param sqrtPriceBX96 Another sqrt price
    /// @param liquidity The amount of usable liquidity
    /// @param roundUp Whether to round the amount up, or down
    /// @return amount1 Amount of currency1 required to cover a position of size liquidity between the two passed prices
    function getAmount1Delta(uint160 sqrtPriceAX96, uint160 sqrtPriceBX96, uint128 liquidity, bool roundUp)
        internal
        pure
        returns (uint256 amount1)
    {
        uint256 numerator = absDiff(sqrtPriceAX96, sqrtPriceBX96);
        uint256 denominator = FixedPoint96.Q96;
        uint256 _liquidity = uint256(liquidity);

        /**
         * Equivalent to:
         *   amount1 = roundUp
         *       ? FullMath.mulDivRoundingUp(liquidity, sqrtPriceBX96 - sqrtPriceAX96, FixedPoint96.Q96)
         *       : FullMath.mulDiv(liquidity, sqrtPriceBX96 - sqrtPriceAX96, FixedPoint96.Q96);
         * Cannot overflow because `type(uint128).max * type(uint160).max >> 96 < (1 << 192)`.
         */
        amount1 = FullMath.mulDiv(_liquidity, numerator, denominator);
        assembly ("memory-safe") {
            amount1 := add(amount1, and(gt(mulmod(_liquidity, numerator, denominator), 0), roundUp))
        }
    }

    /// @notice Helper that gets signed currency0 delta
    /// @param sqrtPriceAX96 A sqrt price
    /// @param sqrtPriceBX96 Another sqrt price
    /// @param liquidity The change in liquidity for which to compute the amount0 delta
    /// @return int256 Amount of currency0 corresponding to the passed liquidityDelta between the two prices
    function getAmount0Delta(uint160 sqrtPriceAX96, uint160 sqrtPriceBX96, int128 liquidity)
        internal
        pure
        returns (int256)
    {
        unchecked {
            return liquidity < 0
                ? getAmount0Delta(sqrtPriceAX96, sqrtPriceBX96, uint128(-liquidity), false).toInt256()
                : -getAmount0Delta(sqrtPriceAX96, sqrtPriceBX96, uint128(liquidity), true).toInt256();
        }
    }

    /// @notice Helper that gets signed currency1 delta
    /// @param sqrtPriceAX96 A sqrt price
    /// @param sqrtPriceBX96 Another sqrt price
    /// @param liquidity The change in liquidity for which to compute the amount1 delta
    /// @return int256 Amount of currency1 corresponding to the passed liquidityDelta between the two prices
    function getAmount1Delta(uint160 sqrtPriceAX96, uint160 sqrtPriceBX96, int128 liquidity)
        internal
        pure
        returns (int256)
    {
        unchecked {
            return liquidity < 0
                ? getAmount1Delta(sqrtPriceAX96, sqrtPriceBX96, uint128(-liquidity), false).toInt256()
                : -getAmount1Delta(sqrtPriceAX96, sqrtPriceBX96, uint128(liquidity), true).toInt256();
        }
    }
}

// src/rebalancers/libraries/PricingLogic.sol
/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

library PricingLogic {
    using FixedPointMathLib for uint256;

    // The binary precision of sqrtPriceX96 squared.
    uint256 internal constant Q192 = FixedPoint96.Q96 ** 2;

    /**
     * @notice Calculates the value of one token in the other token for a given amountIn and sqrtPriceX96.
     * Does not take into account slippage and fees.
     * @param sqrtPriceX96 The square root of the price (token1/token0), with 96 binary precision.
     * @param zeroToOne Bool indicating if token0 has to be swapped to token1 or opposite.
     * @param amountIn The amount that of tokenIn that must be swapped to tokenOut.
     * @return amountOut The amount of tokenOut.
     * @dev Function will revert for all pools where the sqrtPriceX96 is bigger than type(uint128).max.
     * type(uint128).max is currently more than enough for all supported pools.
     * If ever the sqrtPriceX96 of a pool exceeds type(uint128).max, a different rebalancer has to be deployed,
     * which does two consecutive mulDivs.
     */
    function _getSpotValue(uint256 sqrtPriceX96, bool zeroToOne, uint256 amountIn)
        internal
        pure
        returns (uint256 amountOut)
    {
        amountOut = zeroToOne
            ? FullMath.mulDiv(amountIn, sqrtPriceX96 ** 2, Q192)
            : FullMath.mulDiv(amountIn, Q192, sqrtPriceX96 ** 2);
    }

    /**
     * @notice Calculates the sqrtPriceX96 (token1/token0) from trusted USD prices of both tokens.
     * @param priceToken0 The price of 1e18 tokens of token0 in USD, with 18 decimals precision.
     * @param priceToken1 The price of 1e18 tokens of token1 in USD, with 18 decimals precision.
     * @return sqrtPriceX96 The square root of the price (token1/token0), with 96 binary precision.
     * @dev The price in Uniswap V3 is defined as:
     * price = amountToken1/amountToken0.
     * The usdPriceToken is defined as: usdPriceToken = amountUsd/amountToken.
     * => amountToken = amountUsd/usdPriceToken.
     * Hence we can derive the Uniswap V3 price as:
     * price = (amountUsd/usdPriceToken1)/(amountUsd/usdPriceToken0) = usdPriceToken0/usdPriceToken1.
     */
    function _getSqrtPriceX96(uint256 priceToken0, uint256 priceToken1) internal pure returns (uint160 sqrtPriceX96) {
        if (priceToken1 == 0) return TickMath.MAX_SQRT_PRICE;

        // Both priceTokens have 18 decimals precision and result of division should have 28 decimals precision.
        // -> multiply by 1e28
        // priceXd28 will overflow if priceToken0 is greater than 1.158e+49.
        // For WBTC (which only has 8 decimals) this would require a bitcoin price greater than 115 792 089 237 316 198 989 824 USD/BTC.
        uint256 priceXd28 = priceToken0.mulDivDown(1e28, priceToken1);
        // Square root of a number with 28 decimals precision has 14 decimals precision.
        uint256 sqrtPriceXd14 = FixedPointMathLib.sqrt(priceXd28);

        // Change sqrtPrice from a decimal fixed point number with 14 digits to a binary fixed point number with 96 digits.
        // Unsafe cast: Cast will only overflow when priceToken0/priceToken1 >= 2^128.
        sqrtPriceX96 = uint160((sqrtPriceXd14 << FixedPoint96.RESOLUTION) / 1e14);
    }
}

// src/rebalancers/libraries/RebalanceLogic.sol
/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

library RebalanceLogic {
    using FixedPointMathLib for uint256;

    // The binary precision of sqrtPriceX96 squared.
    uint256 internal constant Q192 = PricingLogic.Q192;

    /**
     * @notice Returns the parameters and constraints to rebalance the position.
     * Both parameters and constraints are calculated based on a hypothetical swap (in the pool itself with fees but without slippage),
     * that maximizes the amount of liquidity that can be added to the positions (no leftovers of either token0 or token1).
     * @param minLiquidityRatio The ratio of the minimum amount of liquidity that must be minted,
     * relative to the hypothetical amount of liquidity when we rebalance without slippage, with 18 decimals precision.
     * @param poolFee The fee of the pool, with 6 decimals precision.
     * @param initiatorFee The fee of the initiator, with 18 decimals precision.
     * @param sqrtPrice The square root of the price (token1/token0), with 96 binary precision.
     * @param sqrtRatioLower The square root price of the lower tick of the liquidity position, with 96 binary precision.
     * @param sqrtRatioUpper The square root price of the upper tick of the liquidity position, with 96 binary precision.
     * @param balance0 The amount of token0 that is available for the rebalance.
     * @param balance1 The amount of token1 that is available for the rebalance.
     * @return minLiquidity The minimum amount of liquidity that must be added to the position.
     * @return zeroToOne Bool indicating if token0 has to be swapped to token1 or opposite.
     * @return amountInitiatorFee The amount of initiator fee, in tokenIn.
     * @return amountIn An approximation of the amount of tokenIn, based on the optimal swap through the pool itself without slippage.
     * @return amountOut An approximation of the amount of tokenOut, based on the optimal swap through the pool itself without slippage.
     */
    function _getRebalanceParams(
        uint256 minLiquidityRatio,
        uint256 poolFee,
        uint256 initiatorFee,
        uint256 sqrtPrice,
        uint256 sqrtRatioLower,
        uint256 sqrtRatioUpper,
        uint256 balance0,
        uint256 balance1
    )
        internal
        pure
        returns (uint256 minLiquidity, bool zeroToOne, uint256 amountInitiatorFee, uint256 amountIn, uint256 amountOut)
    {
        // Total fee is pool fee + initiator fee, with 18 decimals precision.
        // Since Uniswap uses 6 decimals precision for the fee, we have to multiply the pool fee by 1e12.
        uint256 fee;
        unchecked {
            fee = initiatorFee + poolFee * 1e12;
        }

        // Calculate the swap parameters
        (zeroToOne, amountIn, amountOut) =
            _getSwapParams(sqrtPrice, sqrtRatioLower, sqrtRatioUpper, balance0, balance1, fee);

        // Calculate the maximum amount of liquidity that can be added to the position.
        {
            uint256 liquidity = LiquidityAmounts.getLiquidityForAmounts(
                uint160(sqrtPrice),
                uint160(sqrtRatioLower),
                uint160(sqrtRatioUpper),
                zeroToOne ? balance0 - amountIn : balance0 + amountOut,
                zeroToOne ? balance1 + amountOut : balance1 - amountIn
            );
            minLiquidity = liquidity.mulDivDown(minLiquidityRatio, 1e18);
        }

        // Get initiator fee amount and the actual amountIn of the swap (without initiator fee).
        unchecked {
            amountInitiatorFee = amountIn.mulDivDown(initiatorFee, 1e18);
            amountIn = amountIn - amountInitiatorFee;
        }
    }

    /**
     * @notice Calculates the swap parameters, calculated based on a hypothetical swap (in the pool itself with fees but without slippage).
     * that maximizes the amount of liquidity that can be added to the positions (no leftovers of either token0 or token1).
     * @param sqrtPrice The square root of the price (token1/token0), with 96 binary precision.
     * @param sqrtRatioLower The square root price of the lower tick of the liquidity position, with 96 binary precision.
     * @param sqrtRatioUpper The square root price of the upper tick of the liquidity position, with 96 binary precision.
     * @param balance0 The amount of token0 that is available for the rebalance.
     * @param balance1 The amount of token1 that is available for the rebalance.
     * @param fee The swapping fees, with 18 decimals precision.
     * @return zeroToOne Bool indicating if token0 has to be swapped to token1 or opposite.
     * @return amountIn An approximation of the amount of tokenIn, based on the optimal swap through the pool itself without slippage.
     * @return amountOut An approximation of the amount of tokenOut, based on the optimal swap through the pool itself without slippage.
     * @dev The swap parameters are derived as follows:
     * 1) First we check if the position is in or out of range.
     *   - If the current price is above the position, the solution is trivial: we swap the full position to token1.
     *   - If the current price is below the position, similar, we swap the full position to token0.
     *   - If the position is in range we proceed with step 2.
     *
     * 2) If the position is in range, we start with calculating the "Target Ratio" and "Current Ratio".
     *    Both ratio's are defined as the value of the amount of token1 compared to the total value of the position:
     *    R = valueToken1 / [valueToken0 + valueToken1]
     *    If we express all values in token1 and use the current pool price to denominate token0 in token1:
     *    R = amount1 / [amount0 * sqrtPrice² + amount1]
     *
     *    a) The "Target Ratio" (R_target) is the ratio of the new liquidity position.
     *       It is calculated with the current price and the upper and lower prices of the liquidity position,
     *       see _getTargetRatio() for the derivation.
     *       To maximise the liquidity of the new position, the balances after the swap should approximate it as close as possible to not have any leftovers.
     *    b) The "Current Ratio" (R_current) is the ratio of the current token balances, it is calculated as follows:
     *       R_current = balance1 / [balance0 * sqrtPrice² + balance1].
     *
     * 3) From R_target and R_current we can finally derive the direction of the swap, amountIn and amountOut.
     *    If R_current is smaller than R_target, we have to swap an amount of token0 to token1, and vice versa.
     *    amountIn and amountOut can be found by solving the following equalities:
     *      a) The ratio of the token balances after the swap equal the "Target Ratio".
     *      b) The swap between token0 and token1 is done in the pool itself,
     *         taking into account fees, but ignoring slippage (-> sqrtPrice remains constant).
     *
     *    If R_current < R_target (swap token0 to token1):
     *      a) R_target = [amount1 + amoutOut] / [(amount0 - amountIn) * sqrtPrice² + (amount1 + amoutOut)].
     *      b) amountOut = (1 - fee) * amountIn * sqrtPrice².
     *         => amountOut = [(R_target - R_current) * (amount0 * sqrtPrice² + amount1)] / [1 + R_target * fee / (1 - fee)].
     *
     *    If R_current > R_target (swap token1 to token0):
     *      a) R_target = [(amount1 - amountIn)] / [(amount0 + amoutOut) * sqrtPrice² + (amount1 - amountIn)].
     *      b) amountOut = (1 - fee) * amountIn / sqrtPrice².
     *         => amountIn = [(R_current - R_target) * (amount0 * sqrtPrice² + amount1)] / (1 - R_target * fee).
     */
    function _getSwapParams(
        uint256 sqrtPrice,
        uint256 sqrtRatioLower,
        uint256 sqrtRatioUpper,
        uint256 balance0,
        uint256 balance1,
        uint256 fee
    ) internal pure returns (bool zeroToOne, uint256 amountIn, uint256 amountOut) {
        if (sqrtPrice >= sqrtRatioUpper) {
            // New position is out of range and fully in token 1.
            // Rebalance to a single-sided liquidity position in token 1.
            zeroToOne = true;
            amountIn = balance0;
            amountOut = _getAmountOut(sqrtPrice, true, balance0, fee);
        } else if (sqrtPrice <= sqrtRatioLower) {
            // New position is out of range and fully in token 0.
            // Rebalance to a single-sided liquidity position in token 0.
            amountIn = balance1;
            amountOut = _getAmountOut(sqrtPrice, false, balance1, fee);
        } else {
            // Get target ratio in token1 terms.
            uint256 targetRatio = _getTargetRatio(sqrtPrice, sqrtRatioLower, sqrtRatioUpper);

            // Calculate the total position value in token1 equivalent:
            uint256 token0ValueInToken1 = PricingLogic._getSpotValue(sqrtPrice, true, balance0);
            uint256 totalValueInToken1 = balance1 + token0ValueInToken1;

            unchecked {
                // Calculate the current ratio of liquidity in token1 terms.
                uint256 currentRatio = balance1.mulDivDown(1e18, totalValueInToken1);
                if (currentRatio < targetRatio) {
                    // Swap token0 partially to token1.
                    zeroToOne = true;
                    {
                        uint256 denominator = 1e18 + targetRatio.mulDivDown(fee, 1e18 - fee);
                        amountOut = (targetRatio - currentRatio).mulDivDown(totalValueInToken1, denominator);
                    }
                    amountIn = _getAmountIn(sqrtPrice, true, amountOut, fee);
                } else {
                    // Swap token1 partially to token0.
                    zeroToOne = false;
                    {
                        uint256 denominator = 1e18 - targetRatio.mulDivDown(fee, 1e18);
                        amountIn = (currentRatio - targetRatio).mulDivDown(totalValueInToken1, denominator);
                    }
                    amountOut = _getAmountOut(sqrtPrice, false, amountIn, fee);
                }
            }
        }
    }

    /**
     * @notice Calculates the amountOut for a given amountIn and sqrtPriceX96 for a hypothetical
     * swap though the pool itself with fees but without slippage.
     * @param sqrtPriceX96 The square root of the price (token1/token0), with 96 binary precision.
     * @param zeroToOne Bool indicating if token0 has to be swapped to token1 or opposite.
     * @param amountIn The amount of tokenIn that must be swapped to tokenOut.
     * @param fee The total fee on amountIn, with 18 decimals precision.
     * @return amountOut The amount of tokenOut.
     * @dev Function will revert for all pools where the sqrtPriceX96 is bigger than type(uint128).max.
     * type(uint128).max is currently more than enough for all supported pools.
     * If ever the sqrtPriceX96 of a pool exceeds type(uint128).max, a different rebalancer has to be deployed,
     * which does two consecutive mulDivs.
     */
    function _getAmountOut(uint256 sqrtPriceX96, bool zeroToOne, uint256 amountIn, uint256 fee)
        internal
        pure
        returns (uint256 amountOut)
    {
        require(sqrtPriceX96 <= type(uint128).max);
        unchecked {
            uint256 amountInWithoutFees = (1e18 - fee).mulDivDown(amountIn, 1e18);
            amountOut = zeroToOne
                ? FullMath.mulDiv(amountInWithoutFees, sqrtPriceX96 ** 2, Q192)
                : FullMath.mulDiv(amountInWithoutFees, Q192, sqrtPriceX96 ** 2);
        }
    }

    /**
     * @notice Calculates the amountIn for a given amountOut and sqrtPriceX96 for a hypothetical
     * swap though the pool itself with fees but without slippage.
     * @param sqrtPriceX96 The square root of the price (token1/token0), with 96 binary precision.
     * @param zeroToOne Bool indicating if token0 has to be swapped to token1 or opposite.
     * @param amountOut The amount that tokenOut that must be swapped.
     * @param fee The total fee on amountIn, with 18 decimals precision.
     * @return amountIn The amount of tokenIn.
     * @dev Function will revert for all pools where the sqrtPriceX96 is bigger than type(uint128).max.
     * type(uint128).max is currently more than enough for all supported pools.
     * If ever the sqrtPriceX96 of a pool exceeds type(uint128).max, a different rebalancer has to be deployed,
     * which does two consecutive mulDivs.
     */
    function _getAmountIn(uint256 sqrtPriceX96, bool zeroToOne, uint256 amountOut, uint256 fee)
        internal
        pure
        returns (uint256 amountIn)
    {
        require(sqrtPriceX96 <= type(uint128).max);
        unchecked {
            uint256 amountInWithoutFees = zeroToOne
                ? FullMath.mulDiv(amountOut, Q192, sqrtPriceX96 ** 2)
                : FullMath.mulDiv(amountOut, sqrtPriceX96 ** 2, Q192);
            amountIn = amountInWithoutFees.mulDivDown(1e18, 1e18 - fee);
        }
    }

    /**
     * @notice Calculates the ratio of how much of the total value of a liquidity position has to be provided in token1.
     * @param sqrtPriceX96 The square root of the current pool price (token1/token0), with 96 binary precision.
     * @param sqrtRatioLower The square root price of the lower tick of the liquidity position, with 96 binary precision.
     * @param sqrtRatioUpper The square root price of the upper tick of the liquidity position, with 96 binary precision.
     * @return targetRatio The ratio of the value of token1 compared to the total value of the position, with 18 decimals precision.
     * @dev Function will revert for all pools where the sqrtPriceX96 is bigger than type(uint128).max.
     * type(uint128).max is currently more than enough for all supported pools.
     * If ever the sqrtPriceX96 of a pool exceeds type(uint128).max, a different rebalancer has to be deployed,
     * which does two consecutive mulDivs.
     * @dev Derivation of the formula:
     * 1) The ratio is defined as:
     *    R = valueToken1 / [valueToken0 + valueToken1]
     *    If we express all values in token1 and use the current pool price to denominate token0 in token1:
     *    R = amount1 / [amount0 * sqrtPrice² + amount1]
     * 2) Amount0 for a given liquidity position of a Uniswap V3 pool is given as:
     *    Amount0 = liquidity * (sqrtRatioUpper - sqrtPrice) / (sqrtRatioUpper * sqrtPrice)
     * 3) Amount1 for a given liquidity position of a Uniswap V3 pool is given as:
     *    Amount1 = liquidity * (sqrtPrice - sqrtRatioLower)
     * 4) Combining 1), 2) and 3) and simplifying we get:
     *    R = [sqrtPrice - sqrtRatioLower] / [2 * sqrtPrice - sqrtRatioLower - sqrtPrice² / sqrtRatioUpper]
     */
    function _getTargetRatio(uint256 sqrtPriceX96, uint256 sqrtRatioLower, uint256 sqrtRatioUpper)
        internal
        pure
        returns (uint256 targetRatio)
    {
        require(sqrtPriceX96 <= type(uint128).max);
        // Unchecked: sqrtPriceX96 is always bigger than sqrtRatioLower.
        // Unchecked: sqrtPriceX96 is always smaller than sqrtRatioUpper -> sqrtPriceX96 > sqrtPriceX96 ** 2 / sqrtRatioUpper.
        unchecked {
            uint256 numerator = sqrtPriceX96 - sqrtRatioLower;
            uint256 denominator = 2 * sqrtPriceX96 - sqrtRatioLower - sqrtPriceX96 ** 2 / sqrtRatioUpper;

            targetRatio = numerator.mulDivDown(1e18, denominator);
        }
    }
}

// src/rebalancers/libraries/RebalanceOptimizationMath.sol
/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

library RebalanceOptimizationMath {
    using FixedPointMathLib for uint256;

    // The minimal relative difference between liquidity0 and liquidity1, with 18 decimals precision.
    uint256 internal constant CONVERGENCE_THRESHOLD = 1e6;

    // The maximal number of iterations to find the optimal swap parameters.
    uint256 internal constant MAX_ITERATIONS = 100;

    /**
     * @notice Iteratively calculates the amountOut for a swap through the pool itself, that maximizes the amount of liquidity that is added.
     * The calculations take both fees and slippage into account, but assume constant liquidity.
     * @param zeroToOne Bool indicating if token0 has to be swapped to token1 or opposite.
     * @param fee The fee of the pool, with 6 decimals precision.
     * @param usableLiquidity The amount of active liquidity in the pool, at the current tick.
     * @param sqrtPriceOld The square root of the pool price (token1/token0) before the swap, with 96 binary precision.
     * @param sqrtRatioLower The square root price of the lower tick of the liquidity position, with 96 binary precision.
     * @param sqrtRatioUpper The square root price of the upper tick of the liquidity position, with 96 binary precision.
     * @param amount0 The balance of token0 before the swap.
     * @param amount1 The balance of token1 before the swap.
     * @param amountIn An approximation of the amount of tokenIn, based on the optimal swap through the pool itself without slippage.
     * @param amountOut An approximation of the amount of tokenOut, based on the optimal swap through the pool itself without slippage.
     * @return amountOut The amount of tokenOut.
     * @dev The optimal amountIn and amountOut are defined as the amounts that maximize the amount of liquidity that can be added to the position.
     * This means that there are no leftovers of either token0 or token1,
     * and liquidity0 (calculated via getLiquidityForAmount0) will be exactly equal to liquidity1 (calculated via getLiquidityForAmount1).
     * @dev The optimal amountIn and amountOut depend on the sqrtPrice of the pool via the liquidity calculations,
     * but the sqrtPrice in turn depends on the amountIn and amountOut via the swap calculations.
     * Since both are highly non-linear, this problem is (according to our understanding) not analytically solvable.
     * Therefore we use an iterative approach to find the optimal swap parameters.
     * The stop criterium is defined when the relative difference between liquidity0 and liquidity1 is below the convergence threshold.
     * @dev Convergence is not guaranteed, worst case or the transaction reverts, or a non-optimal swap is performed,
     * But then minLiquidity enforces that either enough liquidity is minted or the transaction will revert.
     * @dev We assume constant active liquidity when calculating the swap parameters.
     * For illiquid pools, or positions that are large relatively to the pool liquidity, this might result in reverting rebalances.
     * But since a minimum amount of liquidity is enforced, should not lead to loss of principal.
     */
    function _getAmountOutWithSlippage(
        bool zeroToOne,
        uint256 fee,
        uint128 usableLiquidity,
        uint160 sqrtPriceOld,
        uint160 sqrtRatioLower,
        uint160 sqrtRatioUpper,
        uint256 amount0,
        uint256 amount1,
        uint256 amountIn,
        uint256 amountOut
    ) internal pure returns (uint256) {
        uint160 sqrtPriceNew;
        bool stopCondition;
        // We iteratively solve for sqrtPrice, amountOut and amountIn, so that the maximal amount of liquidity can be added to the position.
        for (uint256 i = 0; i < MAX_ITERATIONS; ++i) {
            // Find a better approximation for sqrtPrice, given the best approximations for the optimal amountIn and amountOut.
            sqrtPriceNew = _approximateSqrtPriceNew(zeroToOne, fee, usableLiquidity, sqrtPriceOld, amountIn, amountOut);

            // If the position is out of range, we can calculate the exact solution.
            if (sqrtPriceNew >= sqrtRatioUpper) {
                // New position is out of range and fully in token 1.
                // Rebalance to a single-sided liquidity position in token 1.
                // We ignore one edge case: Swapping token0 to token1 decreases the sqrtPrice,
                // hence a swap for a position that is just out of range might become in range due to slippage.
                // This might lead to a suboptimal rebalance, which worst case results in too little liquidity and the rebalance reverts.
                return _getAmount1OutFromAmount0In(fee, usableLiquidity, sqrtPriceOld, amount0);
            } else if (sqrtPriceNew <= sqrtRatioLower) {
                // New position is out of range and fully in token 0.
                // Rebalance to a single-sided liquidity position in token 0.
                // We ignore one edge case: Swapping token1 to token0 increases the sqrtPrice,
                // hence a swap for a position that is just out of range might become in range due to slippage.
                // This might lead to a suboptimal rebalance, which worst case results in too little liquidity and the rebalance reverts.
                return _getAmount0OutFromAmount1In(fee, usableLiquidity, sqrtPriceOld, amount1);
            }

            // If the position is not out of range, calculate the amountIn and amountOut, given the new approximated sqrtPrice.
            (amountIn, amountOut) = _getSwapParamsExact(zeroToOne, fee, usableLiquidity, sqrtPriceOld, sqrtPriceNew);

            // Given the new approximated sqrtPriceNew and its swap amounts,
            // calculate a better approximation for the optimal amountIn and amountOut, that would maximise the liquidity provided
            // (no leftovers of either token0 or token1).
            (stopCondition, amountIn, amountOut) = _approximateOptimalSwapAmounts(
                zeroToOne, sqrtRatioLower, sqrtRatioUpper, amount0, amount1, amountIn, amountOut, sqrtPriceNew
            );

            // Check if stop condition of iteration is met:
            // The relative difference between liquidity0 and liquidity1 is below the convergence threshold.
            if (stopCondition) return amountOut;
            // If not, we do an extra iteration with our better approximated amountIn and amountOut.
        }
        // If solution did not converge within MAX_ITERATIONS steps, we use the amountOut of the last iteration step.
        return amountOut;
    }

    /**
     * @notice Approximates the SqrtPrice after the swap, given an approximation for the amountIn and amountOut that maximise liquidity added.
     * @param zeroToOne Bool indicating if token0 has to be swapped to token1 or opposite.
     * @param fee The fee of the pool, with 6 decimals precision.
     * @param usableLiquidity The amount of active liquidity in the pool, at the current tick.
     * @param sqrtPriceOld The SqrtPrice before the swap.
     * @param amountIn An approximation of the amount of tokenIn, that maximise liquidity added.
     * @param amountOut An approximation of the amount of tokenOut, that maximise liquidity added.
     * @return sqrtPriceNew The approximation of the SqrtPrice after the swap.
     */
    function _approximateSqrtPriceNew(
        bool zeroToOne,
        uint256 fee,
        uint128 usableLiquidity,
        uint160 sqrtPriceOld,
        uint256 amountIn,
        uint256 amountOut
    ) internal pure returns (uint160 sqrtPriceNew) {
        unchecked {
            // Calculate the exact sqrtPriceNew for both amountIn and amountOut.
            // Both solutions will be different, but they will converge with every iteration closer to the same solution.
            uint256 amountInLessFee = amountIn.mulDivDown(1e6 - fee, 1e6);
            uint256 sqrtPriceNew0;
            uint256 sqrtPriceNew1;
            if (zeroToOne) {
                sqrtPriceNew0 = SqrtPriceMath.getNextSqrtPriceFromAmount0RoundingUp(
                    sqrtPriceOld, usableLiquidity, amountInLessFee, true
                );
                sqrtPriceNew1 = SqrtPriceMath.getNextSqrtPriceFromAmount1RoundingDown(
                    sqrtPriceOld, usableLiquidity, amountOut, false
                );
            } else {
                sqrtPriceNew0 =
                    SqrtPriceMath.getNextSqrtPriceFromAmount0RoundingUp(sqrtPriceOld, usableLiquidity, amountOut, false);
                sqrtPriceNew1 = SqrtPriceMath.getNextSqrtPriceFromAmount1RoundingDown(
                    sqrtPriceOld, usableLiquidity, amountInLessFee, true
                );
            }
            // Calculate the new best approximation as the arithmetic average of both solutions (rounded towards current price).
            // We could as well use the geometric average, but empirically we found no difference in conversion speed,
            // and the geometric average is more expensive to calculate.
            // Unchecked + unsafe cast: sqrtPriceNew0 and sqrtPriceNew1 are always smaller than type(uint160).max.
            sqrtPriceNew = zeroToOne
                ? uint160(FixedPointMathLib.unsafeDiv(sqrtPriceNew0 + sqrtPriceNew1, 2))
                : uint160(FixedPointMathLib.unsafeDivUp(sqrtPriceNew0 + sqrtPriceNew1, 2));
        }
    }

    /**
     * @notice Calculates the amountOut of token1, for a given amountIn of token0.
     * @param fee The fee of the pool, with 6 decimals precision.
     * @param usableLiquidity The amount of active liquidity in the pool, at the current tick.
     * @param sqrtPriceOld The SqrtPrice before the swap.
     * @param amount0 The balance of token0 before the swap.
     * @return amountOut The amount of token1 that is swapped to.
     * @dev The calculations take both fees and slippage into account, but assume constant liquidity.
     */
    function _getAmount1OutFromAmount0In(uint256 fee, uint128 usableLiquidity, uint160 sqrtPriceOld, uint256 amount0)
        internal
        pure
        returns (uint256 amountOut)
    {
        unchecked {
            uint256 amountInLessFee = amount0.mulDivUp(1e6 - fee, 1e6);
            uint160 sqrtPriceNew = SqrtPriceMath.getNextSqrtPriceFromAmount0RoundingUp(
                sqrtPriceOld, usableLiquidity, amountInLessFee, true
            );
            amountOut = SqrtPriceMath.getAmount1Delta(sqrtPriceNew, sqrtPriceOld, usableLiquidity, false);
        }
    }

    /**
     * @notice Calculates the amountOut of token0, for a given amountIn of token1.
     * @param fee The fee of the pool, with 6 decimals precision.
     * @param usableLiquidity The amount of active liquidity in the pool, at the current tick.
     * @param sqrtPriceOld The SqrtPrice before the swap.
     * @param amount1 The balance of token1 before the swap.
     * @return amountOut The amount of token0 that is swapped to.
     * @dev The calculations take both fees and slippage into account, but assume constant liquidity.
     */
    function _getAmount0OutFromAmount1In(uint256 fee, uint128 usableLiquidity, uint160 sqrtPriceOld, uint256 amount1)
        internal
        pure
        returns (uint256 amountOut)
    {
        unchecked {
            uint256 amountInLessFee = amount1.mulDivUp(1e6 - fee, 1e6);
            uint160 sqrtPriceNew = SqrtPriceMath.getNextSqrtPriceFromAmount1RoundingDown(
                sqrtPriceOld, usableLiquidity, amountInLessFee, true
            );
            amountOut = SqrtPriceMath.getAmount0Delta(sqrtPriceOld, sqrtPriceNew, usableLiquidity, false);
        }
    }

    /**
     * @notice Calculates the amountIn and amountOut of token0, for a given SqrtPrice after the swap.
     * @param zeroToOne Bool indicating if token0 has to be swapped to token1 or opposite.
     * @param fee The fee of the pool, with 6 decimals precision.
     * @param usableLiquidity The amount of active liquidity in the pool, at the current tick.
     * @param sqrtPriceOld The SqrtPrice before the swap.
     * @param sqrtPriceNew The SqrtPrice after the swap.
     * @return amountIn The amount of tokenIn.
     * @return amountOut The amount of tokenOut.
     * @dev The calculations take both fees and slippage into account, but assume constant liquidity.
     */
    function _getSwapParamsExact(
        bool zeroToOne,
        uint256 fee,
        uint128 usableLiquidity,
        uint160 sqrtPriceOld,
        uint160 sqrtPriceNew
    ) internal pure returns (uint256 amountIn, uint256 amountOut) {
        unchecked {
            if (zeroToOne) {
                uint256 amountInLessFee =
                    SqrtPriceMath.getAmount0Delta(sqrtPriceNew, sqrtPriceOld, usableLiquidity, true);
                amountIn = amountInLessFee.mulDivUp(1e6, 1e6 - fee);
                amountOut = SqrtPriceMath.getAmount1Delta(sqrtPriceNew, sqrtPriceOld, usableLiquidity, false);
            } else {
                uint256 amountInLessFee =
                    SqrtPriceMath.getAmount1Delta(sqrtPriceOld, sqrtPriceNew, usableLiquidity, true);
                amountIn = amountInLessFee.mulDivUp(1e6, 1e6 - fee);
                amountOut = SqrtPriceMath.getAmount0Delta(sqrtPriceOld, sqrtPriceNew, usableLiquidity, false);
            }
        }
    }

    /**
     * @notice Approximates the amountIn and amountOut that maximise liquidity added,
     * given an approximation for the SqrtPrice after the swap and an approximation of the balances of token0 and token1 after the swap.
     * @param zeroToOne Bool indicating if token0 has to be swapped to token1 or opposite.
     * @param sqrtRatioLower The square root price of the lower tick of the liquidity position, with 96 binary precision.
     * @param sqrtRatioUpper The square root price of the upper tick of the liquidity position, with 96 binary precision.
     * @param amount0 The balance of token0 before the swap.
     * @param amount1 The balance of token1 before the swap.
     * @param amountIn An approximation of the amount of tokenIn, used to calculate the approximated balances after the swap.
     * @param amountOut An approximation of the amount of tokenOut, used to calculate the approximated balances after the swap.
     * @param sqrtPrice An approximation of the SqrtPrice after the swap.
     * @return converged Bool indicating if the stop criterium of iteration is met.
     * @return amountIn_ The new approximation of the amount of tokenIn that maximise liquidity added.
     * @return amountOut_ The new approximation of the amount of amountOut that maximise liquidity added.
     */
    function _approximateOptimalSwapAmounts(
        bool zeroToOne,
        uint160 sqrtRatioLower,
        uint160 sqrtRatioUpper,
        uint256 amount0,
        uint256 amount1,
        uint256 amountIn,
        uint256 amountOut,
        uint160 sqrtPrice
    ) internal pure returns (bool, uint256, uint256) {
        unchecked {
            // Calculate the liquidity for the given approximated sqrtPrice and the approximated balances of token0 and token1 after the swap.
            uint256 liquidity0;
            uint256 liquidity1;
            if (zeroToOne) {
                liquidity0 = LiquidityAmounts.getLiquidityForAmount0(
                    sqrtPrice, sqrtRatioUpper, amount0 > amountIn ? amount0 - amountIn : 0
                );
                liquidity1 = LiquidityAmounts.getLiquidityForAmount1(sqrtRatioLower, sqrtPrice, amount1 + amountOut);
            } else {
                liquidity0 = LiquidityAmounts.getLiquidityForAmount0(sqrtPrice, sqrtRatioUpper, amount0 + amountOut);
                liquidity1 = LiquidityAmounts.getLiquidityForAmount1(
                    sqrtRatioLower, sqrtPrice, amount1 > amountIn ? amount1 - amountIn : 0
                );
            }

            // Calculate the relative difference of liquidity0 and liquidity1.
            uint256 relDiff = 1e18
                - (
                    liquidity0 < liquidity1
                        ? liquidity0.mulDivDown(1e18, liquidity1)
                        : liquidity1.mulDivDown(1e18, liquidity0)
                );
            // In the optimal solution liquidity0 equals liquidity1,
            // and there are no leftovers for token0 or token1 after minting the liquidity.
            // Hence the relative distance between liquidity0 and liquidity1
            // is a good estimator how close we are to the optimal solution.
            bool converged = relDiff < CONVERGENCE_THRESHOLD;

            // The new approximated liquidity is the minimum of liquidity0 and liquidity1.
            // Calculate the new approximated amountIn or amountOut,
            // for which this liquidity would be the optimal solution.
            if (liquidity0 < liquidity1) {
                uint256 amount1New = SqrtPriceMath.getAmount1Delta(
                    sqrtRatioLower, sqrtPrice, LiquidityAmounts.toUint128(liquidity0), true
                );
                zeroToOne
                    // Since amountOut can't be negative, we use 90% of the previous amountOut as a fallback.
                    ? amountOut = amount1New > amount1 ? amount1New - amount1 : amountOut.mulDivDown(9, 10)
                    : amountIn = amount1 - amount1New;
            } else {
                uint256 amount0New = SqrtPriceMath.getAmount0Delta(
                    sqrtPrice, sqrtRatioUpper, LiquidityAmounts.toUint128(liquidity1), true
                );
                zeroToOne
                    ? amountIn = amount0 - amount0New
                    // Since amountOut can't be negative, we use 90% of the previous amountOut as a fallback.
                    : amountOut = amount0New > amount0 ? amount0New - amount0 : amountOut.mulDivDown(9, 10);
            }

            return (converged, amountIn, amountOut);
        }
    }
}

// src/rebalancers/libraries/ArcadiaLogic.sol
/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

library ArcadiaLogic {
    // The contract address of the Arcadia Factory.
    IFactory internal constant FACTORY = IFactory(0xDa14Fdd72345c4d2511357214c5B89A919768e59);
    // The contract address of the Arcadia Registry.
    IRegistry internal constant REGISTRY = IRegistry(0xd0690557600eb8Be8391D1d97346e2aab5300d5f);

    /**
     * @notice Returns the trusted USD prices for 1e18 gwei of token0 and token1.
     * @param token0 The contract address of token0.
     * @param token1 The contract address of token1.
     * @param usdPriceToken0 The USD price of 1e18 gwei of token0, with 18 decimals precision.
     * @param usdPriceToken1 The USD price of 1e18 gwei of token1, with 18 decimals precision.
     */
    function _getValuesInUsd(address token0, address token1)
        internal
        view
        returns (uint256 usdPriceToken0, uint256 usdPriceToken1)
    {
        address[] memory assets = new address[](2);
        assets[0] = token0;
        assets[1] = token1;
        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 1e18;
        assetAmounts[1] = 1e18;

        AssetValueAndRiskFactors[] memory valuesAndRiskFactors =
            REGISTRY.getValuesInUsd(address(0), assets, new uint256[](2), assetAmounts);

        (usdPriceToken0, usdPriceToken1) = (valuesAndRiskFactors[0].assetValue, valuesAndRiskFactors[1].assetValue);
    }

    /**
     * @notice Encodes the action data for the flash-action used to rebalance a Liquidity Position.
     * @param positionManager The contract address of the Position Manager.
     * @param id The id of the Liquidity Position.
     * @param initiator The address of the initiator.
     * @param tickLower The new lower tick to rebalance the position to.
     * @param tickUpper The new upper tick to rebalancer the position to.
     * @param swapData Arbitrary calldata provided by an initiator for a swap.
     * @return actionData Bytes string with the encoded data.
     */
    function _encodeAction(
        address positionManager,
        uint256 id,
        address initiator,
        int24 tickLower,
        int24 tickUpper,
        bytes calldata swapData
    ) internal pure returns (bytes memory actionData) {
        // Encode Uniswap V3 position that has to be withdrawn from and deposited back into the Account.
        address[] memory assets_ = new address[](1);
        assets_[0] = positionManager;
        uint256[] memory assetIds_ = new uint256[](1);
        assetIds_[0] = id;
        uint256[] memory assetAmounts_ = new uint256[](1);
        assetAmounts_[0] = 1;
        uint256[] memory assetTypes_ = new uint256[](1);
        assetTypes_[0] = 2;

        ActionData memory assetData =
            ActionData({ assets: assets_, assetIds: assetIds_, assetAmounts: assetAmounts_, assetTypes: assetTypes_ });

        // Empty data objects that have to be encoded when calling flashAction(), but that are not used for this specific flash-action.
        bytes memory signature;
        ActionData memory transferFromOwner;
        IPermit2.PermitBatchTransferFrom memory permit;

        // Data required by this contract when Account does the executeAction() callback during the flash-action.
        bytes memory rebalanceData = abi.encode(assetData, initiator, tickLower, tickUpper, swapData);

        // Encode the actionData.
        actionData = abi.encode(assetData, transferFromOwner, permit, signature, rebalanceData);
    }

    /**
     * @notice Encodes the deposit data after the flash-action used to rebalance the Liquidity Position.
     * @param positionManager The contract address of the Position Manager.
     * @param id The id of the Liquidity Position.
     * @param position Struct with the position data.
     * @param count The number of assets to deposit.
     * @param balance0 The amount of token0 to deposit.
     * @param balance1 The amount of token1 to deposit.
     * @param reward The amount of reward token to deposit.
     * @return depositData Bytes string with the encoded data.
     */
    function _encodeDeposit(
        address positionManager,
        uint256 id,
        Rebalancer.PositionState memory position,
        uint256 count,
        uint256 balance0,
        uint256 balance1,
        uint256 reward
    ) internal pure returns (ActionData memory depositData) {
        depositData.assets = new address[](count);
        depositData.assetIds = new uint256[](count);
        depositData.assetAmounts = new uint256[](count);
        depositData.assetTypes = new uint256[](count);

        // Add newly minted Liquidity Position.
        depositData.assets[0] = positionManager;
        depositData.assetIds[0] = id;
        depositData.assetAmounts[0] = 1;
        depositData.assetTypes[0] = 2;

        // Track the next index for the ERC20 tokens.
        uint256 index = 1;

        if (balance0 > 0) {
            depositData.assets[1] = position.token0;
            depositData.assetAmounts[1] = balance0;
            depositData.assetTypes[1] = 1;
            index = 2;
        }

        if (balance1 > 0) {
            depositData.assets[index] = position.token1;
            depositData.assetAmounts[index] = balance1;
            depositData.assetTypes[index] = 1;
            ++index;
        }

        if (reward > 0) {
            depositData.assets[index] = StakedSlipstreamLogic.REWARD_TOKEN;
            depositData.assetAmounts[index] = reward;
            depositData.assetTypes[index] = 1;
        }
    }
}

// src/rebalancers/libraries/BurnLogic.sol
/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

library BurnLogic {
    /**
     * @notice Burns the Liquidity Position.
     * @param positionManager The contract address of the Position Manager.
     * @param id The id of the Liquidity Position.
     * @param position Struct with the position data.
     * @return balance0 The amount of token0 claimed.
     * @return balance1 The amount of token1 claimed.
     * @return rewards The amount of reward token claimed.
     */
    function _burn(address positionManager, uint256 id, Rebalancer.PositionState memory position)
        internal
        returns (uint256 balance0, uint256 balance1, uint256 rewards)
    {
        // If position is a staked slipstream position, first unstake the position.
        bool staked;
        if (
            positionManager == address(StakedSlipstreamLogic.STAKED_SLIPSTREAM_AM)
                || positionManager == address(StakedSlipstreamLogic.STAKED_SLIPSTREAM_WRAPPER)
        ) {
            // Staking rewards are deposited back into the account at the end of the transaction.
            // Or, if rewardToken is an underlying token of the position, added to the balances
            rewards = IStakedSlipstreamAM(positionManager).burn(id);
            // After the position is unstaked, it becomes a slipstream position.
            positionManager = address(SlipstreamLogic.POSITION_MANAGER);
            staked = true;
        }

        // Remove liquidity of the position and claim outstanding fees to get full amounts of token0 and token1
        // for rebalance.
        IPositionManager(positionManager).decreaseLiquidity(
            DecreaseLiquidityParams({
                tokenId: id,
                liquidity: position.liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );

        // We assume that the amount of tokens to collect never exceeds type(uint128).max.
        (balance0, balance1) = IPositionManager(positionManager).collect(
            CollectParams({
                tokenId: id,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        // Burn the position
        IPositionManager(positionManager).burn(id);

        // If the reward token is the same as one of the underlying tokens, update the token-balance instead.
        if (staked) {
            if (StakedSlipstreamLogic.REWARD_TOKEN == position.token0) {
                (balance0, rewards) = (balance0 + rewards, 0);
            } else if (StakedSlipstreamLogic.REWARD_TOKEN == position.token1) {
                (balance1, rewards) = (balance1 + rewards, 0);
            }
        }
    }
}

// src/rebalancers/libraries/MintLogic.sol
/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

library MintLogic {
    using SafeApprove for ERC20;

    /**
     * @notice Mints a new Liquidity Position.
     * @param positionManager The contract address of the Position Manager.
     * @param position Struct with the position data.
     * @param balance0 The balance of token0 before minting liquidity.
     * @param balance1 The balance of token1 before minting liquidity.
     * @return newTokenId The id of the new Liquidity Position.
     * @return liquidity The amount of liquidity minted.
     * @return balance0_ The remaining balance of token0 after minting liquidity.
     * @return balance1_ The remaining balance of token1 after minting liquidity.
     */
    function _mint(
        address positionManager,
        Rebalancer.PositionState memory position,
        uint256 balance0,
        uint256 balance1
    ) internal returns (uint256 newTokenId, uint256 liquidity, uint256 balance0_, uint256 balance1_) {
        // Before position can be staked, we have to create a slipstream position.
        address stakedPositionManager;
        if (
            positionManager == StakedSlipstreamLogic.STAKED_SLIPSTREAM_AM
                || positionManager == StakedSlipstreamLogic.STAKED_SLIPSTREAM_WRAPPER
        ) {
            stakedPositionManager = positionManager;
            positionManager = address(SlipstreamLogic.POSITION_MANAGER);
        }

        ERC20(position.token0).safeApproveWithRetry(positionManager, balance0);
        ERC20(position.token1).safeApproveWithRetry(positionManager, balance1);

        uint256 amount0;
        uint256 amount1;
        (newTokenId, liquidity, amount0, amount1) = (positionManager == address(UniswapV3Logic.POSITION_MANAGER))
            ? UniswapV3Logic.POSITION_MANAGER.mint(
                IUniswapV3PositionManager.MintParams({
                    token0: position.token0,
                    token1: position.token1,
                    fee: position.fee,
                    tickLower: position.tickLower,
                    tickUpper: position.tickUpper,
                    amount0Desired: balance0,
                    amount1Desired: balance1,
                    amount0Min: 0,
                    amount1Min: 0,
                    recipient: address(this),
                    deadline: block.timestamp
                })
            )
            : SlipstreamLogic.POSITION_MANAGER.mint(
                ICLPositionManager.MintParams({
                    token0: position.token0,
                    token1: position.token1,
                    tickSpacing: position.tickSpacing,
                    tickLower: position.tickLower,
                    tickUpper: position.tickUpper,
                    amount0Desired: balance0,
                    amount1Desired: balance1,
                    amount0Min: 0,
                    amount1Min: 0,
                    recipient: address(this),
                    deadline: block.timestamp,
                    sqrtPriceX96: 0
                })
            );

        // Update balances.
        balance0_ = balance0 - amount0;
        balance1_ = balance1 - amount1;

        // If position is a staked slipstream position, stake the position.
        if (stakedPositionManager != address(0)) {
            SlipstreamLogic.POSITION_MANAGER.approve(stakedPositionManager, newTokenId);
            IStakedSlipstreamAM(stakedPositionManager).mint(newTokenId);
        }
    }
}

// src/rebalancers/Rebalancer.sol
/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

/**
 * @title Permissioned rebalancer for Uniswap V3 and Slipstream Liquidity Positions.
 * @notice The Rebalancer will act as an Asset Manager for Arcadia Accounts.
 * It will allow third parties to trigger the rebalancing functionality for a Liquidity Position in the Account.
 * The owner of an Arcadia Account should set an initiator via setAccountInfo() that will be permisionned to rebalance
 * all Liquidity Positions held in that Account.
 * @dev The contract prevents frontrunning/sandwiching by comparing the actual pool price with a pool price calculated from trusted
 * price feeds (oracles). The tolerance in terms of price deviation is specific to the initiator but limited by a global MAX_TOLERANCE.
 * @dev The contract guarantees a limited slippage with each rebalance by enforcing a minimum amount of liquidity that must be added,
 * based on a hypothetical optimal swap through the pool itself without slippage.
 * This protects the Account owners from incompetent or malicious initiators who route swaps poorly, or try to skim off liquidity from the position.
 */
contract Rebalancer is IActionBase {
    using FixedPointMathLib for uint256;
    using SafeApprove for ERC20;
    using SafeTransferLib for ERC20;
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The maximum lower deviation of the pools actual sqrtPriceX96,
    // The maximum deviation of the actual pool price, in % with 18 decimals precision.
    uint256 internal immutable MAX_TOLERANCE;

    // The maximum fee an initiator can set, with 18 decimals precision.
    uint256 internal immutable MAX_INITIATOR_FEE;

    // The ratio that limits the amount of slippage of the swap, with 18 decimals precision.
    // It is defined as the quotient between the minimal amount of liquidity that must be added,
    // and the amount of liquidity that would be added if the swap was executed through the pool without slippage.
    // MIN_LIQUIDITY_RATIO = minLiquidity / liquidityWithoutSlippage
    uint256 internal immutable MIN_LIQUIDITY_RATIO;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The Account to compound the fees for, used as transient storage.
    address internal account;

    // A mapping from initiator to rebalancing fee.
    mapping(address initiator => InitiatorInfo) internal initiatorInfo;

    // A mapping that sets the approved initiator per account.
    mapping(address account => address initiator) internal accountToInitiator;

    // A mapping that sets a strategy hook per account.
    mapping(address account => address hook) internal strategyHook;

    // A struct with the state of a specific position, only used in memory.
    struct PositionState {
        address pool;
        address token0;
        address token1;
        uint24 fee;
        int24 tickSpacing;
        int24 tickUpper;
        int24 tickLower;
        uint128 liquidity;
        uint160 sqrtRatioLower;
        uint160 sqrtRatioUpper;
        uint256 sqrtPriceX96;
        uint256 lowerBoundSqrtPriceX96;
        uint256 upperBoundSqrtPriceX96;
    }

    // A struct with information for each specific initiator
    struct InitiatorInfo {
        uint64 upperSqrtPriceDeviation;
        uint64 lowerSqrtPriceDeviation;
        uint64 fee;
        uint64 minLiquidityRatio;
    }

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error InitiatorNotValid();
    error InsufficientLiquidity();
    error InvalidValue();
    error NotAnAccount();
    error OnlyAccount();
    error OnlyAccountOwner();
    error OnlyPool();
    error OnlyPositionManager();
    error Reentered();
    error UnbalancedPool();

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event AccountInfoSet(address indexed account, address indexed initiator, address indexed strategyHook);
    event Rebalance(address indexed account, address indexed positionManager, uint256 oldId, uint256 newId);

    /* //////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param maxTolerance The maximum allowed deviation of the actual pool price for any initiator,
     * relative to the price calculated with trusted external prices of both assets, with 18 decimals precision.
     * @param maxInitiatorFee The maximum fee an initiator can set,
     * relative to the ideal amountIn, with 18 decimals precision.
     * @param minLiquidityRatio The ratio of the minimum amount of liquidity that must be minted,
     * relative to the hypothetical amount of liquidity when we rebalance without slippage, with 18 decimals precision.
     */
    constructor(uint256 maxTolerance, uint256 maxInitiatorFee, uint256 minLiquidityRatio) {
        MAX_TOLERANCE = maxTolerance;
        MAX_INITIATOR_FEE = maxInitiatorFee;
        MIN_LIQUIDITY_RATIO = minLiquidityRatio;
    }

    /* ///////////////////////////////////////////////////////////////
                             REBALANCING LOGIC
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Rebalances a UniswapV3 or Slipstream Liquidity Position, owned by an Arcadia Account.
     * @param account_ The Arcadia Account owning the position.
     * @param positionManager The contract address of the Position Manager.
     * @param oldId The oldId of the Liquidity Position to rebalance.
     * @param tickLower The new lower tick to rebalance to.
     * @param tickUpper The new upper tick to rebalance to.
     * @dev When tickLower and tickUpper are equal, ticks will be updated with same tick-spacing as current position
     * and with a balanced, 50/50 ratio around current tick.
     */
    function rebalance(
        address account_,
        address positionManager,
        uint256 oldId,
        int24 tickLower,
        int24 tickUpper,
        bytes calldata swapData
    ) external {
        // If the initiator is set, account_ is an actual Arcadia Account.
        if (account != address(0)) revert Reentered();
        if (accountToInitiator[account_] != msg.sender) revert InitiatorNotValid();

        // Store Account address, used to validate the caller of the executeAction() callback and serves as a reentrancy guard.
        account = account_;

        // Encode data for the flash-action.
        bytes memory actionData =
            ArcadiaLogic._encodeAction(positionManager, oldId, msg.sender, tickLower, tickUpper, swapData);

        // Call flashAction() with this contract as actionTarget.
        IAccount(account_).flashAction(address(this), actionData);

        // Reset account.
        account = address(0);
    }

    /**
     * @notice Callback function called by the Arcadia Account during the flashAction.
     * @param rebalanceData A bytes object containing a struct with the assetData of the position and the address of the initiator.
     * @return depositData A struct with the asset data of the Liquidity Position and with the leftovers after mint, if any.
     * @dev The Liquidity Position is already transferred to this contract before executeAction() is called.
     * @dev When rebalancing we will burn the current Liquidity Position and mint a new one with a new tokenId.
     */
    function executeAction(bytes calldata rebalanceData) external override returns (ActionData memory depositData) {
        // Caller should be the Account, provided as input in rebalance().
        if (msg.sender != account) revert OnlyAccount();

        // Cache the strategy hook.
        address hook = strategyHook[msg.sender];

        // Decode rebalanceData.
        bytes memory swapData;
        address positionManager;
        uint256 oldId;
        uint256 newId;
        PositionState memory position;
        address initiator;
        {
            ActionData memory assetData;
            int24 tickLower;
            int24 tickUpper;
            (assetData, initiator, tickLower, tickUpper, swapData) =
                abi.decode(rebalanceData, (ActionData, address, int24, int24, bytes));
            positionManager = assetData.assets[0];
            oldId = assetData.assetIds[0];

            // Fetch and cache all position related data.
            position = getPositionState(positionManager, oldId, tickLower, tickUpper, initiator);
        }

        // If set, call the strategy hook before the rebalance (view function).
        // This can be used to enforce additional constraints on the rebalance, specific to the Account/Id.
        // Such as:
        // - Directional preferences.
        // - Minimum Cool Down Periods.
        // - Excluding rebalancing of certain positions.
        // - ...
        if (hook != address(0)) {
            IStrategyHook(hook).beforeRebalance(
                msg.sender, positionManager, oldId, position.tickLower, position.tickUpper
            );
        }

        // Check that pool is initially balanced.
        // Prevents sandwiching attacks when swapping and/or adding liquidity.
        if (isPoolUnbalanced(position)) revert UnbalancedPool();

        // Remove liquidity of the position and claim outstanding fees/rewards.
        (uint256 balance0, uint256 balance1, uint256 reward) = BurnLogic._burn(positionManager, oldId, position);

        {
            // Get the rebalance parameters.
            // These are calculated based on a hypothetical swap through the pool, without slippage.
            (uint256 minLiquidity, bool zeroToOne, uint256 amountInitiatorFee, uint256 amountIn, uint256 amountOut) =
            RebalanceLogic._getRebalanceParams(
                initiatorInfo[initiator].minLiquidityRatio,
                position.fee,
                initiatorInfo[initiator].fee,
                position.sqrtPriceX96,
                position.sqrtRatioLower,
                position.sqrtRatioUpper,
                balance0,
                balance1
            );

            // Do the actual swap to rebalance the position.
            // This can be done either directly through the pool, or via a router with custom swap data.
            // For swaps directly through the pool, if slippage is bigger than calculated, the transaction will not immediately revert,
            // but excess slippage will be subtracted from the initiatorFee.
            // For swaps via a router, tokenOut should be the limiting factor when increasing liquidity.
            (balance0, balance1) = SwapLogic._swap(
                swapData,
                positionManager,
                position,
                zeroToOne,
                amountInitiatorFee,
                amountIn,
                amountOut,
                balance0,
                balance1
            );

            // Check that the pool is still balanced after the swap.
            if (isPoolUnbalanced(position)) revert UnbalancedPool();

            // Mint the new liquidity position.
            // We mint with the total available balances of token0 and token1, not subtracting the initiator fee.
            // Leftovers must be in tokenIn, otherwise the total tokenIn balance will be added as liquidity,
            // and the initiator fee will be 0 (but the transaction will not revert).
            uint256 liquidity;
            (newId, liquidity, balance0, balance1) = MintLogic._mint(positionManager, position, balance0, balance1);

            // Check that the actual liquidity of the position is above the minimum threshold.
            // This prevents loss of principal of the liquidity position due to slippage,
            // or malicious initiators who remove liquidity during a custom swap.
            if (liquidity < minLiquidity) revert InsufficientLiquidity();

            // Transfer fee to the initiator.
            (balance0, balance1) = FeeLogic._transfer(
                initiator, zeroToOne, amountInitiatorFee, position.token0, position.token1, balance0, balance1
            );
        }

        // Approve Account to redeposit Liquidity Position and leftovers.
        {
            uint256 count = 1;
            IPositionManager(positionManager).approve(msg.sender, newId);
            if (balance0 > 0) {
                ERC20(position.token0).safeApproveWithRetry(msg.sender, balance0);
                count = 2;
            }
            if (balance1 > 0) {
                ERC20(position.token1).safeApproveWithRetry(msg.sender, balance1);
                ++count;
            }
            if (reward > 0) {
                ERC20(StakedSlipstreamLogic.REWARD_TOKEN).safeApproveWithRetry(msg.sender, reward);
                ++count;
            }

            // Encode deposit data for the flash-action.
            depositData =
                ArcadiaLogic._encodeDeposit(positionManager, newId, position, count, balance0, balance1, reward);
        }

        // If set, call the strategy hook after the rebalance (non view function).
        // Can be used to check additional constraints and persist state changes on the hook.
        if (hook != address(0)) IStrategyHook(hook).afterRebalance(msg.sender, positionManager, oldId, newId);

        emit Rebalance(msg.sender, positionManager, oldId, newId);

        return depositData;
    }

    /* ///////////////////////////////////////////////////////////////
                          SWAP CALLBACK
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Callback after executing a swap via IPool.swap.
     * @param amount0Delta The amount of token0 that was sent (negative) or must be received (positive) by the pool by
     * the end of the swap. If positive, the callback must send that amount of token0 to the pool.
     * @param amount1Delta The amount of token1 that was sent (negative) or must be received (positive) by the pool by
     * the end of the swap. If positive, the callback must send that amount of token1 to the pool.
     * @param data Any data passed by this contract via the IPool.swap() call.
     */
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        // Check that callback came from an actual Uniswap V3 or Slipstream pool.
        (address positionManager, address token0, address token1, uint24 feeOrTickSpacing) =
            abi.decode(data, (address, address, address, uint24));
        if (positionManager == address(UniswapV3Logic.POSITION_MANAGER)) {
            if (UniswapV3Logic._computePoolAddress(token0, token1, feeOrTickSpacing) != msg.sender) revert OnlyPool();
        } else {
            // Logic holds for both Slipstream and staked Slipstream positions.
            if (SlipstreamLogic._computePoolAddress(token0, token1, int24(feeOrTickSpacing)) != msg.sender) {
                revert OnlyPool();
            }
        }

        if (amount0Delta > 0) {
            ERC20(token0).safeTransfer(msg.sender, uint256(amount0Delta));
        } else if (amount1Delta > 0) {
            ERC20(token1).safeTransfer(msg.sender, uint256(amount1Delta));
        }
    }

    /* ///////////////////////////////////////////////////////////////
                    PUBLIC POSITION VIEW FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice returns if the pool of a Liquidity Position is unbalanced.
     * @param position Struct with the position data.
     * @return isPoolUnbalanced_ Bool indicating if the pool is unbalanced.
     */
    function isPoolUnbalanced(PositionState memory position) internal pure returns (bool isPoolUnbalanced_) {
        // Check if current priceX96 of the Pool is within accepted tolerance of the calculated trusted priceX96.
        isPoolUnbalanced_ = position.sqrtPriceX96 <= position.lowerBoundSqrtPriceX96
            || position.sqrtPriceX96 >= position.upperBoundSqrtPriceX96;
    }

    /**
     * @notice Fetches all required position data from external contracts.
     * @param positionManager The contract address of the Position Manager.
     * @param oldId The oldId of the Liquidity Position.
     * @param tickLower The lower tick of the newly minted position.
     * @param tickUpper The upper tick of the newly minted position.
     * @param initiator The address of the initiator.
     * @return position Struct with the position data.
     */
    function getPositionState(
        address positionManager,
        uint256 oldId,
        int24 tickLower,
        int24 tickUpper,
        address initiator
    ) internal view virtual returns (PositionState memory position) {}

    /* ///////////////////////////////////////////////////////////////
                      NATIVE ETH HANDLER
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Receives native ether.
     * @dev Required since the Slipstream Non Fungible Position Manager sends full ether balance to caller
     * on an increaseLiquidity.
     * @dev Funds received can not be reclaimed, the receive only serves as a protection against griefing attacks.
     */
    receive() external payable {
        if (msg.sender != address(SlipstreamLogic.POSITION_MANAGER)) revert OnlyPositionManager();
    }
}

// src/rebalancers/libraries/SlipstreamLogic.sol
/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

library SlipstreamLogic {
    // The Slipstream Factory contract.
    address internal constant CL_FACTORY = 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A;

    // The Slipstream Pool Implementation contract.
    address internal constant POOL_IMPLEMENTATION = 0xeC8E5342B19977B4eF8892e02D8DAEcfa1315831;

    // The Slipstream NonfungiblePositionManager contract.
    ICLPositionManager internal constant POSITION_MANAGER =
        ICLPositionManager(0x827922686190790b37229fd06084350E74485b72);

    /**
     * @notice Computes the contract address of a Slipstream Pool.
     * @param token0 The contract address of token0.
     * @param token1 The contract address of token1.
     * @param tickSpacing The tick spacing of the Pool.
     * @return pool The contract address of the Slipstream Pool.
     */
    function _computePoolAddress(address token0, address token1, int24 tickSpacing)
        internal
        pure
        returns (address pool)
    {
        pool = PoolAddress.computeAddress(POOL_IMPLEMENTATION, CL_FACTORY, token0, token1, tickSpacing);
    }

    /**
     * @notice Fetches Slipstream specific position data from external contracts.
     * @param position Struct with the position data.
     * @param id The id of the Liquidity Position.
     * @return tickCurrent The current tick of the pool.
     * @return tickRange The tick range of the position.
     */
    function _getPositionState(Rebalancer.PositionState memory position, uint256 id)
        internal
        view
        returns (int24 tickCurrent, int24 tickRange)
    {
        // Get data of the Liquidity Position.
        int24 tickLower;
        int24 tickUpper;
        (,, position.token0, position.token1, position.tickSpacing, tickLower, tickUpper, position.liquidity,,,,) =
            POSITION_MANAGER.positions(id);
        tickRange = tickUpper - tickLower;

        // Get data of the Liquidity Pool.
        position.pool = _computePoolAddress(position.token0, position.token1, position.tickSpacing);
        (position.sqrtPriceX96, tickCurrent,,,,) = ICLPool(position.pool).slot0();

        position.fee = ICLPool(position.pool).fee();
    }
}

// src/rebalancers/libraries/SwapLogic.sol
/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

library SwapLogic {
    using SafeApprove for ERC20;

    /**
     * @notice Swaps one token for another to rebalance the Liquidity Position.
     * @param swapData Arbitrary calldata provided by an initiator for the swap.
     * @param positionManager The contract address of the Position Manager.
     * @param position Struct with the position data.
     * @param zeroToOne Bool indicating if token0 has to be swapped to token1 or opposite.
     * @param amountInitiatorFee The amount of initiator fee, in tokenIn.
     * @param amountIn An approximation of the amount of tokenIn, based on the optimal swap through the pool itself without slippage.
     * @param amountOut An approximation of the amount of tokenOut, based on the optimal swap through the pool itself without slippage.
     * @param balance0 The balance of token0 before the swap.
     * @param balance1 The balance of token1 before the swap.
     * @return balance0_ The balance of token0 after the swap.
     * @return balance1_ The balance of token1 after the swap.
     */
    function _swap(
        bytes memory swapData,
        address positionManager,
        Rebalancer.PositionState memory position,
        bool zeroToOne,
        uint256 amountInitiatorFee,
        uint256 amountIn,
        uint256 amountOut,
        uint256 balance0,
        uint256 balance1
    ) internal returns (uint256 balance0_, uint256 balance1_) {
        // Don't do swaps with zero amount.
        if (amountIn == 0) return (balance0, balance1);

        // Do the actual swap to rebalance the position.
        // This can be done either directly through the pool, or via a router with custom swap data.
        if (swapData.length == 0) {
            // Calculate a more accurate amountOut, with slippage.
            amountOut = RebalanceOptimizationMath._getAmountOutWithSlippage(
                zeroToOne,
                position.fee,
                IPool(position.pool).liquidity(),
                uint160(position.sqrtPriceX96),
                position.sqrtRatioLower,
                position.sqrtRatioUpper,
                zeroToOne ? balance0 - amountInitiatorFee : balance0,
                zeroToOne ? balance1 : balance1 - amountInitiatorFee,
                amountIn,
                amountOut
            );
            (balance0_, balance1_) = _swapViaPool(positionManager, position, zeroToOne, amountOut, balance0, balance1);
        } else {
            (balance0_, balance1_) = _swapViaRouter(positionManager, position, zeroToOne, swapData);
        }
    }

    /**
     * @notice Swaps one token for another, directly through the pool itself.
     * @param positionManager The contract address of the Position Manager.
     * @param position Struct with the position data.
     * @param zeroToOne Bool indicating if token0 has to be swapped to token1 or opposite.
     * @param amountOut The amount of tokenOut that must be swapped to.
     * @param balance0 The balance of token0 before the swap.
     * @param balance1 The balance of token1 before the swap.
     * @return balance0_ The balance of token0 after the swap.
     * @return balance1_ The balance of token1 after the swap.
     */
    function _swapViaPool(
        address positionManager,
        Rebalancer.PositionState memory position,
        bool zeroToOne,
        uint256 amountOut,
        uint256 balance0,
        uint256 balance1
    ) internal returns (uint256 balance0_, uint256 balance1_) {
        // Pool should still be balanced (within tolerance boundaries) after the swap.
        uint160 sqrtPriceLimitX96 =
            uint160(zeroToOne ? position.lowerBoundSqrtPriceX96 : position.upperBoundSqrtPriceX96);

        // Encode the swap data.
        bytes memory data = (positionManager == address(UniswapV3Logic.POSITION_MANAGER))
            ? abi.encode(positionManager, position.token0, position.token1, position.fee)
            // Logic holds for both Slipstream and staked Slipstream positions.
            : abi.encode(positionManager, position.token0, position.token1, position.tickSpacing);

        // Do the swap.
        // Callback (external function) must be implemented in the main contract.
        (int256 deltaAmount0, int256 deltaAmount1) =
            IPool(position.pool).swap(address(this), zeroToOne, -int256(amountOut), sqrtPriceLimitX96, data);

        // Check that pool is still balanced.
        // If sqrtPriceLimitX96 is reached before an amountOut of tokenOut is received, the pool is not balanced anymore.
        // By setting the sqrtPriceX96 to sqrtPriceLimitX96, the transaction will revert on the balance check.
        if (amountOut > (zeroToOne ? uint256(-deltaAmount1) : uint256(-deltaAmount0))) {
            position.sqrtPriceX96 = sqrtPriceLimitX96;
        }

        // Update the balances.
        balance0_ = zeroToOne ? balance0 - uint256(deltaAmount0) : balance0 + uint256(-deltaAmount0);
        balance1_ = zeroToOne ? balance1 + uint256(-deltaAmount1) : balance1 - uint256(deltaAmount1);
    }

    /**
     * @notice Swaps one token for another, directly through the pool itself.
     * @param positionManager The contract address of the Position Manager.
     * @param position Struct with the position data.
     * @param zeroToOne Bool indicating if token0 has to be swapped to token1 or opposite.
     * @param swapData Arbitrary calldata provided by an initiator for the swap.
     * @return balance0 The balance of token0 after the swap.
     * @return balance1 The balance of token1 after the swap.
     * @dev Initiator has to route swap in such a way that at least minLiquidity of liquidity is added to the position after the swap.
     * And leftovers must be in tokenIn, otherwise the total tokenIn balance will be added as liquidity,
     * and the initiator fee will be 0 (but the transaction will not revert)
     */
    function _swapViaRouter(
        address positionManager,
        Rebalancer.PositionState memory position,
        bool zeroToOne,
        bytes memory swapData
    ) internal returns (uint256 balance0, uint256 balance1) {
        // Decode the swap data.
        (address router, uint256 amountIn, bytes memory data) = abi.decode(swapData, (address, uint256, bytes));

        // Approve token to swap.
        address tokenToSwap = zeroToOne ? position.token0 : position.token1;
        ERC20(tokenToSwap).safeApproveWithRetry(router, amountIn);

        // Execute arbitrary swap.
        (bool success, bytes memory result) = router.call(data);
        require(success, string(result));

        // Pool should still be balanced (within tolerance boundaries) after the swap.
        // Since the swap went potentially through the pool itself (but does not have to),
        // the sqrtPriceX96 might have moved and brought the pool out of balance.
        // By fetching the sqrtPriceX96, the transaction will revert in that case on the balance check.
        if (positionManager == address(UniswapV3Logic.POSITION_MANAGER)) {
            (position.sqrtPriceX96,,,,,,) = IUniswapV3Pool(position.pool).slot0();
        } else {
            // Logic holds for both Slipstream and staked Slipstream positions.
            (position.sqrtPriceX96,,,,,) = ICLPool(position.pool).slot0();
        }

        // Update the balances.
        balance0 = ERC20(position.token0).balanceOf(address(this));
        balance1 = ERC20(position.token1).balanceOf(address(this));
    }
}

// src/rebalancers/libraries/UniswapV3Logic.sol
/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

library UniswapV3Logic {
    // The Uniswap V3 Factory contract.
    address internal constant UNISWAP_V3_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;

    // The Uniswap V3 NonfungiblePositionManager contract.
    IUniswapV3PositionManager internal constant POSITION_MANAGER =
        IUniswapV3PositionManager(0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1);

    /**
     * @notice Computes the contract address of a Uniswap V3 Pool.
     * @param token0 The contract address of token0.
     * @param token1 The contract address of token1.
     * @param fee The fee of the Pool.
     * @return pool The contract address of the Uniswap V3 Pool.
     */
    function _computePoolAddress(address token0, address token1, uint24 fee) internal pure returns (address pool) {
        pool = PoolAddress.computeAddress(UNISWAP_V3_FACTORY, token0, token1, fee);
    }

    /**
     * @notice Fetches Uniswap V3 specific position data from external contracts.
     * @param position Struct with the position data.
     * @param id The id of the Liquidity Position.
     * @param getTickSpacing Bool indicating if the tick spacing should be fetched.
     * @return tickCurrent The current tick of the pool.
     * @return tickRange The tick range of the position.
     */
    function _getPositionState(Rebalancer.PositionState memory position, uint256 id, bool getTickSpacing)
        internal
        view
        returns (int24 tickCurrent, int24 tickRange)
    {
        // Get data of the Liquidity Position.
        int24 tickLower;
        int24 tickUpper;
        (,, position.token0, position.token1, position.fee, tickLower, tickUpper, position.liquidity,,,,) =
            POSITION_MANAGER.positions(id);
        tickRange = tickUpper - tickLower;

        // Get data of the Liquidity Pool.
        position.pool = _computePoolAddress(position.token0, position.token1, position.fee);
        (position.sqrtPriceX96, tickCurrent,,,,,) = IUniswapV3Pool(position.pool).slot0();

        if (getTickSpacing) position.tickSpacing = IUniswapV3Pool(position.pool).tickSpacing();
    }
}

// src/rebalancers/RebalancerSpot.sol
/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

/**
 * @title Permissioned rebalancer for Uniswap V3 and Slipstream Liquidity Positions.
 * @notice The Rebalancer will act as an Asset Manager for Arcadia Spot Accounts.
 * It will allow third parties to trigger the rebalancing functionality for a Liquidity Position in the Account.
 * The owner of an Arcadia Account should set an initiator via setAccountInfo() that will be permisionned to rebalance
 * all Liquidity Positions held in that Account.
 * @dev The contract prevents frontrunning/sandwiching by comparing the actual pool price with a pool price calculated from a TWAP.
 * The tolerance in terms of price deviation is specific to the initiator but limited by a global MAX_TOLERANCE.
 * @dev The contract guarantees a limited slippage with each rebalance by enforcing a minimum amount of liquidity that must be added,
 * based on a hypothetical optimal swap through the pool itself without slippage.
 * This protects the Account owners from incompetent or malicious initiators who route swaps poorly, or try to skim off liquidity from the position.
 */
contract RebalancerSpot is Rebalancer {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param maxTolerance The maximum allowed deviation of the actual pool price for any initiator,
     * relative to the price calculated with trusted external prices of both assets, with 18 decimals precision.
     * @param maxInitiatorFee The maximum fee an initiator can set,
     * relative to the ideal amountIn, with 18 decimals precision.
     * @param minLiquidityRatio The ratio of the minimum amount of liquidity that must be minted,
     * relative to the hypothetical amount of liquidity when we rebalance without slippage, with 18 decimals precision.
     */
    constructor(uint256 maxTolerance, uint256 maxInitiatorFee, uint256 minLiquidityRatio)
        Rebalancer(maxTolerance, maxInitiatorFee, minLiquidityRatio)
    { }

    /* ///////////////////////////////////////////////////////////////
                    PUBLIC POSITION VIEW FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Fetches all required position data from external contracts.
     * @param positionManager The contract address of the Position Manager.
     * @param oldId The oldId of the Liquidity Position.
     * @param tickLower The lower tick of the newly minted position.
     * @param tickUpper The upper tick of the newly minted position.
     * @param initiator The address of the initiator.
     * @return position Struct with the position data.
     */
    function getPositionState(
        address positionManager,
        uint256 oldId,
        int24 tickLower,
        int24 tickUpper,
        address initiator
    ) internal view override returns (PositionState memory position) {
        // Get data of the Liquidity Position.
        (int24 tickCurrent, int24 tickRange) = positionManager == address(UniswapV3Logic.POSITION_MANAGER)
            ? UniswapV3Logic._getPositionState(position, oldId, tickLower == tickUpper)
            // Logic holds for both Slipstream and staked Slipstream positions.
            : SlipstreamLogic._getPositionState(position, oldId);

        // Store the new ticks for the rebalance
        if (tickLower == tickUpper) {
            // Round current tick down to a tick that is a multiple of the tick spacing (can be initialised).
            // We do not handle the edge cases where the new ticks might exceed MIN_TICK or MAX_TICK.
            // This will result in a revert during the mint, if ever needed a different rebalancer has to be deployed.
            tickCurrent = tickCurrent / position.tickSpacing * position.tickSpacing;
            // For tick ranges that are an even multiple of the tick spacing, we use a symmetric spacing around the current tick.
            // For uneven multiples, the smaller part is below the current tick.
            position.tickLower = tickCurrent - tickRange / (2 * position.tickSpacing) * position.tickSpacing;
            position.tickUpper = position.tickLower + tickRange;
        } else {
            (position.tickLower, position.tickUpper) = (tickLower, tickUpper);
        }
        position.sqrtRatioLower = TickMath.getSqrtPriceAtTick(position.tickLower);
        position.sqrtRatioUpper = TickMath.getSqrtPriceAtTick(position.tickUpper);

        // Calculate the time weighted average tick over 300s.
        // This is to prevent sandwiching attacks when swapping and/or adding liquidity.
        int24 twat = TwapLogic._getTwat(position.pool);
        // Get the time weighted average sqrtPriceX96 over 300s.
        uint256 twaSqrtPriceX96 = TickMath.getSqrtPriceAtTick(twat);

        // Calculate the upper and lower bounds of sqrtPriceX96 for the Pool to be in acceptable balanced state.
        // We do not handle the edge cases where exceed MIN_SQRT_RATIO or MAX_SQRT_RATIO.
        // This will result in a revert during swapViaPool, if ever needed a different rebalancer has to be deployed.
        position.lowerBoundSqrtPriceX96 =
            twaSqrtPriceX96.mulDivDown(initiatorInfo[initiator].lowerSqrtPriceDeviation, 1e18);
        position.upperBoundSqrtPriceX96 =
            twaSqrtPriceX96.mulDivDown(initiatorInfo[initiator].upperSqrtPriceDeviation, 1e18);
    }
}

