// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.19;

import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "./AggregatorV3Interface.sol";
import {MErc20Storage, MTokenInterface, MErc20Interface} from "../MTokenInterfaces.sol";
import {EIP20Interface} from "../EIP20Interface.sol";
import {IChainlinkOracle} from "../interfaces/IChainlinkOracle.sol";
import {IOEVWrapperFeed} from "./IOEVWrapperFeed.sol";

/**
 * @title ChainlinkOEVWrapper
 * @notice A wrapper for Chainlink price feeds that allows early updates for liquidation
 * @dev This contract implements the AggregatorV3Interface and adds OEV (Oracle Extractable Value) functionality
 */
contract ChainlinkOEVWrapper is
    Ownable,
    AggregatorV3Interface,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    /// @notice The maximum basis points for the fee multiplier
    uint16 public constant MAX_BPS = 10000;

    /// @notice Price mantissa decimals (used by ChainlinkOracle)
    uint8 private constant PRICE_MANTISSA_DECIMALS = 18;

    /// @notice The ChainlinkOracle contract
    IChainlinkOracle public immutable chainlinkOracle;

    /// @notice The Chainlink price feed this proxy forwards to
    AggregatorV3Interface public priceFeed;

    /// @notice The address that will receive the OEV fees
    address public feeRecipient;

    /// @notice The fee multiplier (in bps) for the OEV fees, to be paid to the liquidator
    uint16 public liquidatorFeeBps;

    /// @notice The last cached round id
    uint256 public cachedRoundId;

    /// @notice The max round delay
    uint256 public maxRoundDelay;

    /// @notice The max decrements
    uint256 public maxDecrements;

    /// @notice Emitted when the fee recipient is changed
    event FeeRecipientChanged(address oldFeeRecipient, address newFeeRecipient);

    /// @notice Emitted when the fee multiplier is changed
    event LiquidatorFeeBpsChanged(
        uint16 oldLiquidatorFeeBps,
        uint16 newLiquidatorFeeBps
    );

    /// @notice Emitted when the max round delay is changed
    event MaxRoundDelayChanged(
        uint256 oldMaxRoundDelay,
        uint256 newMaxRoundDelay
    );

    /// @notice Emitted when the max decrements is changed
    event MaxDecrementsChanged(
        uint256 oldMaxDecrements,
        uint256 newMaxDecrements
    );

    /// @notice Emitted when the price is updated early and liquidated
    event PriceUpdatedEarlyAndLiquidated(
        address indexed borrower,
        uint256 repayAmount,
        address mTokenCollateral,
        address mTokenLoan,
        uint256 protocolFee,
        uint256 liquidatorFee
    );

    /// @notice Emitted when tokens are recovered from the contract
    event TokenRecovered(
        address indexed tokenAddress,
        address indexed to,
        uint256 amount
    );

    /**
     * @notice Contract constructor
     * @param _priceFeed Address of the Chainlink price feed to forward calls to
     * @param _owner Address that will own this contract
     * @param _liquidatorFeeBps The liquidator fee BPS for the OEV fees
     * @param _maxRoundDelay The max round delay
     * @param _maxDecrements The max decrements
     */
    constructor(
        address _priceFeed,
        address _owner,
        address _chainlinkOracle,
        address _feeRecipient,
        uint16 _liquidatorFeeBps,
        uint256 _maxRoundDelay,
        uint256 _maxDecrements
    ) {
        require(
            _priceFeed != address(0),
            "ChainlinkOEVWrapper: price feed cannot be zero address"
        );
        require(
            _owner != address(0),
            "ChainlinkOEVWrapper: owner cannot be zero address"
        );
        require(
            _liquidatorFeeBps <= MAX_BPS,
            "ChainlinkOEVWrapper: liquidator fee cannot be greater than MAX_BPS"
        );
        require(
            _maxRoundDelay > 0,
            "ChainlinkOEVWrapper: max round delay cannot be zero"
        );
        require(
            _maxDecrements > 0,
            "ChainlinkOEVWrapper: max decrements cannot be zero"
        );
        require(
            _chainlinkOracle != address(0),
            "ChainlinkOEVWrapper: chainlink oracle cannot be zero address"
        );
        require(
            _feeRecipient != address(0),
            "ChainlinkOEVWrapper: fee recipient cannot be zero address"
        );

        priceFeed = AggregatorV3Interface(_priceFeed);
        liquidatorFeeBps = _liquidatorFeeBps;
        cachedRoundId = priceFeed.latestRound();
        maxRoundDelay = _maxRoundDelay;
        maxDecrements = _maxDecrements;
        chainlinkOracle = IChainlinkOracle(_chainlinkOracle);
        feeRecipient = _feeRecipient;

        _transferOwnership(_owner);
    }

    /**
     * @notice Returns the number of decimals in the price feed
     * @return The number of decimals
     */
    function decimals() external view override returns (uint8) {
        return priceFeed.decimals();
    }

    /**
     * @notice Returns a description of the price feed
     * @return The description string
     */
    function description() external view override returns (string memory) {
        return priceFeed.description();
    }

    /**
     * @notice Returns the version number of the price feed
     * @return The version number
     */
    function version() external view override returns (uint256) {
        return priceFeed.version();
    }

    /**
     * @notice Returns data for a specific round
     * @param _roundId The round ID to retrieve data for
     * @return roundId The round ID
     * @return answer The price reported in this round
     * @return startedAt The timestamp when the round started
     * @return updatedAt The timestamp when the round was updated
     * @return answeredInRound The round ID in which the answer was computed
     */
    function getRoundData(
        uint80 _roundId
    )
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = priceFeed
            .getRoundData(_roundId);
        _validateRoundData(roundId, answer, updatedAt, answeredInRound);
    }

    /**
     * @notice Returns data from the latest round, with OEV protection mechanism
     * @dev If the latest round hasn't been paid for (via updatePriceEarlyAndLiquidate) and is recent,
     *      this function will return data from a previous round instead
     * @return roundId The round ID
     * @return answer The latest price
     * @return startedAt The timestamp when the round started
     * @return updatedAt The timestamp when the round was updated
     * @return answeredInRound The round ID in which the answer was computed
     */
    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = priceFeed
            .latestRoundData();

        // The default behavior is to delay the price update unless someone has paid for the current round.
        // If the current round is not too old (maxRoundDelay seconds) and hasn't been paid for,
        // attempt to find the most recent valid round by checking previous rounds
        if (
            roundId != cachedRoundId &&
            block.timestamp < updatedAt + maxRoundDelay
        ) {
            // start from the previous round
            uint256 currentRoundId = roundId - 1;

            for (uint256 i = 0; i < maxDecrements && currentRoundId > 0; i++) {
                try priceFeed.getRoundData(uint80(currentRoundId)) returns (
                    uint80 r,
                    int256 a,
                    uint256 s,
                    uint256 u,
                    uint80 ar
                ) {
                    // previous round data found, update the round data
                    roundId = r;
                    answer = a;
                    startedAt = s;
                    updatedAt = u;
                    answeredInRound = ar;
                    break;
                } catch {
                    // previous round data not found, continue to the next decrement
                    currentRoundId--;
                }
            }
        }
        _validateRoundData(roundId, answer, updatedAt, answeredInRound);
    }

