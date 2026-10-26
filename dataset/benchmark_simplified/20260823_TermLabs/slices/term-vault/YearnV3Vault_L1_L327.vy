# @version 0.3.7

"""
@title Yearn V3 Vault
@license GNU AGPLv3
@author yearn.finance
@notice
    The Yearn VaultV3 is designed as a non-opinionated system to distribute funds of 
    depositors for a specific `asset` into different opportunities (aka Strategies)
    and manage accounting in a robust way.

    Depositors receive shares (aka vaults tokens) proportional to their deposit amount. 
    Vault tokens are yield-bearing and can be redeemed at any time to get back deposit 
    plus any yield generated.

    Addresses that are given different permissioned roles by the `role_manager` 
    are then able to allocate funds as they best see fit to different strategies 
    and adjust the strategies and allocations as needed, as well as reporting realized
    profits or losses.

    Strategies are any ERC-4626 compliant contracts that use the same underlying `asset` 
    as the vault. The vault provides no assurances as to the safety of any strategy
    and it is the responsibility of those that hold the corresponding roles to choose
    and fund strategies that best fit their desired specifications.

    Those holding vault tokens are able to redeem the tokens for the corresponding
    amount of underlying asset based on any reported profits or losses since their
    initial deposit.

    The vault is built to be customized by the management to be able to fit their
    specific desired needs. Including the customization of strategies, accountants, 
    ownership etc.
"""

# INTERFACES #

from vyper.interfaces import ERC20
from vyper.interfaces import ERC20Detailed

interface IStrategy:
    def asset() -> address: view
    def balanceOf(owner: address) -> uint256: view
    def convertToAssets(shares: uint256) -> uint256: view
    def convertToShares(assets: uint256) -> uint256: view
    def previewWithdraw(assets: uint256) -> uint256: view
    def maxDeposit(receiver: address) -> uint256: view
    def deposit(assets: uint256, receiver: address) -> uint256: nonpayable
    def maxRedeem(owner: address) -> uint256: view
    def redeem(shares: uint256, receiver: address, owner: address) -> uint256: nonpayable
    
interface IAccountant:
    def report(strategy: address, gain: uint256, loss: uint256) -> (uint256, uint256): nonpayable

interface IDepositLimitModule:
    def available_deposit_limit(receiver: address) -> uint256: view
    
interface IWithdrawLimitModule:
    def available_withdraw_limit(owner: address, max_loss: uint256, strategies: DynArray[address, MAX_QUEUE]) -> uint256: view

interface IFactory:
    def protocol_fee_config() -> (uint16, address): view

# EVENTS #
# ERC4626 EVENTS
event Deposit:
    sender: indexed(address)
    owner: indexed(address)
    assets: uint256
    shares: uint256

event Withdraw:
    sender: indexed(address)
    receiver: indexed(address)
    owner: indexed(address)
    assets: uint256
    shares: uint256

# ERC20 EVENTS
event Transfer:
    sender: indexed(address)
    receiver: indexed(address)
    value: uint256

event Approval:
    owner: indexed(address)
    spender: indexed(address)
    value: uint256

# STRATEGY EVENTS
event StrategyChanged:
    strategy: indexed(address)
    change_type: indexed(StrategyChangeType)
    
event StrategyReported:
    strategy: indexed(address)
    gain: uint256
    loss: uint256
    current_debt: uint256
    protocol_fees: uint256
    total_fees: uint256
    total_refunds: uint256

# DEBT MANAGEMENT EVENTS
event DebtUpdated:
    strategy: indexed(address)
    current_debt: uint256
    new_debt: uint256

# ROLE UPDATES
event RoleSet:
    account: indexed(address)
    role: indexed(Roles)

# STORAGE MANAGEMENT EVENTS
event UpdateFutureRoleManager:
    future_role_manager: indexed(address)

event UpdateRoleManager:
    role_manager: indexed(address)

event UpdateAccountant:
    accountant: indexed(address)

event UpdateDepositLimitModule:
    deposit_limit_module: indexed(address)

event UpdateWithdrawLimitModule:
    withdraw_limit_module: indexed(address)

event UpdateDefaultQueue:
    new_default_queue: DynArray[address, MAX_QUEUE]

event UpdateUseDefaultQueue:
    use_default_queue: bool

event UpdateAutoAllocate:
    auto_allocate: bool

event UpdatedMaxDebtForStrategy:
    sender: indexed(address)
    strategy: indexed(address)
    new_debt: uint256

event UpdateDepositLimit:
    deposit_limit: uint256

event UpdateMinimumTotalIdle:
    minimum_total_idle: uint256

event UpdateProfitMaxUnlockTime:
    profit_max_unlock_time: uint256

event DebtPurchased:
    strategy: indexed(address)
    amount: uint256

event Shutdown:
    pass

# STRUCTS #
struct StrategyParams:
    # Timestamp when the strategy was added.
    activation: uint256 
    # Timestamp of the strategies last report.
    last_report: uint256
    # The current assets the strategy holds.
    current_debt: uint256
    # The max assets the strategy can hold. 
    max_debt: uint256

# CONSTANTS #
# The max length the withdrawal queue can be.
MAX_QUEUE: constant(uint256) = 10
# 100% in Basis Points.
MAX_BPS: constant(uint256) = 10_000
# Extended for profit locking calculations.
MAX_BPS_EXTENDED: constant(uint256) = 1_000_000_000_000
# The version of this vault.
API_VERSION: constant(String[28]) = "3.0.4"

# ENUMS #
# Each permissioned function has its own Role.
# Roles can be combined in any combination or all kept separate.
# Follows python Enum patterns so the first Enum == 1 and doubles each time.
enum Roles:
    ADD_STRATEGY_MANAGER # Can add strategies to the vault.
    REVOKE_STRATEGY_MANAGER # Can remove strategies from the vault.
    FORCE_REVOKE_MANAGER # Can force remove a strategy causing a loss.
    ACCOUNTANT_MANAGER # Can set the accountant that assess fees.
    QUEUE_MANAGER # Can set the default withdrawal queue.
    REPORTING_MANAGER # Calls report for strategies.
    DEBT_MANAGER # Adds and removes debt from strategies.
    MAX_DEBT_MANAGER # Can set the max debt for a strategy.
    DEPOSIT_LIMIT_MANAGER # Sets deposit limit and module for the vault.
    WITHDRAW_LIMIT_MANAGER # Sets the withdraw limit module.
    MINIMUM_IDLE_MANAGER # Sets the minimum total idle the vault should keep.
    PROFIT_UNLOCK_MANAGER # Sets the profit_max_unlock_time.
    DEBT_PURCHASER # Can purchase bad debt from the vault.
    EMERGENCY_MANAGER # Can shutdown vault in an emergency.

enum StrategyChangeType:
    ADDED
    REVOKED

enum Rounding:
    ROUND_DOWN
    ROUND_UP

# STORAGE #
# Underlying token used by the vault.
asset: public(address)
# Based off the `asset` decimals.
decimals: public(uint8)
# Deployer contract used to retrieve the protocol fee config.
factory: address

# HashMap that records all the strategies that are allowed to receive assets from the vault.
strategies: public(HashMap[address, StrategyParams])
# The current default withdrawal queue.
default_queue: public(DynArray[address, MAX_QUEUE])
# Should the vault use the default_queue regardless whats passed in.
use_default_queue: public(bool)
# Should the vault automatically allocate funds to the first strategy in queue.
auto_allocate: public(bool)

### ACCOUNTING ###
# ERC20 - amount of shares per account
balance_of: HashMap[address, uint256]
# ERC20 - owner -> (spender -> amount)
allowance: public(HashMap[address, HashMap[address, uint256]])
# Total amount of shares that are currently minted including those locked.
total_supply: uint256
# Total amount of assets that has been deposited in strategies.
total_debt: uint256
# Current assets held in the vault contract. Replacing balanceOf(this) to avoid price_per_share manipulation.
total_idle: uint256
# Minimum amount of assets that should be kept in the vault contract to allow for fast, cheap redeems.
minimum_total_idle: public(uint256)
# Maximum amount of tokens that the vault can accept. If totalAssets > deposit_limit, deposits will revert.
deposit_limit: public(uint256)

### PERIPHERY ###
# Contract that charges fees and can give refunds.
accountant: public(address)
# Contract to control the deposit limit.
deposit_limit_module: public(address)
# Contract to control the withdraw limit.
withdraw_limit_module: public(address)

### ROLES ###
# HashMap mapping addresses to their roles
roles: public(HashMap[address, Roles])
# Address that can add and remove roles to addresses.
role_manager: public(address)
# Temporary variable to store the address of the next role_manager until the role is accepted.
future_role_manager: public(address)

# ERC20 - name of the vaults token.
name: public(String[64])
# ERC20 - symbol of the vaults token.
symbol: public(String[32])

# State of the vault - if set to true, only withdrawals will be available. It can't be reverted.
shutdown: bool
# The amount of time profits will unlock over.
profit_max_unlock_time: uint256
# The timestamp of when the current unlocking period ends.
full_profit_unlock_date: uint256
# The per second rate at which profit will unlock.
profit_unlocking_rate: uint256
# Last timestamp of the most recent profitable report.
last_profit_update: uint256

# `nonces` track `permit` approvals with signature.
nonces: public(HashMap[address, uint256])
DOMAIN_TYPE_HASH: constant(bytes32) = keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)')
PERMIT_TYPE_HASH: constant(bytes32) = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")

# Constructor
@external
def __init__():
    # Set `asset` so it cannot be re-initialized.
    self.asset = self
    
@external
def initialize(
    asset: address, 
    name: String[64], 
    symbol: String[32], 
    role_manager: address, 
    profit_max_unlock_time: uint256
):
    """
    @notice
        Initialize a new vault. Sets the asset, name, symbol, and role manager.
    @param asset
        The address of the asset that the vault will accept.
    @param name
        The name of the vault token.
    @param symbol
        The symbol of the vault token.
    @param role_manager 
        The address that can add and remove roles to addresses
    @param profit_max_unlock_time
        The amount of time that the profit will be locked for
    """
    assert self.asset == empty(address), "initialized"
    assert asset != empty(address), "ZERO ADDRESS"
    assert role_manager != empty(address), "ZERO ADDRESS"

    self.asset = asset
    # Get the decimals for the vault to use.
    self.decimals = ERC20Detailed(asset).decimals()
    
    # Set the factory as the deployer address.
    self.factory = msg.sender

    # Must be less than one year for report cycles
    assert profit_max_unlock_time <= 31_556_952 # dev: profit unlock time too long
    self.profit_max_unlock_time = profit_max_unlock_time

    self.name = name
    self.symbol = symbol
    self.role_manager = role_manager

## SHARE MANAGEMENT ##
## ERC20 ##
