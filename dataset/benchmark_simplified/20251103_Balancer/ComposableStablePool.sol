// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

// -----------------------------
// Inlined dependencies (flattened)
// -----------------------------

// BalancerErrors.sol (subset: _require/_revert + Errors codes used by math)
// solhint-disable
library Helper {
    function _require(bool condition, uint256 errorCode) internal pure {
        if (!condition) _revert(errorCode);
    }

    function _revert(uint256 errorCode) internal pure {
        _revert(errorCode, 0x42414c); // "BAL"
    }

    function _revert(uint256 errorCode, bytes3 prefix) internal pure {
        uint256 prefixUint = uint256(uint24(prefix));
        assembly {
            let units := add(mod(errorCode, 10), 0x30)
            errorCode := div(errorCode, 10)
            let tenths := add(mod(errorCode, 10), 0x30)
            errorCode := div(errorCode, 10)
            let hundreds := add(mod(errorCode, 10), 0x30)

            let formattedPrefix := shl(24, add(0x23, shl(8, prefixUint)))
            let revertReason := shl(
                200,
                add(formattedPrefix, add(add(units, shl(8, tenths)), shl(16, hundreds)))
            )

            mstore(0x0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
            mstore(0x04, 0x0000000000000000000000000000000000000000000000000000000000000020)
            mstore(0x24, 7)
            mstore(0x44, revertReason)
            revert(0, 100)
        }
    }
}

library Errors {
    // Math
    uint256 internal constant ADD_OVERFLOW = 0;
    uint256 internal constant SUB_OVERFLOW = 1;
    uint256 internal constant MUL_OVERFLOW = 3;
    uint256 internal constant ZERO_DIVISION = 4;
    uint256 internal constant DIV_INTERNAL = 5;

    // Pools (Stable)
    uint256 internal constant STABLE_INVARIANT_DIDNT_CONVERGE = 321;
    uint256 internal constant STABLE_GET_BALANCE_DIDNT_CONVERGE = 322;
}

// Math.sol (inlined)
library Math {
    function abs(int256 a) internal pure returns (uint256) {
        return a > 0 ? uint256(a) : uint256(-a);
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        Helper._require(c >= a, Errors.ADD_OVERFLOW);
        return c;
    }

    function add(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a + b;
        Helper._require((b >= 0 && c >= a) || (b < 0 && c < a), Errors.ADD_OVERFLOW);
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        Helper._require(b <= a, Errors.SUB_OVERFLOW);
        return a - b;
    }

    function sub(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a - b;
        Helper._require((b >= 0 && c <= a) || (b < 0 && c > a), Errors.SUB_OVERFLOW);
        return c;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a * b;
        Helper._require(a == 0 || c / a == b, Errors.MUL_OVERFLOW);
        return c;
    }

    function divDown(uint256 a, uint256 b) internal pure returns (uint256) {
        Helper._require(b != 0, Errors.ZERO_DIVISION);
        return a / b;
    }

    function divUp(uint256 a, uint256 b) internal pure returns (uint256) {
        Helper._require(b != 0, Errors.ZERO_DIVISION);
        if (a == 0) return 0;
        return 1 + (a - 1) / b;
    }
}

// FixedPoint.sol (minimal inlined subset used by StableMath)
library FixedPoint {
    uint256 internal constant ONE = 1e18;

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        Helper._require(c >= a, Errors.ADD_OVERFLOW);
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        Helper._require(b <= a, Errors.SUB_OVERFLOW);
        return a - b;
    }

    function mulDown(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 product = a * b;
        Helper._require(a == 0 || product / a == b, Errors.MUL_OVERFLOW);
        return product / ONE;
    }

    function mulUp(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 product = a * b;
        Helper._require(a == 0 || product / a == b, Errors.MUL_OVERFLOW);
        if (product == 0) return 0;
        return ((product - 1) / ONE) + 1;
    }

    function divDown(uint256 a, uint256 b) internal pure returns (uint256) {
        Helper._require(b != 0, Errors.ZERO_DIVISION);
        if (a == 0) return 0;
        uint256 aInflated = a * ONE;
        Helper._require(aInflated / a == ONE, Errors.DIV_INTERNAL);
        return aInflated / b;
    }

    function divUp(uint256 a, uint256 b) internal pure returns (uint256) {
        Helper._require(b != 0, Errors.ZERO_DIVISION);
        if (a == 0) return 0;
        uint256 aInflated = a * ONE;
        Helper._require(aInflated / a == ONE, Errors.DIV_INTERNAL);
        return ((aInflated - 1) / b) + 1;
    }

    function complement(uint256 x) internal pure returns (uint256) {
        return (x < ONE) ? (ONE - x) : 0;
    }
}

// StableMath.sol (inlined)
// solhint-disable private-vars-leading-underscore, var-name-mixedcase
library StableMath {
    using FixedPoint for uint256;

    uint256 internal constant _MIN_AMP = 1;
    uint256 internal constant _MAX_AMP = 5000;
    uint256 internal constant _AMP_PRECISION = 1e3;

    uint256 internal constant _MAX_STABLE_TOKENS = 5;

    function _calculateInvariant(uint256 amplificationParameter, uint256[] memory balances)
        internal
        pure
        returns (uint256)
    {
        uint256 sum = 0;
        uint256 numTokens = balances.length;
        for (uint256 i = 0; i < numTokens; i++) {
            sum = sum.add(balances[i]);
        }
        if (sum == 0) {
            return 0;
        }

        uint256 prevInvariant;
        uint256 invariant = sum;
        uint256 ampTimesTotal = amplificationParameter * numTokens;

        for (uint256 i = 0; i < 255; i++) {
            uint256 D_P = invariant;
            for (uint256 j = 0; j < numTokens; j++) {
                D_P = Math.divDown(Math.mul(D_P, invariant), Math.mul(balances[j], numTokens));
            }

            prevInvariant = invariant;

            invariant = Math.divDown(
                Math.mul(
                    (Math.divDown(Math.mul(ampTimesTotal, sum), _AMP_PRECISION).add(Math.mul(D_P, numTokens))),
                    invariant
                ),
                (Math.divDown(Math.mul((ampTimesTotal - _AMP_PRECISION), invariant), _AMP_PRECISION).add(
                    Math.mul((numTokens + 1), D_P)
                ))
            );

            if (invariant > prevInvariant) {
                if (invariant - prevInvariant <= 1) {
                    return invariant;
                }
            } else if (prevInvariant - invariant <= 1) {
                return invariant;
            }
        }

        Helper._revert(Errors.STABLE_INVARIANT_DIDNT_CONVERGE);
        return 0;
    }

    function _calcOutGivenIn(
        uint256 amplificationParameter,
        uint256[] memory balances,
        uint256 tokenIndexIn,
        uint256 tokenIndexOut,
        uint256 tokenAmountIn,
        uint256 invariant
    ) internal pure returns (uint256) {
        balances[tokenIndexIn] = balances[tokenIndexIn].add(tokenAmountIn);

        uint256 finalBalanceOut = _getTokenBalanceGivenInvariantAndAllOtherBalances(
            amplificationParameter,
            balances,
            invariant,
            tokenIndexOut
        );

        balances[tokenIndexIn] = balances[tokenIndexIn] - tokenAmountIn;

        return balances[tokenIndexOut].sub(finalBalanceOut).sub(1);
    }

    function _calcInGivenOut(
        uint256 amplificationParameter,
        uint256[] memory balances,
        uint256 tokenIndexIn,
        uint256 tokenIndexOut,
        uint256 tokenAmountOut,
        uint256 invariant
    ) internal pure returns (uint256) {
        balances[tokenIndexOut] = balances[tokenIndexOut].sub(tokenAmountOut);

        uint256 finalBalanceIn = _getTokenBalanceGivenInvariantAndAllOtherBalances(
            amplificationParameter,
            balances,
            invariant,
            tokenIndexIn
        );

        balances[tokenIndexOut] = balances[tokenIndexOut] + tokenAmountOut;

        return finalBalanceIn.sub(balances[tokenIndexIn]).add(1);
    }

    function _calcBptOutGivenExactTokensIn(
        uint256 amp,
        uint256[] memory balances,
        uint256[] memory amountsIn,
        uint256 bptTotalSupply,
        uint256 currentInvariant,
        uint256 swapFeePercentage
    ) internal pure returns (uint256) {
        uint256 sumBalances = 0;
        for (uint256 i = 0; i < balances.length; i++) {
            sumBalances = sumBalances.add(balances[i]);
        }

        uint256[] memory balanceRatiosWithFee = new uint256[](amountsIn.length);
        uint256 invariantRatioWithFees = 0;
        for (uint256 i = 0; i < balances.length; i++) {
            uint256 currentWeight = balances[i].divDown(sumBalances);
            balanceRatiosWithFee[i] = balances[i].add(amountsIn[i]).divDown(balances[i]);
            invariantRatioWithFees = invariantRatioWithFees.add(balanceRatiosWithFee[i].mulDown(currentWeight));
        }

        uint256[] memory newBalances = new uint256[](balances.length);
        for (uint256 i = 0; i < balances.length; i++) {
            uint256 amountInWithoutFee;
            if (balanceRatiosWithFee[i] > invariantRatioWithFees) {
                uint256 nonTaxableAmount = balances[i].mulDown(invariantRatioWithFees.sub(FixedPoint.ONE));
                uint256 taxableAmount = amountsIn[i].sub(nonTaxableAmount);
                amountInWithoutFee = nonTaxableAmount.add(taxableAmount.mulDown(FixedPoint.ONE - swapFeePercentage));
            } else {
                amountInWithoutFee = amountsIn[i];
            }

            newBalances[i] = balances[i].add(amountInWithoutFee);
        }

        uint256 newInvariant = _calculateInvariant(amp, newBalances);
        uint256 invariantRatio = newInvariant.divDown(currentInvariant);

        if (invariantRatio > FixedPoint.ONE) {
            return bptTotalSupply.mulDown(invariantRatio - FixedPoint.ONE);
        } else {
            return 0;
        }
    }

    function _calcTokenInGivenExactBptOut(
        uint256 amp,
        uint256[] memory balances,
        uint256 tokenIndex,
        uint256 bptAmountOut,
        uint256 bptTotalSupply,
        uint256 currentInvariant,
        uint256 swapFeePercentage
    ) internal pure returns (uint256) {
        uint256 newInvariant = bptTotalSupply.add(bptAmountOut).divUp(bptTotalSupply).mulUp(currentInvariant);

        uint256 newBalanceTokenIndex = _getTokenBalanceGivenInvariantAndAllOtherBalances(
            amp,
            balances,
            newInvariant,
            tokenIndex
        );
        uint256 amountInWithoutFee = newBalanceTokenIndex.sub(balances[tokenIndex]);

        uint256 sumBalances = 0;
        for (uint256 i = 0; i < balances.length; i++) {
            sumBalances = sumBalances.add(balances[i]);
        }

        uint256 currentWeight = balances[tokenIndex].divDown(sumBalances);
        uint256 taxablePercentage = currentWeight.complement();
        uint256 taxableAmount = amountInWithoutFee.mulUp(taxablePercentage);
        uint256 nonTaxableAmount = amountInWithoutFee.sub(taxableAmount);

        return nonTaxableAmount.add(taxableAmount.divUp(FixedPoint.ONE - swapFeePercentage));
    }

    function _calcBptInGivenExactTokensOut(
        uint256 amp,
        uint256[] memory balances,
        uint256[] memory amountsOut,
        uint256 bptTotalSupply,
        uint256 currentInvariant,
        uint256 swapFeePercentage
    ) internal pure returns (uint256) {
        uint256 sumBalances = 0;
        for (uint256 i = 0; i < balances.length; i++) {
            sumBalances = sumBalances.add(balances[i]);
        }

        uint256[] memory balanceRatiosWithoutFee = new uint256[](amountsOut.length);
        uint256 invariantRatioWithoutFees = 0;
        for (uint256 i = 0; i < balances.length; i++) {
            uint256 currentWeight = balances[i].divUp(sumBalances);
            balanceRatiosWithoutFee[i] = balances[i].sub(amountsOut[i]).divUp(balances[i]);
            invariantRatioWithoutFees = invariantRatioWithoutFees.add(balanceRatiosWithoutFee[i].mulUp(currentWeight));
        }

        uint256[] memory newBalances = new uint256[](balances.length);
        for (uint256 i = 0; i < balances.length; i++) {
            uint256 amountOutWithFee;
            if (invariantRatioWithoutFees > balanceRatiosWithoutFee[i]) {
                uint256 nonTaxableAmount = balances[i].mulDown(invariantRatioWithoutFees.complement());
                uint256 taxableAmount = amountsOut[i].sub(nonTaxableAmount);
                amountOutWithFee = nonTaxableAmount.add(taxableAmount.divUp(FixedPoint.ONE - swapFeePercentage));
            } else {
                amountOutWithFee = amountsOut[i];
            }

            newBalances[i] = balances[i].sub(amountOutWithFee);
        }

        uint256 newInvariant = _calculateInvariant(amp, newBalances);
        uint256 invariantRatio = newInvariant.divDown(currentInvariant);

        return bptTotalSupply.mulUp(invariantRatio.complement());
    }

    function _calcTokenOutGivenExactBptIn(
        uint256 amp,
        uint256[] memory balances,
        uint256 tokenIndex,
        uint256 bptAmountIn,
        uint256 bptTotalSupply,
        uint256 currentInvariant,
        uint256 swapFeePercentage
    ) internal pure returns (uint256) {
        uint256 newInvariant = bptTotalSupply.sub(bptAmountIn).divUp(bptTotalSupply).mulUp(currentInvariant);

        uint256 newBalanceTokenIndex = _getTokenBalanceGivenInvariantAndAllOtherBalances(
            amp,
            balances,
            newInvariant,
            tokenIndex
        );
        uint256 amountOutWithoutFee = balances[tokenIndex].sub(newBalanceTokenIndex);

        uint256 sumBalances = 0;
        for (uint256 i = 0; i < balances.length; i++) {
            sumBalances = sumBalances.add(balances[i]);
        }

        uint256 currentWeight = balances[tokenIndex].divDown(sumBalances);
        uint256 taxablePercentage = currentWeight.complement();
        uint256 taxableAmount = amountOutWithoutFee.mulUp(taxablePercentage);
        uint256 nonTaxableAmount = amountOutWithoutFee.sub(taxableAmount);

        return nonTaxableAmount.add(taxableAmount.mulDown(FixedPoint.ONE - swapFeePercentage));
    }

    function _getTokenBalanceGivenInvariantAndAllOtherBalances(
        uint256 amplificationParameter,
        uint256[] memory balances,
        uint256 invariant,
        uint256 tokenIndex
    ) internal pure returns (uint256) {
        uint256 ampTimesTotal = amplificationParameter * balances.length;
        uint256 sum = balances[0];
        uint256 P_D = balances[0] * balances.length;
        for (uint256 j = 1; j < balances.length; j++) {
            P_D = Math.divDown(Math.mul(Math.mul(P_D, balances[j]), balances.length), invariant);
            sum = sum.add(balances[j]);
        }
        sum = sum - balances[tokenIndex];

        uint256 inv2 = Math.mul(invariant, invariant);
        uint256 c = Math.mul(
            Math.mul(Math.divUp(inv2, Math.mul(ampTimesTotal, P_D)), _AMP_PRECISION),
            balances[tokenIndex]
        );
        uint256 b = sum.add(Math.mul(Math.divDown(invariant, ampTimesTotal), _AMP_PRECISION));

        uint256 prevTokenBalance = 0;
        uint256 tokenBalance = Math.divUp(inv2.add(c), invariant.add(b));

        for (uint256 i = 0; i < 255; i++) {
            prevTokenBalance = tokenBalance;

            tokenBalance = Math.divUp(
                Math.mul(tokenBalance, tokenBalance).add(c),
                Math.mul(tokenBalance, 2).add(b).sub(invariant)
            );

            if (tokenBalance > prevTokenBalance) {
                if (tokenBalance - prevTokenBalance <= 1) {
                    return tokenBalance;
                }
            } else if (prevTokenBalance - tokenBalance <= 1) {
                return tokenBalance;
            }
        }

        Helper._revert(Errors.STABLE_GET_BALANCE_DIDNT_CONVERGE);
        return 0;
    }
}

interface IERC20Minimal {
    function decimals() external view returns (uint8);
}

/**
 * @dev Swap-only minimal contract: keeps `onSwap` and only the functions it calls.
 *      This is intended for auditing `onSwap` math and control-flow, not for production deployment.
 */
contract ComposableStablePool {
    // -----------------------------
    // Minimal external types
    // -----------------------------

    enum SwapKind {
        GIVEN_IN,
        GIVEN_OUT
    }

    struct SwapRequest {
        SwapKind kind;
        IERC20Minimal tokenIn;
        IERC20Minimal tokenOut;
        uint256 amount;
        // The remaining fields exist in Balancer's SwapRequest, but are unused by this swap-only contract.
        bytes32 poolId;
        uint256 lastChangeBlock;
        address from;
        address to;
        bytes userData;
    }

    // -----------------------------
    // Constants / state used by onSwap
    // -----------------------------

    uint256 private constant _ONE = 1e18;

    // Fixed-point swap fee percentage (1e18 = 100%).
    uint256 private immutable _swapFeePercentage;

    // Packed amplification interpolation state (same layout as Balancer's StablePoolAmplification).
    bytes32 private immutable _packedAmp;

    // Registered tokens include BPT (this contract) as one of the tokens. `bptIndex` points to BPT.
    IERC20Minimal[] private _tokens;
    uint256 private immutable _bptIndex;

    // Scaling factors per registered token (18-decimal normalization).
    uint256[] private _scalingFactors;

    // Virtual supply inputs: `totalSupply` is needed for BPT swap math.
    uint256 private immutable _totalSupply;

    constructor(
        IERC20Minimal[] memory registeredTokens,
        uint256 bptIndex,
        uint256[] memory scalingFactors,
        uint256 amplificationParameter,
        uint256 swapFeePercentage,
        uint256 totalSupply_
    ) {
        require(registeredTokens.length >= 3, "MIN_TOKENS");
        require(bptIndex < registeredTokens.length, "BPT_INDEX_OOB");
        require(scalingFactors.length == registeredTokens.length, "SCALING_LEN");

        _tokens = registeredTokens;
        _bptIndex = bptIndex;
        _scalingFactors = scalingFactors;

        require(amplificationParameter >= StableMath._MIN_AMP && amplificationParameter <= StableMath._MAX_AMP, "AMP");
        uint256 amp = amplificationParameter * StableMath._AMP_PRECISION;
        // Store constant amp (no interpolation) for audit usage.
        // Layout: [ end time | start time | end value | start value ] (4x uint64)
        uint256 t = block.timestamp;
        _packedAmp =
            _encodeUint64(amp, 0) |
            _encodeUint64(amp, 64) |
            _encodeUint64(t, 128) |
            _encodeUint64(t, 192);

        require(swapFeePercentage <= 1e18, "FEE");
        _swapFeePercentage = swapFeePercentage;
        _totalSupply = totalSupply_;
    }

    // -----------------------------
    // External: onSwap
    // -----------------------------

    function onSwap(
        SwapRequest memory swapRequest,
        uint256[] memory balances,
        uint256 indexIn,
        uint256 indexOut
    ) external view returns (uint256) {
        _requireStr(indexIn < _tokens.length && indexOut < _tokens.length && indexIn != indexOut, "INDEX");
        _requireStr(balances.length == _tokens.length, "BAL_LEN");

        if (swapRequest.kind == SwapKind.GIVEN_IN) {
            return _swapGivenIn(swapRequest, balances, indexIn, indexOut);
        } else {
            return _swapGivenOut(swapRequest, balances, indexIn, indexOut);
        }
    }

    // -----------------------------
    // Swap path (only functions used by onSwap)
    // -----------------------------

    function _swapGivenIn(
        SwapRequest memory swapRequest,
        uint256[] memory balances,
        uint256 indexIn,
        uint256 indexOut
    ) private view returns (uint256) {
        // Subtract swap fee before scaling (same pattern as BaseGeneralPool).
        swapRequest.amount = _subtractSwapFeeAmount(swapRequest.amount);

        _upscaleArray(balances, _scalingFactors);
        swapRequest.amount = _upscale(swapRequest.amount, _scalingFactors[indexIn]);

        uint256 amountOut = _isBptSwap(indexIn, indexOut)
            ? _onSwapWithBpt(true, swapRequest.amount, balances, indexIn, indexOut)
            : _onSwapRegular(true, swapRequest.amount, balances, indexIn, indexOut);

        return _downscaleDown(amountOut, _scalingFactors[indexOut]);
    }

    function _swapGivenOut(
        SwapRequest memory swapRequest,
        uint256[] memory balances,
        uint256 indexIn,
        uint256 indexOut
    ) private view returns (uint256) {
        _upscaleArray(balances, _scalingFactors);
        swapRequest.amount = _upscale(swapRequest.amount, _scalingFactors[indexOut]);

        uint256 amountIn = _isBptSwap(indexIn, indexOut)
            ? _onSwapWithBpt(false, swapRequest.amount, balances, indexIn, indexOut)
            : _onSwapRegular(false, swapRequest.amount, balances, indexIn, indexOut);

        amountIn = _downscaleUp(amountIn, _scalingFactors[indexIn]);
        return _addSwapFeeAmount(amountIn);
    }

    function _isBptSwap(uint256 indexIn, uint256 indexOut) private view returns (bool) {
        return indexIn == _bptIndex || indexOut == _bptIndex;
    }

    function _onSwapRegular(
        bool isGivenIn,
        uint256 amountGiven,
        uint256[] memory registeredBalances,
        uint256 registeredIndexIn,
        uint256 registeredIndexOut
    ) private view returns (uint256) {
        uint256[] memory balances = _dropBptItem(registeredBalances);
        uint256 indexIn = _skipBptIndex(registeredIndexIn);
        uint256 indexOut = _skipBptIndex(registeredIndexOut);

        uint256 amp = _getAmp();
        uint256 invariant = StableMath._calculateInvariant(amp, balances);

        if (isGivenIn) {
            return StableMath._calcOutGivenIn(amp, balances, indexIn, indexOut, amountGiven, invariant);
        } else {
            return StableMath._calcInGivenOut(amp, balances, indexIn, indexOut, amountGiven, invariant);
        }
    }

    // BPT swap path: simplified (no protocol fee minting / join-exit invariant caching).
    function _onSwapWithBpt(
        bool isGivenIn,
        uint256 amount,
        uint256[] memory registeredBalances,
        uint256 registeredIndexIn,
        uint256 registeredIndexOut
    ) private view returns (uint256) {
        uint256 amp = _getAmp();

        (uint256 virtualSupply, uint256[] memory balances) = _dropBptItemFromBalances(registeredBalances);
        uint256 invariant = StableMath._calculateInvariant(amp, balances);

        if (registeredIndexOut == _bptIndex) {
            // token -> BPT (join swap)
            return isGivenIn
                ? _joinSwapExactTokenInForBptOut(amount, balances, _skipBptIndex(registeredIndexIn), amp, virtualSupply, invariant)
                : _joinSwapExactBptOutForTokenIn(amount, balances, _skipBptIndex(registeredIndexIn), amp, virtualSupply, invariant);
        } else {
            // BPT -> token (exit swap)
            return isGivenIn
                ? _exitSwapExactBptInForTokenOut(amount, balances, _skipBptIndex(registeredIndexOut), amp, virtualSupply, invariant)
                : _exitSwapExactTokenOutForBptIn(amount, balances, _skipBptIndex(registeredIndexOut), amp, virtualSupply, invariant);
        }
    }

    function _joinSwapExactTokenInForBptOut(
        uint256 amountIn,
        uint256[] memory balances,
        uint256 indexIn,
        uint256 amp,
        uint256 supply,
        uint256 invariant
    ) private view returns (uint256) {
        uint256[] memory amountsIn = new uint256[](balances.length);
        amountsIn[indexIn] = amountIn;
        return StableMath._calcBptOutGivenExactTokensIn(amp, balances, amountsIn, supply, invariant, _swapFeePercentage);
    }

    function _joinSwapExactBptOutForTokenIn(
        uint256 bptOut,
        uint256[] memory balances,
        uint256 indexIn,
        uint256 amp,
        uint256 supply,
        uint256 invariant
    ) private view returns (uint256) {
        return StableMath._calcTokenInGivenExactBptOut(amp, balances, indexIn, bptOut, supply, invariant, _swapFeePercentage);
    }

    function _exitSwapExactBptInForTokenOut(
        uint256 bptIn,
        uint256[] memory balances,
        uint256 indexOut,
        uint256 amp,
        uint256 supply,
        uint256 invariant
    ) private view returns (uint256) {
        return StableMath._calcTokenOutGivenExactBptIn(amp, balances, indexOut, bptIn, supply, invariant, _swapFeePercentage);
    }

    function _exitSwapExactTokenOutForBptIn(
        uint256 amountOut,
        uint256[] memory balances,
        uint256 indexOut,
        uint256 amp,
        uint256 supply,
        uint256 invariant
    ) private view returns (uint256) {
        uint256[] memory amountsOut = new uint256[](balances.length);
        amountsOut[indexOut] = amountOut;
        return StableMath._calcBptInGivenExactTokensOut(amp, balances, amountsOut, supply, invariant, _swapFeePercentage);
    }

    // -----------------------------
    // Minimal shared helpers
    // -----------------------------

    function _getAmp() private view returns (uint256) {
        // This contract stores constant amp, so just read start value.
        return _decodeUint64(_packedAmp, 0);
    }

    function _dropBptItem(uint256[] memory amounts) private view returns (uint256[] memory) {
        uint256[] memory amountsWithoutBpt = new uint256[](amounts.length - 1);
        for (uint256 i = 0; i < amountsWithoutBpt.length; i++) {
            amountsWithoutBpt[i] = amounts[i < _bptIndex ? i : i + 1];
        }
        return amountsWithoutBpt;
    }

    function _dropBptItemFromBalances(uint256[] memory registeredBalances)
        private
        view
        returns (uint256, uint256[] memory)
    {
        // For audit convenience, we use a fixed total supply provided at deployment time.
        uint256 bptBalance = registeredBalances[_bptIndex];
        uint256 virtualSupply = _totalSupply - bptBalance;
        return (virtualSupply, _dropBptItem(registeredBalances));
    }

    function _skipBptIndex(uint256 index) private view returns (uint256) {
        _requireStr(index != _bptIndex, "BPT_INDEX");
        return index < _bptIndex ? index : index - 1;
    }

    function _upscaleArray(uint256[] memory amounts, uint256[] memory scalingFactors) private pure {
        for (uint256 i = 0; i < amounts.length; ++i) {
            amounts[i] = _upscale(amounts[i], scalingFactors[i]);
        }
    }

    function _upscale(uint256 amount, uint256 scalingFactor) internal pure returns (uint256) {
        // Upscale rounding wouldn't necessarily always go in the same direction: in a swap for example the balance of
        // token in should be rounded up, and that of token out rounded down. This is the only place where we round in
        // the same direction for all amounts, as the impact of this rounding is expected to be minimal (and there's no
        // rounding error unless `_scalingFactor()` is overriden).
        return FixedPoint.mulDown(amount, scalingFactor);
    }


    function _downscaleDown(uint256 amount, uint256 scalingFactor) internal pure returns (uint256) {
        return FixedPoint.divDown(amount, scalingFactor);
    }

    function _downscaleUp(uint256 amount, uint256 scalingFactor) private pure returns (uint256) {
        // ceil(amount * 1e18 / scalingFactor)
        uint256 numerator = amount * _ONE;
        return numerator == 0 ? 0 : ((numerator - 1) / scalingFactor) + 1;
    }

    function _subtractSwapFeeAmount(uint256 amount) private view returns (uint256) {
        // amount * (1 - fee)
        uint256 complement = _ONE - _swapFeePercentage;
        return (amount * complement) / _ONE;
    }

    function _addSwapFeeAmount(uint256 amount) private view returns (uint256) {
        // amount / (1 - fee), rounding up
        uint256 complement = _ONE - _swapFeePercentage;
        require(complement != 0, "FEE_100");
        return amount == 0 ? 0 : ((amount * _ONE - 1) / complement) + 1;
    }

    function _encodeUint64(uint256 value, uint256 offset) private pure returns (bytes32) {
        require(value < 2**64, "U64");
        return bytes32(value << offset);
    }

    function _decodeUint64(bytes32 data, uint256 offset) private pure returns (uint256) {
        return uint256(data >> offset) & ((1 << 64) - 1);
    }

    function _requireStr(bool ok, string memory reason) private pure {
        if (!ok) revert(reason);
    }
}

