// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ChainGasUsage} from "./ChainGasUsage.sol";
import {ISwap} from "./interfaces/ISwap.sol";
import {ITokenMessenger} from "./interfaces/ITokenMessenger.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Router is ChainGasUsage {
    using SafeERC20 for IERC20;

    uint256 public feeBp;
    uint256 public constant BP_DENOMINATOR = 10000;
    uint8 public constant SYSTEM_DECIMALS = 9;

    // Swap contract => registered
    mapping(address swap => bool registered) public swaps;
    // TokenMessenger contract => registered
    mapping(address tokenMessenger => bool registered) public tokenMessengers;
    // Relayer address => registered
    mapping(address relayer => bool registered) public relayers;
    // intermediaryToken => destinationChain => destinationToken => info
    enum DestinationToken {
        Disabled,
        Enabled,
        EnabledWithSwap
    }
    mapping(
        address intermediaryToken
            => mapping(uint32 destinationChain => mapping(bytes32 destinationToken => DestinationToken info))
    ) internal destinationTokenInfo;
    // nonce for messages
    uint256 public nonce;
    // messageHash => used
    mapping(bytes32 messageHash => bool used) public usedMessages;

    // token address => amount that can be withdrawn by admin
    mapping(address token => uint256 amount) public withdrawableAmount;

    event TokenSent(
        address sender,
        address sourceToken,
        uint256 amountIn,
        uint256 normalizedAmountOut,
        uint32 sourceChain,
        uint32 destinationChain,
        bytes32 destinationToken,
        bytes32 recipient,
        address intermediaryToken,
        uint256 nonce,
        bytes32 messageHash,
        address swapAddr,
        address tokenMessengersAddr,
        bytes32 metadata
    );
    event TokenReceived(
        uint256 normalizedAmountIn,
        uint256 fee,
        uint256 amountOut,
        uint32 sourceChain,
        uint32 destinationChain,
        bytes32 destinationToken,
        bytes32 recipient,
        address intermediaryToken,
        uint256 nonce,
        bytes32 messageHash,
        address swapAddr,
        address tokenMessengersAddr
    );

    address public constant ETH_MARKER = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint32 public immutable CHAIN_ID;

    uint32 public constant ACTION_ROUTER = DEFAULT_ACTION;
    uint32 public constant ACTION_SWAP = 1;

    constructor(uint32 _chainId) Ownable(msg.sender) {
        CHAIN_ID = _chainId;
    }

    function registerSwap(address swap, bool registered) external onlyOwner {
        swaps[swap] = registered;
    }

    function registerTokenMessenger(address tokenMessenger, bool registered) external onlyOwner {
        tokenMessengers[tokenMessenger] = registered;
        address token = ITokenMessenger(tokenMessenger).token();
        if (registered) {
            IERC20(token).forceApprove(tokenMessenger, type(uint256).max);
        } else {
            IERC20(token).forceApprove(tokenMessenger, 0);
        }
    }

    function registerRelayer(address relayer, bool registered) external onlyOwner {
        relayers[relayer] = registered;
    }

    // Getter for full destination token info
    function getDestinationTokenInfo(address intermediaryToken, uint32 destinationChain, bytes32 destinationToken)
        external
        view
        returns (DestinationToken)
    {
        return destinationTokenInfo[intermediaryToken][destinationChain][destinationToken];
    }

    // Extended setter to also control whether swap is required on destination chain
    function setDestinationToken(
        address intermediaryToken,
        uint32 destinationChain,
        bytes32 destinationToken,
        DestinationToken status
    ) external onlyOwner {
        destinationTokenInfo[intermediaryToken][destinationChain][destinationToken] = status;
    }

    function setFee(uint256 _feeBp) external onlyOwner {
        require(_feeBp <= BP_DENOMINATOR, "Fee too high");
        feeBp = _feeBp;
    }

    struct SendParams {
        uint256 amount;
        uint256 minSwapAmount;
        bytes32 destinationToken;
        bytes32 destinationAddress;
        bytes32 metadata;
        address sourceToken;
        address swapAddr;
        address tokenMessengerAddr;
        uint32 destinationChain;
    }

