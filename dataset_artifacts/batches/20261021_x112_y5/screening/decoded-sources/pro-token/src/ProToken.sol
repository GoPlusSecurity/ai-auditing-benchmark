// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title IPancakePair
 * @dev Interface for PancakeSwap pair contract
 */
interface IPancakePair {
  function sync() external;
}

/**
 * @title Token
 * @dev ERC20 token contract with liquidity pool balancing functionality
 * Features:
 * - Whitelist management for exempt addresses
 * - Sell tax mechanism
 * - Transfer restrictions from/to liquidity pool
 * - Automatic liquidity pool balancing
 */
contract Token is ERC20, Ownable {

    /// @dev Governance address that controls contract parameters
    address public governance;
    
    /// @dev Treasury address authorized to mint tokens
    address public treasury;
    
    /// @dev Mapping of whitelisted addresses exempt from transfer restrictions
    mapping(address => bool) public whitelist; 

    /// @dev Target liquidity pool address (e.g., PancakeSwap pair)
    address public targetPool;
    
    /// @dev Target ratio for pool balancing (in basis points, max 500 = 5%)
    uint256 public targetRatio;

    /// @dev Transfer status flag - when false, transfers from pool are disabled
    bool public transferStatus;
    
    /// @dev Sell tax ratio (in basis points, max 3000 = 30%)
    uint256 public sellRatio; 
    
    /// @dev Address that receives sell tax fees
    address public feeReceiver;

    /// @dev Dead address for token burns
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
    
    /// @dev Base value for percentage calculations (10000 = 100%)
    uint256 public constant BASE_100 = 10000;

    uint256 public lastBalanceTime;
    uint256 public constant BALANCE_COOLDOWN = 6 hours;
   
   
    // Errors
    error InvalidAddress();
    error InvalidRatio();
    error Disabled();
    error Unauthorized();
    error ErrorCooldown();

    // Events
    event TreasuryAddressUpdated(address _newTreasury);
    event GovernanceAddressupdated(address _newGovernance);
    event FeeReceiverAddressUpdated(address _newReceiver);
    event SellRateChanged(uint256 _ratio);
    event BalanceTargetRateChanged(uint256 _ratio);
    event BalancePoolAddressUpdated(address _pool);
    event TokenTransferStateUpdated(bool _enabled);
    event WhitelistAdded(address _address);
    event WhitelistRemoved(address _address);
    event BalancePoolBurned(uint256 _burnAmount);

    /**
     * @dev Constructor - Initializes the token contract
     * Sets initial sell tax to 3% (300 basis points)
     * Sets initial target ratio to 1% (100 basis points)
     * Sets deployer as initial governance and fee receiver
     */
    constructor() ERC20("Pro Token", "Pro") Ownable(msg.sender) {
        sellRatio = 300;
        targetRatio = 100;

        feeReceiver = msg.sender;
        governance = msg.sender;
    }

    /**
     * @dev Modifier to restrict function access to governance only
     */
    modifier onlyGovernance() {
        require(msg.sender == governance, "unauthorized access");
        _;
    }

    function decimals() public pure override returns (uint8) {
        return 9;
    }



    /**
     * @dev Internal function to handle token transfers with tax and restrictions
     * @param _from Address sending tokens
     * @param _to Address receiving tokens
     * @param _amount Amount of tokens to transfer
     * 
     * Logic:
     * - If transfer is from pool to non-whitelisted address: check if transfers are enabled
     * - If transfer is to pool from non-whitelisted address: apply sell tax
     * - Whitelisted addresses bypass all restrictions
     */
    function _update(address _from, address _to, uint256 _amount) internal  override {
        if ((_from == targetPool && !whitelist[_to]) || (_to == targetPool && !whitelist[_from])) {
            if (_from == targetPool) {   
                // Transfer from pool: only allowed if transferStatus is true or sending to DEAD
               if (!transferStatus && ( _to != DEAD && !whitelist[_to])) revert Disabled();
            } else if (_to == targetPool) { 
                // Transfer to pool (sell): apply sell tax
                require(feeReceiver != address(0) && feeReceiver != targetPool, "invalid fee receiver");
                uint256 sellfeeAmount = _amount * sellRatio / BASE_100;
                if (sellfeeAmount > 0) {
                    if (sellfeeAmount >= _amount) revert InvalidRatio();
                    super._update(_from, feeReceiver, sellfeeAmount);
                    _amount -= sellfeeAmount;
                }
            }
        }
        super._update(_from, _to, _amount);
    }
   

    /**
     * @dev Add an address to the whitelist
     * @param _addr Address to add to whitelist
     * Whitelisted addresses are exempt from transfer restrictions and sell taxes
     */
    function addWhitelist(address _addr) external onlyOwner {
        whitelist[_addr] = true;

        emit WhitelistAdded(_addr);
    }

    /**
     * @dev Remove an address from the whitelist
     * @param _addr Address to remove from whitelist
     */
    function removeWhitelist(address _addr) external onlyOwner {
        whitelist[_addr] = false;

        emit WhitelistRemoved(_addr);
    }

    /**
     * @dev Set the target liquidity pool address
     * @param _newPool Address of the liquidity pool (e.g., PancakeSwap pair)
     * This address is used for transfer restrictions and pool balancing
     */
    function setTargetPool(address _newPool) external onlyOwner {
        if(_newPool == address(0)) revert InvalidAddress();
        targetPool =_newPool;

        emit BalancePoolAddressUpdated(targetPool);
    }

    /**
     * @dev Set the treasury address
     * @param _newTreasury Address of the treasury
     * Treasury address is authorized to mint new tokens
     */
    function setTreasury(address _newTreasury) external onlyOwner {
        if(_newTreasury == address(0)) revert InvalidAddress();
        treasury = _newTreasury;

        emit TreasuryAddressUpdated(treasury);
    }


    /**
     * @dev Set the target ratio for pool balancing
     * @param _newRatio New target ratio in basis points (0-500, where 500 = 5%)
     * This ratio determines how much of the pool's token balance will be burned during balancePool()
     */
    function setTargetRatio(uint256 _newRatio) external onlyOwner {
        if(_newRatio > 500) revert InvalidRatio();
        targetRatio = _newRatio;
        
        emit BalanceTargetRateChanged(targetRatio);
    }

  

    /**
     * @dev Enable or disable transfers from the liquidity pool
     * @param _enable True to enable transfers from pool, false to disable
     * When disabled, only whitelisted addresses and DEAD address can receive tokens from pool
     */
    function setTransferState(bool _enable) external onlyOwner {
        transferStatus = _enable;

        emit TokenTransferStateUpdated(_enable);
    }

    /**
     * @dev Transfer governance to a new address
     * @param _newGovernance Address of the new governance
     * This transfers all administrative control to the new address
     */
    function transferGovernance(address _newGovernance) external onlyOwner {
        if (_newGovernance == address(0)) revert InvalidAddress();
        governance = _newGovernance;

        emit GovernanceAddressupdated(governance);
    }

    /**
     * @dev Set the fee receiver address
     * @param _newReceiver Address that will receive sell tax fees
     */
    function setFeeReceiver(address _newReceiver) external onlyGovernance {
        if (_newReceiver == address(0)) revert InvalidAddress();
        feeReceiver = _newReceiver;

        emit FeeReceiverAddressUpdated(feeReceiver);
    }

    /**
     * @dev Set the sell tax rate
     * @param _newTaxRate New sell tax rate in basis points (0-3000, where 3000 = 30%)
     * This tax is applied when tokens are sold to the liquidity pool
     */
    function setSellRates(uint256 _newTaxRate) external onlyGovernance {
        if(_newTaxRate > 3000) revert InvalidRatio();
        sellRatio = _newTaxRate;

        emit SellRateChanged(sellRatio);
    }

    /**
     * @dev Balance the liquidity pool by burning a percentage of pool's tokens
     * This function:
     * 1. Calculates the burn amount based on targetRatio
     * 2. Burns tokens from the pool by sending them to DEAD address
     * 3. Syncs the PancakeSwap pair to update reserves
     * 
     * Requirements:
     * - targetRatio must be less than 500 (5%)
     * - Only callable by governance
     */
    function balancePool() external onlyGovernance {
        if (block.timestamp < lastBalanceTime + BALANCE_COOLDOWN) revert ErrorCooldown();
        if (targetRatio > 500) revert InvalidRatio();  // max 5%
        if (targetPool == address(0)) revert InvalidAddress();

        uint256 burnAmount = balanceOf(targetPool) * targetRatio / BASE_100;
        if (burnAmount == 0) revert ErrorCooldown();
        _update(targetPool, DEAD, burnAmount);
       
        IPancakePair(targetPool).sync();
        lastBalanceTime = block.timestamp;
        emit BalancePoolBurned(burnAmount);
    }

    /**
     * @dev Mint new tokens to a specified address
     * @param _to Address to receive the minted tokens
     * @param _amount Amount of tokens to mint
     * 
     * Requirements:
     * - Only callable by treasury address
     */
    function mint(address _to, uint256 _amount) external {
        if(msg.sender != treasury) revert Unauthorized();

        _mint(_to, _amount);
    }

}