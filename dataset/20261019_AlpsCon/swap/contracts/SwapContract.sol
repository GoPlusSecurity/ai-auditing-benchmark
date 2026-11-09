//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "./interfaces/ChainLinkAggregatorV3Interface.sol";
import {IAITradeHubContract} from "./interfaces/IAITradeHubContract.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IVaultContract} from "./interfaces/IVaultContract.sol";
import {SafeERC20} from "./math/SafeERC20.sol";
import {SafeMath} from "./math/SafeMath.sol";
import {ReentrancyGuard} from "./utils/ReentrancyGuard.sol";

contract SwapContract is ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint constant public DECIMAL_PRECISION = 1e18;
    // Use to convert a price answer to an 18-digit precision uint
    uint constant public TARGET_RATE_DIGITS = 8;

    struct ContractConfig {
        address owner;
        IERC20 baseToken;
        IERC20 usdToken;
        mapping(address => address) tokenWithChainLinkAddress; // Token address => Chainlink oracle address
        address[] supportTokens;
        uint256 exchangeUSDTRate; // 10**TARGET_RATE_DIGITS mean 10 trai = 1 USDT
        uint256 swapFee; //3 = 0.3%
        IAITradeHubContract aiTradeHubContract;
        IVaultContract vaultContract;
    }

    struct ChainlinkResponse {
        uint80 roundId;
        int256 answer;
        uint256 timestamp;
        bool success;
        uint8 decimals;
    }

    //Event
    event SwapEvent(address indexed token1, address indexed  token2, uint256 amount, uint256 rate, uint256 fee);

    //Error
    error SwapPermissionDenied();
    error SwapNotContainMainTokenError();
    error SwapNotContainListedTokenError();
    error SwapAmountInvalidError();
    error SwapInsufficientFundsError();
    error SwapTokenInvalidError();
    error SwapTokenAddressNotInWhiteListError();
    error SwapTokenGetPriceError();

    ContractConfig public config;

    modifier onlyOwner() {
        if (msg.sender != config.owner) revert SwapPermissionDenied();
        _;
    }

    constructor(address baseToken, address usdToken, address[] memory exchangeTokenAddress, address[] memory exchangeTokenChainLinkAddress, uint256 rate, uint256 swapFee, address aiTradeHubContractAddress, address vaultContractAddress){
        config.owner = msg.sender;
        config.baseToken = IERC20(baseToken);
        config.usdToken = IERC20(usdToken);
        config.exchangeUSDTRate = rate;
        config.swapFee = swapFee;
        config.aiTradeHubContract = IAITradeHubContract(aiTradeHubContractAddress);
        config.vaultContract = IVaultContract(vaultContractAddress);
        for (uint i = 0; i < exchangeTokenAddress.length; i++) {
            config.tokenWithChainLinkAddress[exchangeTokenAddress[i]] = exchangeTokenChainLinkAddress[i];
            config.supportTokens.push(exchangeTokenAddress[i]);
        }
        config.supportTokens.push(baseToken);
        config.supportTokens.push(usdToken);
    }

    //PUBLIC function
    function swap(address fromToken, address toToken, uint256 amount) external nonReentrant {
        if (amount == 0) revert SwapAmountInvalidError();
        address mainTokenAddress = address(config.baseToken);
        if (fromToken != mainTokenAddress && toToken != mainTokenAddress)
            revert SwapNotContainMainTokenError();
        if (!_isInWhiteList(msg.sender))
            revert SwapTokenAddressNotInWhiteListError();
        _swap(fromToken, toToken, amount, true);
    }

    function estimateSwapAmount(address fromToken, address toToken, uint256 amount) public view returns (uint256){
        uint256 swapRate = _getSwapRate(fromToken, toToken);
        uint256 swapAmount = _getSwapAmount(amount, swapRate);
        return swapAmount;
    }

    function supportTokens() external view returns (address[] memory){
        return config.supportTokens;
    }

    function getUSDPrice(address tokenAddress) external view returns (uint256){
        if (tokenAddress == address(0))
            revert SwapTokenInvalidError();
        if (tokenAddress == address(config.baseToken))
            return (10 ** (TARGET_RATE_DIGITS * 2)).div(config.exchangeUSDTRate);

        if (tokenAddress == address(config.usdToken))
            return 10 ** TARGET_RATE_DIGITS;

        address chainLinkAddress = config.tokenWithChainLinkAddress[tokenAddress];
        if (chainLinkAddress == address(0))
            revert SwapTokenInvalidError();
        return _fetchPrice(chainLinkAddress);
    }

    function getSwapRate(address fromToken, address toToken) external view returns (uint256){
        return _getSwapRate(fromToken, toToken);
    }

    function isInWhiteList(address _address) external view returns (bool){
        return _isInWhiteList(_address);
    }

    //PUBLIC function END

    //OWNER function
    function addExchangeToken(address tokenAddress, address chainLinkTokenAddress) onlyOwner external {
        if (tokenAddress == address(0) || chainLinkTokenAddress == address(0)) {
            revert SwapTokenInvalidError();
        }
        config.tokenWithChainLinkAddress[tokenAddress] = chainLinkTokenAddress;
        config.supportTokens.push(tokenAddress);
    }

    function removeExchangeToken(address tokenAddress) onlyOwner public {
        if (tokenAddress == address(0)) {
            revert SwapTokenInvalidError();
        }
        delete config.tokenWithChainLinkAddress[tokenAddress];
        for (uint i = 0; i < config.supportTokens.length; i++) {
            if (config.supportTokens[i] == tokenAddress) {
                delete config.supportTokens[i];
            }
        }
    }

    function addAddressToWhiteList(address walletAddress) onlyOwner external {
        config.vaultContract.moduleWriteStorageBool(_genWhiteListKey(walletAddress), true);
    }

    function removeAddressInWhiteList(address walletAddress) onlyOwner external {
        (,
            ,
            ,
            ,
            uint256 user_locked_amount,
            uint256 user_pending_amount,
            ,
            int256 user_earnings,
            ,
        ) = config.aiTradeHubContract.getStats(walletAddress);
        //If user have funds then not remove it
        if (user_locked_amount > 0 || user_pending_amount > 0 || user_earnings > 0)
            return;
        config.vaultContract.moduleWriteStorageBool(_genWhiteListKey(walletAddress), false);
    }

    function setExchangeUSDTRate(uint256 rate) onlyOwner external {
        if (rate > 0)
            config.exchangeUSDTRate = rate;
    }

    function setSwapFee(uint256 fee) onlyOwner external {
        if (fee > 0)
            config.swapFee = fee;
    }

    function setAITradeHubContractAddress(address aiTradeHubContractAddress) onlyOwner public {
        config.aiTradeHubContract = IAITradeHubContract(aiTradeHubContractAddress);
    }
    //OWNER function END
    function _swap(address fromToken, address toToken, uint256 amount, bool chargeFee) internal {
        address sender = msg.sender;
        uint256 senderTokenBalance = IERC20(fromToken).balanceOf(sender);
        if (senderTokenBalance <= 0) revert SwapInsufficientFundsError();
        uint256 rate = _getSwapRate(fromToken, toToken);
        uint256 toAmount = _getSwapAmount(amount, rate);
        uint256 fee;
        if (chargeFee) {
            fee = _getSwapFee(toAmount);
            toAmount -= fee;
        }
        //Transfer from sender to swap contract
        IERC20(fromToken).safeTransferFrom(sender, address(this), amount);
        //Transfer from swap contract to Vault
        IERC20(fromToken).approve(address(config.vaultContract), amount);
        config.vaultContract.moduleDepositToken(fromToken, amount, 0);
        //Withdraw from Vault to sender
        config.vaultContract.moduleWithdrawToken(toToken, sender, toAmount);
        //Collect fee to Vault
        if (fee > 0) {
            config.vaultContract.moduleRecordFee(toToken, fee);
        }
        emit SwapEvent(fromToken, toToken, amount, rate, fee);
    }

    function _getSwapAmount(uint256 amount, uint256 rate) internal pure returns (uint256){
        return amount.mul(rate).div(10 ** TARGET_RATE_DIGITS);
    }

    function _getSwapFee(uint256 amount) internal view returns (uint256){
        return amount.mul(config.swapFee).div(1000);
    }

    function _getSwapRate(address fromToken, address toToken) internal view returns (uint256){
        address mainTokenAddress = address(config.baseToken);
        uint256 rate;
        // USDT -> TRAI
        if (fromToken == address(config.usdToken)) {
            return config.exchangeUSDTRate;
        }
            // TRAI -> USDT
        else if (toToken == address(config.usdToken)) {
            return (10 ** (TARGET_RATE_DIGITS * 2)).div(config.exchangeUSDTRate);
        }
        address otherTokenAddress;
        if (fromToken == mainTokenAddress) {
            otherTokenAddress = toToken;
        } else {
            otherTokenAddress = fromToken;
        }
        address chainLinkTokenAddress = config.tokenWithChainLinkAddress[otherTokenAddress];
        if (chainLinkTokenAddress == address(0)) revert SwapNotContainListedTokenError();

        uint256 tokenPrice = _fetchPrice(chainLinkTokenAddress);
        if (tokenPrice <= 0)
            revert SwapTokenGetPriceError();
        // TRAI -> OTHER
        if (fromToken == mainTokenAddress) {
            rate = (10 ** (TARGET_RATE_DIGITS * 2)).div(config.exchangeUSDTRate).mul(10 ** TARGET_RATE_DIGITS).div(tokenPrice);

        }
            //OTHER -> TRAI
        else {
            rate = (tokenPrice * config.exchangeUSDTRate).div(10 ** TARGET_RATE_DIGITS);
        }
        return rate;
    }

    function _fetchPrice(address chainLinkTokenAddress) internal view returns (uint) {
        ChainlinkResponse memory _chainlinkResponse = _getCurrentChainlinkResponse(AggregatorV3Interface(chainLinkTokenAddress));
        uint scaledChainlinkPrice = _scaleChainlinkPriceByDigits(uint256(_chainlinkResponse.answer), _chainlinkResponse.decimals);
        return scaledChainlinkPrice;
    }

    function _getCurrentChainlinkResponse(AggregatorV3Interface priceAggregator) internal view returns (ChainlinkResponse memory chainlinkResponse) {
        // First, try to get current decimal precision:
        try priceAggregator.decimals() returns (uint8 decimals) {
            // If call to Chainlink succeeds, record the current decimal precision
            chainlinkResponse.decimals = decimals;
        } catch {
            // If call to Chainlink aggregator reverts, return a zero response with success = false
            return chainlinkResponse;
        }

        // Secondly, try to get latest price data:
        try priceAggregator.latestRoundData() returns
        (
            uint80 roundId,
            int256 answer,
            uint256 /* startedAt */,
            uint256 timestamp,
            uint80 /* answeredInRound */
        )
        {
            // If call to Chainlink succeeds, return the response and success = true
            chainlinkResponse.roundId = roundId;
            chainlinkResponse.answer = answer;
            chainlinkResponse.timestamp = timestamp;
            chainlinkResponse.success = true;
            return chainlinkResponse;
        } catch {
            // If call to Chainlink aggregator reverts, return a zero response with success = false
            return chainlinkResponse;
        }
    }

    function _scaleChainlinkPriceByDigits(uint _price, uint _answerDigits) internal pure returns (uint) {
        uint price;
        if (_answerDigits >= TARGET_RATE_DIGITS) {
            // Scale the returned price value down to ourProject's target precision
            price = _price / (10 ** (_answerDigits - TARGET_RATE_DIGITS));
        }
        else if (_answerDigits < TARGET_RATE_DIGITS) {
            // Scale the returned price value up to ourProject's target precision
            price = _price * (10 ** (TARGET_RATE_DIGITS - _answerDigits));
        }
        return price;
//        return 20 * 10 ** TARGET_RATE_DIGITS;
    }

    function _isInWhiteList(address _address) internal view returns (bool){
        return config.vaultContract.moduleReadStorageBool(_genWhiteListKey(_address));
    }

    function _genWhiteListKey(address _address) internal pure returns (bytes32){
        return keccak256(abi.encode("WHITE_LIST", _address));
    }
}