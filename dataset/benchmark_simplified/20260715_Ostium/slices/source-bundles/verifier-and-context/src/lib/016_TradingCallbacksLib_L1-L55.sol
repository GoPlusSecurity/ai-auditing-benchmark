// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import '@openzeppelin/contracts/utils/math/SafeCast.sol';
import '@openzeppelin/contracts/utils/math/SignedMath.sol';
import '@openzeppelin/contracts/utils/math/Math.sol';
import '../interfaces/IOstiumTradingStorage.sol';
import '../interfaces/IOstiumPairInfos.sol';
import '../interfaces/IOstiumRegistry.sol';
import '../interfaces/IOstiumVault.sol';
import '../interfaces/IOstiumPairsStorage.sol';
import '../interfaces/IOstiumTradingCallbacks.sol';

library TradingCallbacksLib {
    using SafeCast for uint256;
    using SafeCast for uint192;

    uint256 constant PRECISION_27 = 1e27;
    uint64 constant PRECISION_18 = 1e18;
    uint64 constant PRECISION_10 = 1e10;
    uint32 constant PRECISION_6 = 1e6;
    uint16 constant MAX_GAIN_P = 900; // 900% PnL (10x)
    uint64 constant MAX_DECAY_FACTOR = 3e18; // 18 decimals

    struct PriceImpactResult {
        uint256 priceImpactP;
        uint256 priceAfterImpact;
        bool isDynamic;
    }

    struct TradeValueResult {
        uint256 tradeValue;
        uint256 liqMarginValue;
        int256 rolloverFees;
        int256 fundingFees;
        int256 profitP;
    }

    function _getTradePriceImpact(int192 price, int192 ask, int192 bid, bool isOpen, bool isLong)
        internal
        pure
        returns (uint256 priceImpactP, uint256 priceAfterImpact)
    {
        if (price == 0) {
            return (0, 0);
        }
        bool aboveSpot = (isOpen == isLong);

        int192 usedPrice = aboveSpot ? ask : bid;

        priceImpactP = (SignedMath.abs(price - usedPrice) * PRECISION_18 * 100 / uint192(price));

        return (priceImpactP, uint192(usedPrice));
    }

