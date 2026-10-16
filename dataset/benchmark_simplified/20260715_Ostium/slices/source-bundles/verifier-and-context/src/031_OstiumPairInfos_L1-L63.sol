// SPDX-License-Identifier: MIT
import '@openzeppelin/contracts/utils/math/SignedMath.sol';
import '@openzeppelin/contracts/utils/math/Math.sol';
import '@openzeppelin/contracts/utils/math/SafeCast.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';

import './lib/ChainUtils.sol';
import './interfaces/IOstiumRegistry.sol';
import './interfaces/IOstiumPairInfos.sol';
import './interfaces/IOstiumTradingStorage.sol';
import './interfaces/IOstiumOpenPnl.sol';

pragma solidity ^0.8.24;

contract OstiumPairInfos is IOstiumPairInfos, Initializable {
    using SafeCast for uint256;
    using SafeCast for int256;
    using SafeCast for uint32;
    using SignedMath for int256;
    using SignedMath for int64;
    using Math for uint256;

    IOstiumRegistry public registry;
    address public manager;

    uint64 constant PRECISION_18 = 1e18; // 18 decimals
    uint64 constant MAX_FUNDING_FEE = 95129375951; // 1000% annum, PRECISION_18
    uint64 constant MAX_ROLLOVER_FEE_PER_BLOCK = 28538812785; // 300% annum, PRECISION_18
    uint64 constant MAX_FR_SPRING_FACTOR = PRECISION_18; // PRECISION_2
    uint64 constant PADE_ERROR_THRESHOLD = 793231258909201900; // PRECISION_18
    uint64 constant POWERTWO_APPROX_THRESHOLD = 6906000000000000000; // PRECISION_18

    uint32 constant PRECISION_6 = 1e6; // 6 decimals
    uint32 constant PRECISION_4 = 1e4;
    uint32 constant MAX_FEEP = 10000000; // 10%, PRECISION_6,
    uint64 constant MAX_BROKER_PREMIUM_PER_BLOCK = 951293760; // 10% annum, PRECISION_18

    uint16 constant MAX_USAGE_THRESHOLDP = 10000; // 100%, PRECISION_2
    uint16 constant MAX_MAKER_LEVERAGE = 10000; // PRECISION_2
    uint16 constant MAX_HILL_SCALE = 250; // PRECISION_2

    uint8 constant PRECISION_2 = 1e2; // 2 decimals
    uint8 constant MAX_LIQ_MARGIN_THRESHOLD_P = 50;

    // Dynamic spread parameter limits
    uint256 constant MAX_NET_VOL_THRESHOLD = 10_000_000_000e18; // PRECISION_18 // 10 Billion
    uint128 constant MIN_DECAY_RATE = 1e14; // PRECISION_18
    uint128 constant MAX_DECAY_RATE = PRECISION_18; // 1 with 18 decimals
    uint256 constant MAX_PRICE_IMPACT_K = 1e21; // PRECISION_27 // 1e-6

    uint8 public liqMarginThresholdP; // e.g., set to 25 (25%)
    uint8 public maxNegativePnlOnOpenP; // (%)

    mapping(uint16 pairIndex => PairOpeningFees) public pairOpeningFees;
    mapping(uint16 pairIndex => PairFundingFeesV2) public pairFundingFees;
    mapping(uint16 pairIndex => PairRolloverFees) public pairRolloverFeesV1;
    mapping(address trader => mapping(uint16 pairIndex => mapping(uint8 tradeIndex => TradeInitialAccFees))) public
        tradeInitialAccFees;
    mapping(uint16 pairIndex => PairRolloverFeesV2) public pairRolloverFeesV2;
    mapping(uint16 pairIndex => DynamicSpreadParams) public pairDynamicSpreadParams;
    mapping(uint16 pairIndex => DynamicSpreadState) public pairDynamicSpreadState;

    constructor() {
