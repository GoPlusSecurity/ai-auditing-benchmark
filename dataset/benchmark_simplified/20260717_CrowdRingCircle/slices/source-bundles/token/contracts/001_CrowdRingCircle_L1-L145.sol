// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title IERC20Minimal
 * @notice Minimal interface for USDT interactions
 */
interface IERC20Minimal {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);
}

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function sync() external;
}

contract CrowdRingCircle is
    ERC20,
    ERC20Burnable,
    ERC20Permit,
    Ownable2Step,
    Pausable,
    ReentrancyGuard
{

    /// @notice Total supply: 100,000,000 CRC with 18 decimals
    uint256 public constant TOTAL_SUPPLY = 100_000_000 * 1e18;

    /// @notice BSC Mainnet USDT (BEP-20) contract address
    address public constant USDT = 0x55d398326f99059fF775485246999027B3197955;

    /// @notice Treasury address that receives USDT recharges
    address public treasury;

    /// @notice Addresses recognized as DEX liquidity pairs (buy is blocked from these)
    mapping(address => bool) public isDexPair;

    /// @notice Addresses exempt from buy/sell restrictions (owner, router, etc.)
    mapping(address => bool) public isExemptFromRestriction;

    /// @notice Master switch for buy restriction enforcement
    bool public buyRestrictionEnabled = true;

    /// @notice Minimum USDT recharge amount (anti-dust)
    uint256 public minRechargeAmount = 1 * 1e18; // 1 USDT

    /// @notice Maximum USDT recharge amount per transaction
    uint256 public maxRechargeAmount = 1_000_000 * 1e18; // 1,000,000 USDT

    /// @notice Tracks total USDT recharged per user
    mapping(address => uint256) public userRechargeTotal;

    /// @notice Global total USDT recharged
    uint256 public totalRecharged;

    /// @notice Minimum CRC balance a non-exempt holder must retain after any outgoing transfer
    uint256 public minHoldAmount = 0; // 1 CRC

    /// @notice Blacklisted addresses (cannot send or receive CRC)
    mapping(address => bool) public isBlacklisted;

    // 卖出销毁总开关
    bool public sellDestroyEnabled = true;

    // 卖出费率：1000 = 10%（基数 10000）
    uint256 public sellFeeRate;

    // 手续费接收地址
    address public feeReceiver;

    event DexPairUpdated(address indexed pair, bool status);
    event ExemptionUpdated(address indexed account, bool status);
    event BuyRestrictionToggled(bool enabled);
    event USDTRecharged(address indexed user, uint256 amount, uint256 timestamp);
    event RechargeAmountLimitsUpdated(uint256 newMin, uint256 newMax);
    event BlacklistUpdated(address indexed account, bool status);
    event EmergencyTokenRecovered(address indexed token, address indexed to, uint256 amount);
    event MinHoldAmountUpdated(uint256 newAmount);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event UserRechargeTotalUpdated(address indexed user, uint256 oldAmount, uint256 newAmount);
    event BurnFromPair(uint256 indexed burnAmount, uint256 pairBalanceBefore, uint256 pairBalanceAfter, string burnType);
    event SafeDeductApplied(address account, uint256 requested, uint256 actual);
    event sellDestroyToggled(bool enabled);
    event SellFeeRateUpdated(uint256 oldRate, uint256 newRate);
    event FeeReceiverUpdated(address indexed oldReceiver, address indexed newReceiver);

    error BuyRestricted();
    error ZeroAddress();
    error Blacklisted(address account);
    error RechargeBelowMinimum(uint256 amount, uint256 minimum);
    error RechargeAboveMaximum(uint256 amount, uint256 maximum);
    error InvalidLimits();
    error TransferFailed();
    error CannotRecoverCRC();
    error InsufficientRetainedBalance(uint256 postBalance, uint256 minRequired);
    error FeeTooHigh();

    /**
     * @param initialOwner Address that receives total supply and becomes contract owner
     * @param initialOwner Initial treasury address that receives USDT recharges
     */
    constructor(address initialOwner)
    ERC20(unicode"众环CRC", unicode"众环CRC")
    ERC20Permit(unicode"众环CRC")
    Ownable(initialOwner)
    {
        if (initialOwner == address(0)) revert ZeroAddress();
        
        // Mint entire supply to initial owner
        _mint(initialOwner, TOTAL_SUPPLY);

        // Set initial treasury address
        treasury = initialOwner; 

        // Owner is exempt from restrictions by default
        isExemptFromRestriction[initialOwner] = true;

        sellFeeRate = 1000;          // 10%
        feeReceiver = initialOwner;

        emit ExemptionUpdated(initialOwner, true);
        emit TreasuryUpdated(address(0), initialOwner);
    }

    /**
     * @dev Override _update to enforce:
     *  1. Blacklist check
     *  2. Buy restriction (block transfers FROM DEX pairs to non-exempt addresses)
     *  3. Minimum hold requirement (non-exempt senders must retain minHoldAmount)
     */
