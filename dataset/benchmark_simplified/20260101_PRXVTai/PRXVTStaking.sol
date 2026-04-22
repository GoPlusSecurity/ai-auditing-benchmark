// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ======== Inlined minimal dependencies (OpenZeppelin-derived) ========

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

library Address {
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");
        (bool success, bytes memory returndata) = target.call(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function verifyCallResult(bool success, bytes memory returndata, string memory errorMessage)
        internal
        pure
        returns (bytes memory)
    {
        if (success) {
            return returndata;
        }
        if (returndata.length > 0) {
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        }
        revert(errorMessage);
    }
}

library SafeERC20 {
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

contract ERC20 is Context, IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 value) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= value, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - value;
        }
        _balances[to] += value;

        emit Transfer(from, to, value);
    }

    function _mint(address account, uint256 value) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _totalSupply += value;
        _balances[account] += value;
        emit Transfer(address(0), account, value);
    }

    function _burn(address account, uint256 value) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");
        uint256 accountBalance = _balances[account];
        require(accountBalance >= value, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - value;
        }
        _totalSupply -= value;
        emit Transfer(account, address(0), value);
    }

    function _approve(address owner, address spender, uint256 value) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= value, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - value);
            }
        }
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        require(initialOwner != address(0), "Ownable: initial owner is the zero address");
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract Ownable2Step is Ownable {
    address private _pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    constructor() Ownable(_msgSender()) {}

    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }

    function transferOwnership(address newOwner) public virtual override onlyOwner {
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }

    function acceptOwnership() public virtual {
        address sender = _msgSender();
        require(pendingOwner() == sender, "Ownable2Step: caller is not the new owner");
        _pendingOwner = address(0);
        _transferOwnership(sender);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

abstract contract Pausable is Context {
    event Paused(address account);
    event Unpaused(address account);

    bool private _paused;

    constructor() {
        _paused = false;
    }

    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

/**
 * @title PRXVTStaking
 * @notice Staking contract for PRXVT token with embedded stPRXVT receipt token
 * @dev Implements Synthetix StakingRewards pattern with burn fees and boost multipliers
 *
 * Features:
 * - Stake PRXVT, receive stPRXVT (1:1)
 * - Earn rewards linearly distributed over time
 * - Configurable burn fee on reward claims (0-50%)
 * - Boost multipliers (1x-2x) for specific users
 * - Pausable with withdrawal escape hatch
 * - Instant withdrawals, no penalties
 */
contract PRXVTStaking is ERC20, Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // ============ Structs ============

    struct BoostInfo {
        uint256 multiplier; // 1e18 to 2e18 (1x to 2x)
        uint256 expiresAt; // Timestamp when boost expires
        string reason; // Reason for boost assignment
    }

    // ============ Events ============

    event RewardPaid(address indexed user, uint256 reward);
    event RewardBurned(address indexed user, uint256 amount);

    // ============ Constants ============

    /// @notice Address where burned tokens are sent
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    /// @notice Maximum burn fee (50% in basis points)
    uint256 public constant MAX_BURN_FEE = 5000;

    /// @notice Duration of boost multipliers
    uint256 public constant BOOST_DURATION = 7 days;

    /// @notice Precision multiplier for reward calculations
    uint256 public constant PRECISION = 1e18;

    // ============ Immutable State ============

    /// @notice PRXVT token address
    IERC20 public immutable prxvtToken;

    // ============ Reward Distribution (Synthetix Pattern) ============

    /// @notice Rewards distributed per second
    uint256 public rewardRate;

    /// @notice Duration of reward period (default 30 days)
    uint256 public rewardsDuration = 30 days;

    /// @notice Timestamp when current reward period ends
    uint256 public periodFinish;

    /// @notice Last time rewards were updated
    uint256 public lastUpdateTime;

    /// @notice Accumulated reward per token
    uint256 public rewardPerTokenStored;

    // ============ User Accounting ============

    /// @notice Reward per token already accounted for per user
    mapping(address => uint256) public userRewardPerTokenPaid;

    /// @notice Pending rewards per user
    mapping(address => uint256) public rewards;

    // ============ Burn Fee System ============

    /// @notice Burn fee percentage in basis points (0-5000)
    uint256 public burnFeePercent = 1000; // Default 10%

    /// @notice Total amount burned over contract lifetime
    uint256 public totalBurned;

    // ============ Boost System ============

    /// @notice Boost information per user
    mapping(address => BoostInfo) private _boosts;

    // ============ Staking Configuration ============

    /// @notice Minimum stake amount for first-time stakers
    uint256 public minimumStake = 10_000e18; // 10,000 PRXVT

    /// @notice Total amount of PRXVT staked
    uint256 private _totalStaked;

    // ============ Constructor ============

    /**
     * @notice Initialize the staking contract
     * @param _prxvtToken Address of the PRXVT token
     */
    constructor(address _prxvtToken) ERC20("Staked PRXVT", "stPRXVT") Ownable(msg.sender) {
        require(_prxvtToken != address(0), "Invalid token address");
        prxvtToken = IERC20(_prxvtToken);
    }

    // ============ Modifiers ============

    /**
     * @notice Update rewards for an account before state changes
     * @param account Address to update rewards for (address(0) to update global state only)
     */
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();

        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }

        _;
    }

    // ============ Synthetix Reward Pattern Functions ============

    /**
     * @notice Get the last time rewards are applicable
     * @return Timestamp of last applicable reward time
     */
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    /**
     * @notice Calculate accumulated reward per token
     * @return Reward per token value
     */
    function rewardPerToken() public view returns (uint256) {
        if (_totalStaked == 0) {
            return rewardPerTokenStored;
        }

        return
            rewardPerTokenStored + ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * PRECISION) / _totalStaked;
    }

    /**
     * @notice Calculate earned rewards for an account (includes boost)
     * @param account Address to check
     * @return Total earned rewards including boost multiplier
     */
    function earned(address account) public view returns (uint256) {
        // Calculate base reward
        uint256 baseReward = (balanceOf(account) * (rewardPerToken() - userRewardPerTokenPaid[account])) / PRECISION
            + rewards[account];

        // Apply boost if active
        BoostInfo storage boost = _boosts[account];
        if (boost.expiresAt > block.timestamp && boost.multiplier > PRECISION) {
            return (baseReward * boost.multiplier) / PRECISION;
        }

        return baseReward;
    }

    // ============ Core User Functions ============

    /**
     * @notice Claim earned rewards (burn fee applied)
     */
    function claimReward() public nonReentrant whenNotPaused updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "No rewards to claim");

        // Reset user rewards
        rewards[msg.sender] = 0;

        // Calculate burn fee
        uint256 burnAmount = (reward * burnFeePercent) / 10_000;
        uint256 userAmount = reward - burnAmount;

        // Update total burned
        totalBurned += burnAmount;

        // Transfer to burn address if fee > 0
        if (burnAmount > 0) {
            prxvtToken.safeTransfer(BURN_ADDRESS, burnAmount);
            emit RewardBurned(msg.sender, burnAmount);
        }

        // Transfer remainder to user
        if (userAmount > 0) {
            prxvtToken.safeTransfer(msg.sender, userAmount);
        }

        emit RewardPaid(msg.sender, userAmount);
    }
}
