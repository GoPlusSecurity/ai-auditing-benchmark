// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// ═══ libraries/FullMath.sol ═══
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


// ═══ libraries/CustomRevert.sol ═══
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


// ═══ libraries/SafeCast.sol ═══
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


// ═══ libraries/BitMath.sol ═══
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


// ═══ libraries/FixedPoint96.sol ═══
/// @title FixedPoint96
/// @notice A library for handling binary fixed point numbers, see https://en.wikipedia.org/wiki/Q_(number_format)
/// @dev Used in SqrtPriceMath.sol
library FixedPoint96 {
    uint8 internal constant RESOLUTION = 96;
    uint256 internal constant Q96 = 0x1000000000000000000000000;
}


// ═══ libraries/TickMath.sol ═══
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


// ═══ v4-periphery/LiquidityAmounts.sol ═══
/// @notice Provides functions for computing liquidity amounts from token amounts and prices
library LiquidityAmounts {
    using SafeCast for uint256;

    /// @notice Computes the amount of liquidity received for a given amount of token0 and price range
    /// @dev Calculates amount0 * (sqrt(upper) * sqrt(lower)) / (sqrt(upper) - sqrt(lower))
    /// @param sqrtPriceAX96 A sqrt price representing the first tick boundary
    /// @param sqrtPriceBX96 A sqrt price representing the second tick boundary
    /// @param amount0 The amount0 being sent in
    /// @return liquidity The amount of returned liquidity
    function getLiquidityForAmount0(uint160 sqrtPriceAX96, uint160 sqrtPriceBX96, uint256 amount0)
        internal
        pure
        returns (uint128 liquidity)
    {
        unchecked {
            if (sqrtPriceAX96 > sqrtPriceBX96) (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);
            uint256 intermediate = FullMath.mulDiv(sqrtPriceAX96, sqrtPriceBX96, FixedPoint96.Q96);
            return FullMath.mulDiv(amount0, intermediate, sqrtPriceBX96 - sqrtPriceAX96).toUint128();
        }
    }

    /// @notice Computes the amount of liquidity received for a given amount of token1 and price range
    /// @dev Calculates amount1 / (sqrt(upper) - sqrt(lower)).
    /// @param sqrtPriceAX96 A sqrt price representing the first tick boundary
    /// @param sqrtPriceBX96 A sqrt price representing the second tick boundary
    /// @param amount1 The amount1 being sent in
    /// @return liquidity The amount of returned liquidity
    function getLiquidityForAmount1(uint160 sqrtPriceAX96, uint160 sqrtPriceBX96, uint256 amount1)
        internal
        pure
        returns (uint128 liquidity)
    {
        unchecked {
            if (sqrtPriceAX96 > sqrtPriceBX96) (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);
            return FullMath.mulDiv(amount1, FixedPoint96.Q96, sqrtPriceBX96 - sqrtPriceAX96).toUint128();
        }
    }

    /// @notice Computes the maximum amount of liquidity received for a given amount of token0, token1, the current
    /// pool prices and the prices at the tick boundaries
    /// @param sqrtPriceX96 A sqrt price representing the current pool prices
    /// @param sqrtPriceAX96 A sqrt price representing the first tick boundary
    /// @param sqrtPriceBX96 A sqrt price representing the second tick boundary
    /// @param amount0 The amount of token0 being sent in
    /// @param amount1 The amount of token1 being sent in
    /// @return liquidity The maximum amount of liquidity received
    function getLiquidityForAmounts(
        uint160 sqrtPriceX96,
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint256 amount0,
        uint256 amount1
    ) internal pure returns (uint128 liquidity) {
        if (sqrtPriceAX96 > sqrtPriceBX96) {
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);
        }

        if (sqrtPriceX96 <= sqrtPriceAX96) {
            liquidity = getLiquidityForAmount0(sqrtPriceAX96, sqrtPriceBX96, amount0);
        } else if (sqrtPriceX96 < sqrtPriceBX96) {
            uint128 liquidity0 = getLiquidityForAmount0(sqrtPriceX96, sqrtPriceBX96, amount0);
            uint128 liquidity1 = getLiquidityForAmount1(sqrtPriceAX96, sqrtPriceX96, amount1);

            liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
        } else {
            liquidity = getLiquidityForAmount1(sqrtPriceAX96, sqrtPriceBX96, amount1);
        }
    }
}


// ═══ types/Currency.sol ═══
type Currency is address;

library CurrencyLibrary {
    Currency public constant ADDRESS_ZERO = Currency.wrap(address(0));
}


// ═══ types/BalanceDelta.sol ═══
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
    /// @notice A BalanceDelta of 0
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


// ═══ types/PoolId.sol ═══
type PoolId is bytes32;

/// @notice Library for computing the ID of a pool
library PoolIdLibrary {
    /// @notice Returns value equal to keccak256(abi.encode(poolKey))
    function toId(PoolKey memory poolKey) internal pure returns (PoolId poolId) {
        assembly ("memory-safe") {
            // 0xa0 represents the total size of the poolKey struct (5 slots of 32 bytes)
            poolId := keccak256(poolKey, 0xa0)
        }
    }
}


// ═══ types/BeforeSwapDelta.sol (type only, for IHooks) ═══
type BeforeSwapDelta is int256;

// ═══ interfaces/IHooks.sol ═══
/// @notice V4 decides whether to invoke specific hooks by inspecting the least significant bits
/// of the address that the hooks contract is deployed to.
/// For example, a hooks contract deployed to address: 0x0000000000000000000000000000000000002400
/// has the lowest bits '10 0100 0000 0000' which would cause the 'before initialize' and 'after add liquidity' hooks to be used.
/// See the Hooks library for the full spec.
/// @dev Should only be callable by the v4 PoolManager.
interface IHooks {
    /// @notice The hook called before the state of a pool is initialized
    /// @param sender The initial msg.sender for the initialize call
    /// @param key The key for the pool being initialized
    /// @param sqrtPriceX96 The sqrt(price) of the pool as a Q64.96
    /// @return bytes4 The function selector for the hook
    function beforeInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96) external returns (bytes4);

    /// @notice The hook called after the state of a pool is initialized
    /// @param sender The initial msg.sender for the initialize call
    /// @param key The key for the pool being initialized
    /// @param sqrtPriceX96 The sqrt(price) of the pool as a Q64.96
    /// @param tick The current tick after the state of a pool is initialized
    /// @return bytes4 The function selector for the hook
    function afterInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96, int24 tick)
        external
        returns (bytes4);

    /// @notice The hook called before liquidity is added
    /// @param sender The initial msg.sender for the add liquidity call
    /// @param key The key for the pool
    /// @param params The parameters for adding liquidity
    /// @param hookData Arbitrary data handed into the PoolManager by the liquidity provider to be passed on to the hook
    /// @return bytes4 The function selector for the hook
    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4);

    /// @notice The hook called after liquidity is added
    /// @param sender The initial msg.sender for the add liquidity call
    /// @param key The key for the pool
    /// @param params The parameters for adding liquidity
    /// @param delta The caller's balance delta after adding liquidity; the sum of principal delta, fees accrued, and hook delta
    /// @param feesAccrued The fees accrued since the last time fees were collected from this position
    /// @param hookData Arbitrary data handed into the PoolManager by the liquidity provider to be passed on to the hook
    /// @return bytes4 The function selector for the hook
    /// @return BalanceDelta The hook's delta in token0 and token1. Positive: the hook is owed/took currency, negative: the hook owes/sent currency
    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external returns (bytes4, BalanceDelta);

    /// @notice The hook called before liquidity is removed
    /// @param sender The initial msg.sender for the remove liquidity call
    /// @param key The key for the pool
    /// @param params The parameters for removing liquidity
    /// @param hookData Arbitrary data handed into the PoolManager by the liquidity provider to be be passed on to the hook
    /// @return bytes4 The function selector for the hook
    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4);

    /// @notice The hook called after liquidity is removed
    /// @param sender The initial msg.sender for the remove liquidity call
    /// @param key The key for the pool
    /// @param params The parameters for removing liquidity
    /// @param delta The caller's balance delta after removing liquidity; the sum of principal delta, fees accrued, and hook delta
    /// @param feesAccrued The fees accrued since the last time fees were collected from this position
    /// @param hookData Arbitrary data handed into the PoolManager by the liquidity provider to be be passed on to the hook
    /// @return bytes4 The function selector for the hook
    /// @return BalanceDelta The hook's delta in token0 and token1. Positive: the hook is owed/took currency, negative: the hook owes/sent currency
    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external returns (bytes4, BalanceDelta);

    /// @notice The hook called before a swap
    /// @param sender The initial msg.sender for the swap call
    /// @param key The key for the pool
    /// @param params The parameters for the swap
    /// @param hookData Arbitrary data handed into the PoolManager by the swapper to be be passed on to the hook
    /// @return bytes4 The function selector for the hook
    /// @return BeforeSwapDelta The hook's delta in specified and unspecified currencies. Positive: the hook is owed/took currency, negative: the hook owes/sent currency
    /// @return uint24 Optionally override the lp fee, only used if three conditions are met: 1. the Pool has a dynamic fee, 2. the value's 2nd highest bit is set (23rd bit, 0x400000), and 3. the value is less than or equal to the maximum fee (1 million)
    function beforeSwap(address sender, PoolKey calldata key, SwapParams calldata params, bytes calldata hookData)
        external
        returns (bytes4, BeforeSwapDelta, uint24);

    /// @notice The hook called after a swap
    /// @param sender The initial msg.sender for the swap call
    /// @param key The key for the pool
    /// @param params The parameters for the swap
    /// @param delta The amount owed to the caller (positive) or owed to the pool (negative)
    /// @param hookData Arbitrary data handed into the PoolManager by the swapper to be be passed on to the hook
    /// @return bytes4 The function selector for the hook
    /// @return int128 The hook's delta in unspecified currency. Positive: the hook is owed/took currency, negative: the hook owes/sent currency
    function afterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external returns (bytes4, int128);

    /// @notice The hook called before donate
    /// @param sender The initial msg.sender for the donate call
    /// @param key The key for the pool
    /// @param amount0 The amount of token0 being donated
    /// @param amount1 The amount of token1 being donated
    /// @param hookData Arbitrary data handed into the PoolManager by the donor to be be passed on to the hook
    /// @return bytes4 The function selector for the hook
    function beforeDonate(
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) external returns (bytes4);

    /// @notice The hook called after donate
    /// @param sender The initial msg.sender for the donate call
    /// @param key The key for the pool
    /// @param amount0 The amount of token0 being donated
    /// @param amount1 The amount of token1 being donated
    /// @param hookData Arbitrary data handed into the PoolManager by the donor to be be passed on to the hook
    /// @return bytes4 The function selector for the hook
    function afterDonate(
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) external returns (bytes4);
}


// ═══ types/PoolKey.sol ═══
using PoolIdLibrary for PoolKey global;

/// @notice Returns the key for identifying a pool
struct PoolKey {
    /// @notice The lower currency of the pool, sorted numerically
    Currency currency0;
    /// @notice The higher currency of the pool, sorted numerically
    Currency currency1;
    /// @notice The pool LP fee, capped at 1_000_000. If the highest bit is 1, the pool has a dynamic fee and must be exactly equal to 0x800000
    uint24 fee;
    /// @notice Ticks that involve positions must be a multiple of tick spacing
    int24 tickSpacing;
    /// @notice The hooks of the pool
    IHooks hooks;
}


// ═══ types/PoolOperation.sol ═══
/// @notice Parameter struct for `ModifyLiquidity` pool operations
struct ModifyLiquidityParams {
    // the lower and upper tick of the position
    int24 tickLower;
    int24 tickUpper;
    // how to modify the liquidity
    int256 liquidityDelta;
    // a value to set if you want unique liquidity positions at the same range
    bytes32 salt;
}

/// @notice Parameter struct for `Swap` pool operations
struct SwapParams {
    /// Whether to swap token0 for token1 or vice versa
    bool zeroForOne;
    /// The desired input amount if negative (exactIn), or the desired output amount if positive (exactOut)
    int256 amountSpecified;
    /// The sqrt price at which, if reached, the swap will stop executing
    uint160 sqrtPriceLimitX96;
}


// ═══ interfaces/IExtsload.sol ═══
/// @notice Interface for functions to access any storage slot in a contract
interface IExtsload {
    /// @notice Called by external contracts to access granular pool state
    /// @param slot Key of slot to sload
    /// @return value The value of the slot as bytes32
    function extsload(bytes32 slot) external view returns (bytes32 value);

    /// @notice Called by external contracts to access granular pool state
    /// @param startSlot Key of slot to start sloading from
    /// @param nSlots Number of slots to load into return value
    /// @return values List of loaded values.
    function extsload(bytes32 startSlot, uint256 nSlots) external view returns (bytes32[] memory values);

    /// @notice Called by external contracts to access sparse pool state
    /// @param slots List of slots to SLOAD from.
    /// @return values List of loaded values.
    function extsload(bytes32[] calldata slots) external view returns (bytes32[] memory values);
}


// ═══ interfaces/IPoolManager.sol (minimal) ═══
interface IPoolManager is IExtsload {
    function unlock(bytes calldata data) external returns (bytes memory);

    function modifyLiquidity(PoolKey memory key, ModifyLiquidityParams memory params, bytes calldata hookData)
        external
        returns (BalanceDelta callerDelta, BalanceDelta feesAccrued);

    function swap(PoolKey memory key, SwapParams memory params, bytes calldata hookData)
        external
        returns (BalanceDelta swapDelta);

    function sync(Currency currency) external;

    function take(Currency currency, address to, uint256 amount) external;

    function settle() external payable returns (uint256 paid);
}


// ═══ libraries/StateLibrary.sol (getSlot0 only) ═══
library StateLibrary {
    bytes32 public constant POOLS_SLOT = bytes32(uint256(6));

    function getSlot0(IPoolManager manager, PoolId poolId)
        internal
        view
        returns (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee)
    {
        bytes32 stateSlot = _getPoolStateSlot(poolId);
        bytes32 data = manager.extsload(stateSlot);
        assembly ("memory-safe") {
            sqrtPriceX96 := and(data, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            tick := signextend(2, shr(160, data))
            protocolFee := and(shr(184, data), 0xFFFFFF)
            lpFee := and(shr(208, data), 0xFFFFFF)
        }
    }

    function _getPoolStateSlot(PoolId poolId) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(PoolId.unwrap(poolId), POOLS_SLOT));
    }
}


// ═══ library/LDF.sol ═══
/// @title  LDF — bonding-curve ↔ Uniswap v4 tick mapping for Uniperp.
/// @notice The bonding curve `realTokens × (V + eth) = K` is realized as N
///         v4 LP positions ("bands"). Band i covers cumulative pool ETH
///         [W·i, W·(i+1)] (W = TICK_WIDTH_ETH) and is seeded with the token
///         slice the curve would sell across that ETH range. All math is
///         deterministic at deploy time.
library LDF {
    uint256 internal constant TOTAL_SUPPLY = 1_000_000 ether; // 1M PERP
    uint256 internal constant VIRTUAL_ETH  = 10 ether;        // virtual reserve V
    uint256 internal constant K            = (TOTAL_SUPPLY * VIRTUAL_ETH) / 1 ether; // 10M (1e18-scaled)
    uint256 internal constant TICK_WIDTH_ETH = 5 ether;       // 5-ETH bands → ≤2.25× price span / band
    int24   internal constant TICK_SPACING   = 60;

    error InvalidBand();

    /// @notice [ethLo, ethHi) cumulative-pool-ETH range covered by band `bandId`.
    function bandEthRange(uint256 bandId) internal pure returns (uint256 ethLo, uint256 ethHi) {
        ethLo = TICK_WIDTH_ETH * bandId;
        ethHi = TICK_WIDTH_ETH * (bandId + 1);
    }

    /// @notice Token allocation for band `bandId`:
    ///         alloc = K·1e18/(V+ethLo) − K·1e18/(V+ethHi). Sum over all bands → TOTAL_SUPPLY.
    function loopAllocForBand(uint256 bandId) internal pure returns (uint256 alloc) {
        uint256 ethLo = TICK_WIDTH_ETH * bandId;
        uint256 ethHi = TICK_WIDTH_ETH * (bandId + 1);
        uint256 remainingLo = FullMath.mulDiv(K, 1e18, VIRTUAL_ETH + ethLo);
        uint256 remainingHi = FullMath.mulDiv(K, 1e18, VIRTUAL_ETH + ethHi);
        alloc = remainingLo - remainingHi;
    }

    /// @notice v4 sqrtPriceX96 at cumulative pool ETH `eth`.
    ///         v4Price = K·1e18 / (V+eth)²  ⟹  sqrtPriceX96 = sqrt(K·1e18)·2^96 / (V+eth).
    function sqrtPriceX96AtEth(uint256 eth) internal pure returns (uint160 sqrtPriceX96) {
        uint256 result = FullMath.mulDiv(sqrt(K * 1e18), 1 << 96, VIRTUAL_ETH + eth);
        require(result <= type(uint160).max, "sqrtPriceOverflow");
        sqrtPriceX96 = uint160(result);
    }

    /// @notice v4 tick range for band `bandId`. Higher pool ETH → lower v4 price
    ///         → lower tick, so tickLower = tick(ethHi), tickUpper = tick(ethLo),
    ///         both aligned to TICK_SPACING.
    function bandToV4Ticks(uint256 bandId) internal pure returns (int24 tickLower, int24 tickUpper) {
        (uint256 ethLo, uint256 ethHi) = bandEthRange(bandId);
        int24 tickHi = TickMath.getTickAtSqrtPrice(sqrtPriceX96AtEth(ethLo));
        int24 tickLo = TickMath.getTickAtSqrtPrice(sqrtPriceX96AtEth(ethHi));
        tickLower = _alignDown(tickLo, TICK_SPACING);
        tickUpper = _alignUp(tickHi, TICK_SPACING);
        if (tickLower >= tickUpper) revert InvalidBand();
    }

    /// @notice L needed to deposit `tokenAmount` token1 single-sided (current ≤ tickLower).
    function liquidityForLoopOnly(int24 tickLower, int24 tickUpper, uint256 tokenAmount)
        internal pure returns (uint128 liquidity)
    {
        return LiquidityAmounts.getLiquidityForAmount1(
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            tokenAmount
        );
    }

    /// @notice L needed to deposit `ethAmount` token0 single-sided (current ≤ tickLower).
    function liquidityForEthOnly(int24 tickLower, int24 tickUpper, uint256 ethAmount)
        internal pure returns (uint128 liquidity)
    {
        return LiquidityAmounts.getLiquidityForAmount0(
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            ethAmount
        );
    }

    /// @notice Inverse of sqrtPriceX96AtEth: cumulative pool ETH implied by a sqrtPrice.
    function ethAtSqrtPrice(uint160 sqrtPriceX96) internal pure returns (uint256 eth) {
        uint256 vPlusEth = FullMath.mulDiv(sqrt(K * 1e18), 1 << 96, sqrtPriceX96);
        eth = vPlusEth > VIRTUAL_ETH ? vPlusEth - VIRTUAL_ETH : 0;
    }

    /// @dev Babylonian integer sqrt.
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) { y = z; z = (x / z + z) / 2; }
    }

    function _alignDown(int24 t, int24 spacing) private pure returns (int24) {
        int24 r = t % spacing;
        if (r < 0) r += spacing;
        return t - r;
    }

    function _alignUp(int24 t, int24 spacing) private pure returns (int24) {
        int24 down = _alignDown(t, spacing);
        return down == t ? t : down + spacing;
    }
}


// ═══ interface IBoostStaking ═══
interface IBoostStaking {
    function notifyReward() external payable;
}


// ═══ interface IBoostToken ═══
/// @notice Minimal ERC20 surface used by BoostHook (TOKEN → PoolManager on sell).
interface IBoostToken {
    function transfer(address to, uint256 amount) external returns (bool);
}


// ═══ contract BoostHook ═══
contract BoostHook {
    using StateLibrary for IPoolManager;

    uint16  public constant MAX_LEVERAGE              = 5;
    uint256 public constant LONG_CAP_BPS              = 4000;   // borrow cap per band: 40% of its capacity
    uint256 public constant BORROW_FEE_BPS            = 100;    // 1% of borrow, at open → stakers
    uint256 public constant SWAP_FEE_BPS              = 100;    // 1% of every direct spot swap → feeRecipient
    uint256 public constant CLOSE_FEE_BPS             = 100;    // 1% of close/liquidation surplus → feeRecipient
    uint256 public constant LIQUIDATION_HEALTH_BPS    = 10_500; // liquidate below 105% health
    uint256 public constant MIN_COLLATERAL_VALUE      = 0.01 ether;
    uint256 public constant NUM_INITIAL_BANDS         = 300;    // 5-ETH bands → covers curveEth 0..1500 (99.3% sold)
    uint256 public constant MAX_BORROW_BANDS          = 5;      // gas cap on the per-open borrow walk
    uint16  public constant MAX_LIQS_PER_SWAP         = 10;
    uint16  public constant MAX_SCAN_PER_SWAP         = 64;
    uint16  public constant MAX_LIQS_PER_BLOCK        = 5;      // bounds cross-swap liquidation cascades in one block
    uint16  public constant OBS_BUFFER_SIZE           = 64;
    uint32  public constant TWAP_SECONDS              = 300;    // liquidation health uses this TWAP window

    // ─── Errors ─────────────────────────────────────────────────────────────
    error PoolMgrOnly();
    error PoolNotInitializedErr();
    error ZeroAddress();
    error Reentrancy();
    error InvalidAction();
    error CollateralBelowMin();
    error InvalidLeverage();
    error InsufficientBorrowCapacity();
    error ImpureBorrow();
    error SlippageExceeded();
    error DeadlineExceeded();
    error PartialFill();
    error TradingNotEnabled();
    error ProtocolPaused();
    error TokenTransferFailed();
    error StakingNotSet();

    IPoolManager public immutable poolManager;
    IBoostToken  public immutable token;

    PoolKey public poolKey;
    bool    public poolInitialized;

    /// @notice Set true only once ALL bands are seeded. Swaps and opens revert
    ///         until then — blocks price discovery against a partially-seeded
    ///         curve if the deploy sequence is broadcast publicly mid-batches.
    bool    public tradingEnabled;

    /// @notice Owner emergency stop. When true, NEW leveraged opens revert.
    ///         Spot trading, closes, and liquidations are never affected.
    bool    public paused;

    /// @dev Receives the 1%-of-swap LP fee (claim via claim()). Hardcoded; not
    ///      exposed as a public getter. Borrow fees go to `staking`, not here.
    address internal constant feeRecipient = 0x98Fb2387eb8B5db1811D6789DE8c1e12546d994D;

    /// @notice V4 tick range + total L + outstanding borrowed-out ETH for a band.
    struct TickBand {
        int24   v4TickLower;
        int24   v4TickUpper;
        uint128 liquidity;
        uint256 borrowedETH;
    }
    mapping(uint256 bandId => TickBand) public bands;

    /// @notice Leveraged-long account. Debt is global — repaid on close into
    ///         whichever fully-passed bands still have outstanding `borrowedETH`
    ///         (nearest-active first). No per-position band tracking.
    struct Position {
        address owner;
        uint256 collateralETH;       // ETH input minus borrow fee
        uint256 debtETH;             // ETH owed back to bands on close
        uint256 holdingTOKEN;        // TOKEN held by hook as position collateral
        uint8   leverage;            // 2..5
        uint128 realizedETHOut;      // lifetime ETH pulled via prior partial closes
    }
    mapping(uint256 positionId => Position) internal _positions;
    /// @notice Per-user list of currently-open position IDs. Entries are
    ///         swap-popped on full close/liquidation, so this stays bounded to
    ///         the user's *open* positions (history lives in `userHistory`).
    mapping(address => uint256[]) public userPositions;
    mapping(uint256 => uint256) internal _userPosIndex;
    uint256 public nextPositionId = 1;

    /// @notice Permanent record of a liquidation. Position structs are wiped on
    ///         liquidation, so this is the only persistent trade history.
    struct ClosedPositionRecord {
        uint64  timestamp;
        uint64  positionId;
        uint8   leverage;
        uint128 collateralETH;
        uint128 amountIn;        // tokens sold
        uint128 amountOut;       // lifetime ETH returned
    }
    mapping(address => ClosedPositionRecord[]) public userHistory;

    uint256[] internal _openIds;
    mapping(uint256 => uint256) internal _openIdIndex;
    uint256 internal _iterCursor;

    uint256 public totalDebtETH;
    uint256 public totalHoldingTOKEN;
    bool    internal _inLiquidation;

    /// @notice Pull-based payouts. ETH owed accrues here; beneficiaries call
    ///         claim(). Prevents a malicious receive() from reverting hook flows.
    mapping(address => uint256) internal _claimable;

    /// @notice REAL ETH the hook holds that couldn't be re-LP'd during a
    ///         close/liquidation. Owner deploys it back via deployReserveToBands().
    ///         Invariant: protocolReserve <= address(this).balance.
    uint256 public protocolReserve;

    /// @notice Realized bad debt — write-off marker, NOT real ETH. Tracks the
    ///         gap between what bands lent out and what closes/liquidations
    ///         recovered. Invariant:
    ///         sum(band.borrowedETH) == totalDebtETH + protocolReserve + totalBadDebtETH.
    uint256 public totalBadDebtETH;

    /// @notice Receives 0.5%-of-borrow fees as ETH rewards. Set once via setStaking().
    IBoostStaking public staking;
    bool public stakingSet;

    /// @notice TWAP ring buffer. Liquidation health uses the TWAP tick, not raw
    ///         spot, so a single-block flash dump can't manufacture liquidations.
    struct Observation {
        uint32 timestamp;
        int56  tickCumulative;
        int24  tick;
        bool   initialized;
    }
    Observation[OBS_BUFFER_SIZE] internal _observations;
    uint16 public obsIndex;

    uint64 internal _lastLiqBlock;
    uint16 internal _liqsThisBlock;

    event PositionOpened(
        uint256 indexed id, address indexed owner,
        uint256 collateralETH, uint256 debtETH, uint256 holdingTOKEN
    );
    event PositionLiquidated(uint256 indexed id, address indexed owner, uint256 ethFromSell, uint256 returnedETH);
    event FeeToStakers(uint256 amount);
    event ProtocolReserveAdded(uint256 amount, uint256 totalReserve);
    event BadDebtRealized(uint256 indexed positionId, uint256 amount, uint256 totalBadDebt);
    event StakingNotifyFailed(uint256 amount);

    uint256 private _locked = 1;
    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }
    modifier onlyPoolManager() { if (msg.sender != address(poolManager)) revert PoolMgrOnly(); _; }

    constructor(IPoolManager pm_, IBoostToken token_) {
        if (address(pm_) == address(0) || address(token_) == address(0)) {
            revert ZeroAddress();
        }
        poolManager = pm_;
        token = token_;
    }

    /// @notice 1% ETH fee on SELL + auto-liquidation scan.
    function afterSwap(address sender, PoolKey calldata key, SwapParams calldata params, BalanceDelta delta, bytes calldata)
        external onlyPoolManager returns (bytes4, int128)
    {
        if (sender == address(this)) return (IHooks.afterSwap.selector, 0);

        // Scan before write: liquidation health must use the TWAP that excludes
        // the just-completed swap, otherwise a flash dump pollutes its own TWAP.
        if (!_inLiquidation) {
            _scanAndLiquidate();
        }
        _writeObservation();

        // Fee skim on SELL (only for exact-input; exact-output rejected in beforeSwap)
        if (params.zeroForOne)              return (IHooks.afterSwap.selector, 0);
        if (params.amountSpecified >= 0)    return (IHooks.afterSwap.selector, 0);

        int128 ethOut = delta.amount0();
        if (ethOut <= 0) return (IHooks.afterSwap.selector, 0);

        uint256 fee = (uint256(uint128(ethOut)) * SWAP_FEE_BPS) / 10000;
        if (fee == 0) return (IHooks.afterSwap.selector, 0);

        // Pull-based: credit fee to feeRecipient
        poolManager.take(key.currency0, address(this), fee);
        _claimable[feeRecipient] += fee;
        return (IHooks.afterSwap.selector, int128(int256(fee)));
    }

    // ─── User entry points ──────────────────────────────────────────────────

    /// @notice Open a leveraged long. `minHoldingOut` is the slippage floor on
    ///         the leveraged-buy output. `deadline` is a unix timestamp.
    function openLong(uint256 leverage, uint256 minHoldingOut, uint256 deadline)
        external
        payable
        nonReentrant
        returns (uint256 positionId, uint256 holdingOut)
    {
        if (block.timestamp > deadline) revert DeadlineExceeded();
        if (!poolInitialized) revert PoolNotInitializedErr();
        if (!tradingEnabled) revert TradingNotEnabled();
        if (paused) revert ProtocolPaused();
        if (!stakingSet) revert StakingNotSet();
        if (leverage < 2 || leverage > MAX_LEVERAGE) revert InvalidLeverage();
        if (msg.value < MIN_COLLATERAL_VALUE) revert CollateralBelowMin();

        uint256 collateral = msg.value;
        uint256 borrowEth  = collateral * (leverage - 1);
        uint256 borrowFee  = (borrowEth * BORROW_FEE_BPS) / 10_000;
        uint256 effectiveCol = collateral - borrowFee;

        // Handler walks fully-passed bands farthest-first, removes ETH-only L
        // from each up to its 40% cap, then swaps `effectiveCol + borrow` → TOKEN.
        bytes memory ret = poolManager.unlock(abi.encode(
            Action.OPEN_LONG,
            abi.encode(borrowEth, effectiveCol, borrowFee)
        ));
        (uint256 actualBorrowed, uint256 swapTokensOut) = abi.decode(ret, (uint256, uint256));

        if (swapTokensOut < minHoldingOut) revert SlippageExceeded();

        positionId = nextPositionId++;
        _positions[positionId] = Position({
            owner:          msg.sender,
            collateralETH:  effectiveCol,
            debtETH:        actualBorrowed,
            holdingTOKEN:   swapTokensOut,
            leverage:       uint8(leverage),
            realizedETHOut: 0
        });
        _userPosIndex[positionId] = userPositions[msg.sender].length;
        userPositions[msg.sender].push(positionId);
        _openIdIndex[positionId] = _openIds.length;
        _openIds.push(positionId);

        totalDebtETH      += actualBorrowed;
        totalHoldingTOKEN += swapTokensOut;
        holdingOut         = swapTokensOut;

        emit PositionOpened(positionId, msg.sender, effectiveCol, actualBorrowed, swapTokensOut);
    }

    // ─── Auto-liquidation ───────────────────────────────────────────────────
    /// @dev Defense layers:
    ///       (A) health uses the TWAP tick (not spot) — a single-block dump
    ///           can't flip a healthy position to liquidatable;
    ///       (B) liquidations per block are capped — bounds any cascade.
    ///      The forced sell itself is uncapped (MAX_SQRT_PRICE − 1, same as a
    ///      user close): a liquidation must fully clear the position in one swap,
    ///      never dribble it out across blocks. A momentary dump below the curve
    ///      is self-correcting via arbitrage; what matters is that the position
    ///      stops accruing bad debt promptly.
    function _scanAndLiquidate() internal {
        uint256 n = _openIds.length;
        if (n == 0) return;

        // If the TWAP buffer isn't warm enough, skip — safer to delay
        // liquidations than to use manipulable spot.
        (int24 twapTick, bool twapOk) = _twapTick(TWAP_SECONDS);
        if (!twapOk) return;
        uint160 healthSqrtP = TickMath.getSqrtPriceAtTick(twapTick);

        if (uint64(block.number) != _lastLiqBlock) {
            _lastLiqBlock = uint64(block.number);
            _liqsThisBlock = 0;
        }
        if (_liqsThisBlock >= MAX_LIQS_PER_BLOCK) return;
        uint256 blockRemaining = MAX_LIQS_PER_BLOCK - _liqsThisBlock;

        // Bound liquidations AND positions scanned per call; cursor advances so
        // the whole set is eventually checked.
        uint256 scanBudget = n < MAX_SCAN_PER_SWAP ? n : MAX_SCAN_PER_SWAP;
        uint256 maxLiq    = scanBudget < MAX_LIQS_PER_SWAP ? scanBudget : MAX_LIQS_PER_SWAP;
        if (maxLiq > blockRemaining) maxLiq = blockRemaining;

        uint256[] memory toLiq = new uint256[](maxLiq);
        uint256 count = 0;
        uint256 cursor = _iterCursor % n;
        uint256 scanned = 0;
        for (uint256 i = 0; i < scanBudget && count < maxLiq; i++) {
            uint256 idx = (cursor + i) % n;
            uint256 posId = _openIds[idx];
            Position storage p = _positions[posId];
            uint256 holdingValueEth = _tokenValueInEth(p.holdingTOKEN, healthSqrtP);
            uint256 healthBps = (holdingValueEth * 10_000) / (p.debtETH == 0 ? 1 : p.debtETH);
            if (healthBps < LIQUIDATION_HEALTH_BPS) toLiq[count++] = posId;
            scanned = i + 1;
        }
        _iterCursor = (cursor + scanned) % (n > 0 ? n : 1);

        if (count == 0) return;

        _inLiquidation = true;
        for (uint256 i = 0; i < count; i++) {
            _liquidateInternal(toLiq[i]);
        }
        _inLiquidation = false;
        _liqsThisBlock += uint16(count);
    }

    function _liquidateInternal(uint256 positionId) internal {
        Position storage pos = _positions[positionId];
        uint256 holding = pos.holdingTOKEN;
        uint256 debt    = pos.debtETH;
        address pOwner = pos.owner;
        // Snapshot before _removePosition wipes the struct.
        uint8   posLeverage      = pos.leverage;
        uint256 posCollateralETH = pos.collateralETH;
        uint128 posRealizedOut   = pos.realizedETHOut;

        totalDebtETH      -= debt;
        totalHoldingTOKEN -= holding;
        _removePosition(positionId);

        // Runs inside afterSwap (already unlocked) — direct PM calls, no recursive
        // unlock. Uncapped sell (MAX_SQRT_PRICE − 1): clear the whole position in
        // one swap. Never reverts on zero output (a toxic position can't DoS the
        // swap that triggers it).
        (uint256 ethFromSell, uint256 actualTokenSold) = _swapTokenForEth(holding, TickMath.MAX_SQRT_PRICE - 1);

        // Pathological edge only (entire curve drained → price floored): any
        // unsold remainder stays in the hook; re-track it so accounting matches.
        uint256 unsoldTokens = holding - actualTokenSold;
        if (unsoldTokens > 0) totalHoldingTOKEN += unsoldTokens;

        // Refill debt-repayment across borrowed bands (nearest-active first).
        uint256 forRefill = debt < ethFromSell ? debt : ethFromSell;
        uint256 spent = forRefill > 0 ? _refillAcrossBands(forRefill) : 0;

        // Real ETH that couldn't be re-LP'd right now → reserve.
        uint256 unabsorbedRefill = forRefill > spent ? forRefill - spent : 0;
        if (unabsorbedRefill > 0) {
            protocolReserve += unabsorbedRefill;
            emit ProtocolReserveAdded(unabsorbedRefill, protocolReserve);
        }

        // ethFromSell < debt → realized loss; bands carry unbacked borrowedETH.
        uint256 badDebt = debt > ethFromSell ? debt - ethFromSell : 0;
        if (badDebt > 0) {
            totalBadDebtETH += badDebt;
            emit BadDebtRealized(positionId, badDebt, totalBadDebtETH);
        }

        // Surplus → user (rare in liquidations), minus the 1% close fee on the surplus → stakers.
        uint256 returnedETH = ethFromSell > debt ? ethFromSell - debt : 0;
        if (returnedETH > 0) {
            uint256 closeFee = (returnedETH * CLOSE_FEE_BPS) / 10_000;
            if (closeFee > 0) {
                _routeFeeToStakers(closeFee);
                returnedETH -= closeFee;
            }
            _claimable[pOwner] += returnedETH;
        }

        uint256 lifetimeOut = uint256(posRealizedOut) + returnedETH;
        _recordHistory(pOwner, positionId, posLeverage, posCollateralETH, actualTokenSold, lifetimeOut);
        emit PositionLiquidated(positionId, pOwner, ethFromSell, returnedETH);
    }

    // ─── openLong → poolManager.unlock callback (PoolManager-only, not user API) ─
    enum Action { OPEN_LONG }

    function unlockCallback(bytes calldata data) external onlyPoolManager returns (bytes memory) {
        (Action action, bytes memory payload) = abi.decode(data, (Action, bytes));
        if (action != Action.OPEN_LONG) revert InvalidAction();
        return _handleOpenLong(payload);
    }

    function _handleOpenLong(bytes memory payload) internal returns (bytes memory) {
        (uint256 borrowEth, uint256 effectiveCol, uint256 borrowFee) =
            abi.decode(payload, (uint256, uint256, uint256));

        (, int24 currentTick,,) = poolManager.getSlot0(_poolId());

        // Borrow walk: fully-passed bands farthest-first, ETH-only single-sided
        // removal from each (so modifyLiquidity returns zero token1 — asserted).
        // The active band is skipped (`v4TickLower <= currentTick`). Per-band
        // cap = 40% × TICK_WIDTH_ETH of cumulative outstanding.
        uint256 capPerBand = (LDF.TICK_WIDTH_ETH * LONG_CAP_BPS) / 10_000;
        // modifyLiquidity rounds down ~1 wei per band, so the walk lands a few
        // wei short of borrowEth. `dustTol` (1 gwei) is both the loop stop
        // condition and the acceptance margin below — a residual ≤ this counts
        // as satisfied.
        //
        // `minBandTake` is a SEPARATE, much smaller threshold: skip a band whose
        // remaining headroom is below it (a sub-`minBandTake` removal would round
        // `a0` to 0 → ImpureBorrow; it's also not worth a band slot). Crucially
        // it's tiny enough that even if ALL NUM_INITIAL_BANDS bands were skipped,
        // the wasted capacity (≤ NUM_INITIAL_BANDS × minBandTake = 3e6 wei) stays
        // far below `dustTol` — so no distribution of band `borrowedETH` values,
        // however the partial-refill arithmetic lands them, can ever make a
        // legitimate open spuriously revert. (1e4 is ~1000× above the single-
        // digit-wei zone where the removal rounds to 0.)
        uint256 dustTol     = 1 gwei;
        uint256 minBandTake = 1e4;
        uint256 remaining = borrowEth;
        uint256 totalFreedETH;
        uint256 slotsUsed;

        for (uint256 bandId = 0; bandId < NUM_INITIAL_BANDS && remaining > dustTol; bandId++) {
            if (slotsUsed >= MAX_BORROW_BANDS) break;
            TickBand storage band = bands[bandId];
            if (band.liquidity == 0) continue;
            if (band.v4TickLower <= currentTick) continue;

            uint256 alreadyOwed = band.borrowedETH;
            if (alreadyOwed >= capPerBand) continue;
            uint256 avail = capPerBand - alreadyOwed;
            uint256 take  = remaining < avail ? remaining : avail;
            if (take < minBandTake) continue; // band ~full — too little to bother

            uint128 lToRemove = LDF.liquidityForEthOnly(band.v4TickLower, band.v4TickUpper, take);
            if (lToRemove == 0 || lToRemove > band.liquidity) continue;

            (BalanceDelta remDelta,) = poolManager.modifyLiquidity(
                poolKey,
                ModifyLiquidityParams({
                    tickLower: band.v4TickLower,
                    tickUpper: band.v4TickUpper,
                    liquidityDelta: -int256(uint256(lToRemove)),
                    salt: bytes32(0)
                }),
                ""
            );
            int128 a0 = remDelta.amount0();
            int128 a1 = remDelta.amount1();
            if (a0 <= 0 || a1 != 0) revert ImpureBorrow();
            uint256 freed = uint256(uint128(a0));
            poolManager.take(CurrencyLibrary.ADDRESS_ZERO, address(this), freed);

            band.liquidity   -= lToRemove;
            band.borrowedETH += freed;
            totalFreedETH    += freed;
            remaining = remaining > freed ? remaining - freed : 0;
            slotsUsed++;
        }

        if (totalFreedETH + dustTol < borrowEth) revert InsufficientBorrowCapacity();

        // Leveraged swap. Must fully consume swapInput — refunding unspent input
        // would leak borrowed band-ETH to the user while debt stays on the books.
        uint256 swapInput = effectiveCol + totalFreedETH;
        (uint256 swapTokensOut, uint256 swapEthSpent) = _swapEthForToken(swapInput);
        if (swapEthSpent < swapInput) revert PartialFill();

        _routeFeeToStakers(borrowFee); // 1% origination → stakers (fallback if bricked)

        return abi.encode(totalFreedETH, swapTokensOut);
    }

    function _currentTick() internal view returns (int24) {
        (, int24 t,,) = poolManager.getSlot0(_poolId());
        return t;
    }

    /// @dev Send `amount` ETH to the staking contract as a reward. If staking is
    ///      bricked, fall back to the LP fee address — never revert the caller.
    function _routeFeeToStakers(uint256 amount) internal {
        if (amount == 0) return;
        try staking.notifyReward{value: amount}() {
            emit FeeToStakers(amount);
        } catch {
            _claimable[feeRecipient] += amount;
            emit StakingNotifyFailed(amount);
        }
    }

    // ─── TWAP observation machinery ─────────────────────────────────────────

    /// @dev Append a new observation. Called from afterSwap. Bandwidth is
    ///      1 observation/second max — multiple swaps in the same block
    ///      collapse to one entry.
    function _writeObservation() internal {
        uint32 nowTs = uint32(block.timestamp);
        Observation memory last = _observations[obsIndex];

        if (last.initialized && last.timestamp == nowTs) {
            return; // already written this second
        }

        int24 curTick = _currentTick();
        int56 newCum;
        if (last.initialized) {
            // Tick was held constant at `last.tick` over [last.timestamp, nowTs].
            int56 delta = int56(last.tick) * int56(uint56(nowTs - last.timestamp));
            newCum = last.tickCumulative + delta;
        }

        uint16 nextIdx = uint16((uint256(obsIndex) + 1) % OBS_BUFFER_SIZE);
        _observations[nextIdx] = Observation({
            timestamp:      nowTs,
            tickCumulative: newCum,
            tick:           curTick,
            initialized:    true
        });
        obsIndex = nextIdx;
    }

    /// @dev TWAP tick over the past `secondsAgo`. Returns ok=false if the
    ///      buffer doesn't have enough history (safe fallback: caller skips
    ///      whatever action depended on it — e.g., liquidation).
    function _twapTick(uint32 secondsAgo) internal view returns (int24 avgTick, bool ok) {
        Observation memory current = _observations[obsIndex];
        if (!current.initialized) return (0, false);

        uint32 endTime = current.timestamp;
        if (endTime < secondsAgo) return (0, false);
        uint32 target = endTime - secondsAgo;

        // Walk backward through ring until we find an obs at-or-before `target`.
        Observation memory past;
        bool found;
        for (uint256 i = 1; i < OBS_BUFFER_SIZE; ++i) {
            uint256 idx = (uint256(obsIndex) + OBS_BUFFER_SIZE - i) % OBS_BUFFER_SIZE;
            Observation memory o = _observations[idx];
            if (!o.initialized) break;
            if (o.timestamp <= target) {
                past = o;
                found = true;
                break;
            }
        }
        if (!found) return (0, false); // buffer doesn't reach back far enough

        uint32 elapsed = endTime - past.timestamp;
        if (elapsed == 0) return (current.tick, true); // shouldn't happen but defensive

        int56 cumDiff = current.tickCumulative - past.tickCumulative;
        avgTick = int24(cumDiff / int56(uint56(elapsed)));
        ok = true;
    }

    // ─── Internal helpers ───────────────────────────────────────────────────

    /// @dev ETH→TOKEN swap. Settles the actual amount0 owed; never reverts on
    ///      zero output — caller handles partial/zero fills.
    function _swapEthForToken(uint256 ethIn)
        internal
        returns (uint256 tokensOut, uint256 actualEthSpent)
    {
        if (ethIn == 0) return (0, 0);
        BalanceDelta d = poolManager.swap(
            poolKey,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -int256(ethIn),
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            ""
        );
        int128 ethDelta = d.amount0();
        int128 tokDelta = d.amount1();

        if (ethDelta < 0) {
            actualEthSpent = uint256(uint128(-ethDelta));
            poolManager.settle{value: actualEthSpent}();
        }
        if (tokDelta > 0) {
            tokensOut = uint256(uint128(tokDelta));
            poolManager.take(poolKey.currency1, address(this), tokensOut);
        }
    }

    /// @dev TOKEN→ETH swap. Never reverts on zero output (a toxic position can't
    ///      DoS the swap that triggers its liquidation). `sqrtPriceLimitX96`
    ///      caps the post-swap price: MAX-1 = "no limit" (user closes),
    ///      TWAP-derived bound = liquidations (anti-sandwich).
    function _swapTokenForEth(uint256 tokenIn, uint160 sqrtPriceLimitX96)
        internal
        returns (uint256 ethOut, uint256 actualTokenSold)
    {
        if (tokenIn == 0) return (0, 0);
        BalanceDelta d = poolManager.swap(
            poolKey,
            SwapParams({
                zeroForOne: false,
                amountSpecified: -int256(tokenIn),
                sqrtPriceLimitX96: sqrtPriceLimitX96
            }),
            ""
        );
        int128 tokDelta = d.amount1();
        int128 ethDelta = d.amount0();

        if (tokDelta < 0) {
            actualTokenSold = uint256(uint128(-tokDelta));
            poolManager.sync(poolKey.currency1);
            if (!token.transfer(address(poolManager), actualTokenSold)) revert TokenTransferFailed();
            poolManager.settle();
        }
        if (ethDelta > 0) {
            ethOut = uint256(uint128(ethDelta));
            poolManager.take(CurrencyLibrary.ADDRESS_ZERO, address(this), ethOut);
        }
    }

    /// @notice Re-LP `budget` ETH across fully-passed bands with outstanding
    ///         `borrowedETH`, nearest-active first. Returns ETH actually placed.
    function _refillAcrossBands(uint256 budget) internal returns (uint256 totalSpent) {
        if (budget == 0) return 0;
        (, int24 currentTick,,) = poolManager.getSlot0(_poolId());

        uint256 remaining = budget;
        for (uint256 i = NUM_INITIAL_BANDS; i > 0 && remaining > 0; i--) {
            uint256 bandId = i - 1;
            TickBand storage band = bands[bandId];
            if (band.borrowedETH == 0) continue;
            if (band.v4TickLower <= currentTick) continue; // not fully-passed

            uint256 owed = band.borrowedETH;
            uint256 put  = remaining < owed ? remaining : owed;

            uint128 lToAdd = LDF.liquidityForEthOnly(band.v4TickLower, band.v4TickUpper, put);
            if (lToAdd == 0) continue;

            (BalanceDelta lpDelta,) = poolManager.modifyLiquidity(
                poolKey,
                ModifyLiquidityParams({
                    tickLower: band.v4TickLower,
                    tickUpper: band.v4TickUpper,
                    liquidityDelta: int256(uint256(lToAdd)),
                    salt: bytes32(0)
                }),
                ""
            );
            int128 owed0 = lpDelta.amount0();
            if (owed0 < 0) {
                uint256 spent = uint256(uint128(-owed0));
                poolManager.settle{value: spent}();
                band.liquidity += lToAdd;
                if (band.borrowedETH >= spent) band.borrowedETH -= spent;
                else band.borrowedETH = 0;
                if (remaining >= spent) remaining -= spent;
                else remaining = 0;
                totalSpent += spent;
            }
        }
    }

    function _removePosition(uint256 id) internal {
        address pOwner = _positions[id].owner;

        // swap-pop from the global open list
        uint256 idx = _openIdIndex[id];
        uint256 last = _openIds.length - 1;
        if (idx != last) {
            uint256 lastId = _openIds[last];
            _openIds[idx] = lastId;
            _openIdIndex[lastId] = idx;
        }
        _openIds.pop();
        delete _openIdIndex[id];

        // swap-pop from the owner's open list
        uint256[] storage up = userPositions[pOwner];
        uint256 uIdx = _userPosIndex[id];
        uint256 uLast = up.length - 1;
        if (uIdx != uLast) {
            uint256 lastUid = up[uLast];
            up[uIdx] = lastUid;
            _userPosIndex[lastUid] = uIdx;
        }
        up.pop();
        delete _userPosIndex[id];

        delete _positions[id];
    }

    /// @dev Append a permanent close/liquidation record. PnL = amountOut - collateralETH.
    function _recordHistory(
        address user,
        uint256 positionId,
        uint8 leverage,
        uint256 collateralETH,
        uint256 amountIn,
        uint256 amountOut
    ) internal {
        userHistory[user].push(ClosedPositionRecord({
            timestamp:     uint64(block.timestamp),
            positionId:    uint64(positionId),
            leverage:      leverage,
            collateralETH: uint128(collateralETH),
            amountIn:      uint128(amountIn),
            amountOut:     uint128(amountOut)
        }));
    }

    /// @dev TOKEN value in ETH at given sqrtPriceX96, computed safely without
    ///      overflowing on near-MAX sqrtP values. Two-step FullMath approach.
    function _tokenValueInEth(uint256 tokenAmount, uint160 sqrtPriceX96) internal pure returns (uint256) {
        // ethValue = tokenAmount × (2^96 / sqrtP) × (2^96 / sqrtP)
        uint256 step1 = FullMath.mulDiv(tokenAmount, 1 << 96, uint256(sqrtPriceX96));
        return FullMath.mulDiv(step1, 1 << 96, uint256(sqrtPriceX96));
    }

    function _poolId() internal view returns (PoolId) {
        return PoolIdLibrary.toId(poolKey);
    }
}
