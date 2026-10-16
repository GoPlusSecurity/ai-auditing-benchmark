// SPDX-License-Identifier: MIT
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/math/Math.sol';
import '@openzeppelin/contracts/utils/math/SafeCast.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';

import './interfaces/IOstiumTradingStorage.sol';
import './interfaces/IOstiumPairInfos.sol';
import './interfaces/IOstiumRegistry.sol';
import './interfaces/IOstiumTradingCallbacks.sol';
import './interfaces/IOstiumPairsStorage.sol';

import './interfaces/IOstiumOpenPnl.sol';
import './lib/TradingCallbacksLib.sol';

pragma solidity ^0.8.24;

contract OstiumTradingCallbacks is IOstiumTradingCallbacks, Initializable {
    using Math for uint256;
    using SafeCast for uint256;
    using SafeCast for uint192;

    // Contracts (constant)
    IOstiumRegistry public registry;

    // Params (constant)
    uint64 constant PRECISION_18 = 1e18;
    uint32 constant PRECISION_6 = 1e6;

    // State
    uint8 public maxSl_P; // How much % from the open price the stop loss can be set
    bool public isPaused; // Prevent opening new trades
    bool public isDone; // Prevent any interaction with the contract

    constructor() {
        _disableInitializers();
    }

    function initialize(IOstiumRegistry _registry) external initializer {
        if (address(_registry) == address(0)) {
            revert WrongParams();
        }

        registry = _registry;
        _setMaxSl_P(85);
    }

    // Modifiers
    modifier onlyGov() {
        isGov();
        _;
    }

    modifier onlyManager() {
        isManager();
        _;
    }

    modifier notDone() {
        isNotDone();
        _;
    }

    modifier onlyTrading() {
        isTrading();
        _;
    }

    function isGov() private view {
        if (msg.sender != registry.gov()) {
            revert NotGov(msg.sender);
        }
    }

    function isManager() private view {
        if (msg.sender != registry.manager()) {
            revert NotManager(msg.sender);
        }
    }

    function isPriceUpKeep(uint16 pairIndex) private view {
        string memory priceUpkeepType =
            IOstiumPairsStorage(registry.getContractAddress('pairsStorage')).oracle(pairIndex);
        if (msg.sender != registry.getContractAddress(bytes32(abi.encodePacked(priceUpkeepType, 'PriceUpkeep')))) {
            revert NotPriceUpKeep(msg.sender);
        }
    }

    function isDayTradeClosed(uint16 pairIndex, uint256 leverage, bool isDayTradingClosed) private view returns (bool) {
        if (isDayTradingClosed) {
            uint32 overnightMaxLeverage =
                IOstiumPairsStorage(registry.getContractAddress('pairsStorage')).pairOvernightMaxLeverage(pairIndex);
            if (overnightMaxLeverage != 0 && leverage > overnightMaxLeverage) {
                return true;
            }
        }
        return false;
    }

    function isNotDone() private view {
        if (isDone) {
            revert IsDone();
        }
    }

    function isTrading() private view {
        if (msg.sender != registry.getContractAddress('trading')) {
            revert NotTrading(msg.sender);
        }
    }

