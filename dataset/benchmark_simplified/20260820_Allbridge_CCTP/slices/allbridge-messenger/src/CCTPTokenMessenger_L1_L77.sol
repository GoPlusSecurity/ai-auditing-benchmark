// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ITokenMessenger} from "./interfaces/ITokenMessenger.sol";
import {ChainGasUsage} from "./ChainGasUsage.sol";

interface ICCTPTokenMessenger {
    function depositForBurnWithHook(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold,
        bytes calldata hookData
    ) external;

    function localMessageTransmitter() external view returns (address);
}

interface IMessageTransmitter {
    function receiveMessage(bytes calldata message, bytes calldata attestation) external returns (bool);
}

contract CCTPTokenMessenger is ITokenMessenger, ChainGasUsage {
    using SafeERC20 for IERC20;

    uint256 internal constant MAX_FEE_SHARE_P = 1e9;

    address public immutable TOKEN;
    address public immutable TOKEN_MESSENGER;
    address public immutable MESSAGE_TRANSMITTER;
    address public immutable ROUTER;
    uint32 public minFinalityThreshold = 1000;
    uint256 public maxFeeShare = 100000;

    mapping(uint32 chainId => uint32 domainPlusOne) public domainMapping;
    mapping(uint32 chainId => bytes32 remoteRouter) public remoteRouters;
    mapping(uint32 chainId => bytes32 remoteTokenMessenger) public remoteTokenMessengers;
    mapping(bytes32 messageHash => uint256 receivedAmount) public receivedMessages;

    mapping(uint32 domain => uint32 chainId) public domainToChainId;

    address public constant ETH_MARKER = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    constructor(address _router, address _token, address _tokenMessenger) Ownable(msg.sender) {
        ROUTER = _router;
        TOKEN = _token;
        TOKEN_MESSENGER = _tokenMessenger;
        MESSAGE_TRANSMITTER = ICCTPTokenMessenger(_tokenMessenger).localMessageTransmitter();
    }

    function setDomainMapping(uint32 chain, uint32 domain) external onlyOwner {
        domainMapping[chain] = domain + 1;
        domainToChainId[domain] = chain;
    }

    function setRemoteRouter(uint32 chain, bytes32 remoteRouter) external onlyOwner {
        remoteRouters[chain] = remoteRouter;
    }

    function setRemoteTokenMessenger(uint32 chain, bytes32 remoteTokenMessenger) external onlyOwner {
        remoteTokenMessengers[chain] = remoteTokenMessenger;
    }

    function setMinFinalityThreshold(uint32 _minFinalityThreshold) external onlyOwner {
        minFinalityThreshold = _minFinalityThreshold;
    }

    function setMaxFeeShare(uint256 _maxFeeShare) external onlyOwner {
        maxFeeShare = _maxFeeShare;
    }

