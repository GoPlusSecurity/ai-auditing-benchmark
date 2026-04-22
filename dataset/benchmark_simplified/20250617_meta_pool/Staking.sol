// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

/// Minimal, inlined OpenZeppelin-style building blocks required by the
/// `mint()` and `depositETH()` call chains. This file intentionally contains
/// no external imports.

library MathUpgradeable {
    enum Rounding {
        Down,
        Up,
        Zero
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /// @dev Full precision multiplication/division, derived from OpenZeppelin v4.8.0.
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator,
        Rounding rounding
    ) internal pure returns (uint256 result) {
        result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
    }

    /// @dev Full precision multiplication/division, derived from OpenZeppelin v4.8.0.
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            uint256 prod0;
            uint256 prod1;
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            if (prod1 == 0) {
                require(denominator > 0, "Math: div by zero");
                return prod0 / denominator;
            }

            require(denominator > prod1, "Math: overflow");

            uint256 remainder;
            assembly {
                remainder := mulmod(x, y, denominator)
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            uint256 twos = denominator & (~denominator + 1);
            assembly {
                denominator := div(denominator, twos)
                prod0 := div(prod0, twos)
                twos := add(div(sub(0, twos), twos), 1)
            }

            prod0 |= prod1 * twos;

            uint256 inverse = (3 * denominator) ^ 2;
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            result = prod0 * inverse;
            return result;
        }
    }
}

abstract contract ContextUpgradeable {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

abstract contract Initializable {
    bool private _initialized;
    bool private _initializing;

    modifier initializer() {
        require(!_initialized || _initializing, "Initializable: already initialized");
        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    modifier onlyInitializing() {
        require(_initializing, "Initializable: not initializing");
        _;
    }
}

interface IERC20Upgradeable {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC20MetadataUpgradeable is IERC20Upgradeable {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

abstract contract ERC20Upgradeable is Initializable, ContextUpgradeable {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    function __ERC20_init(string memory name_, string memory symbol_) internal onlyInitializing {
        _name = name_;
        _symbol = symbol_;
    }

    function name() internal view virtual returns (string memory) {
        return _name;
    }

    function symbol() internal view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() internal view virtual returns (uint8) {
        return 18;
    }

    function totalSupply() internal view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) internal view virtual returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) internal virtual returns (bool) {
        _transfer(_msgSender(), to, amount);
        return true;
    }

    function allowance(address owner, address spender) internal view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) internal virtual returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) internal virtual returns (bool) {
        _spendAllowance(from, _msgSender(), amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from zero");
        require(to != address(0), "ERC20: transfer to zero");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to zero");
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from zero");
        require(spender != address(0), "ERC20: approve to zero");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}

/// Minimal inlined ERC4626 logic required by `mint()` and `depositETH()`.
abstract contract ERC4626Upgradeable is Initializable, ERC20Upgradeable {
    using MathUpgradeable for uint256;

    IERC20Upgradeable private _asset;
    uint8 private _decimals;

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);

    function __ERC4626_init(IERC20Upgradeable asset_) internal onlyInitializing {
        __ERC4626_init_unchained(asset_);
    }

    function __ERC4626_init_unchained(IERC20Upgradeable asset_) internal onlyInitializing {
        (bool success, uint8 assetDecimals) = _tryGetAssetDecimals(asset_);
        _decimals = success ? assetDecimals : super.decimals();
        _asset = asset_;
    }

    function _tryGetAssetDecimals(IERC20Upgradeable asset_) private returns (bool, uint8) {
        (bool success, bytes memory encodedDecimals) = address(asset_).call(
            abi.encodeWithSelector(IERC20MetadataUpgradeable.decimals.selector)
        );
        if (success && encodedDecimals.length >= 32) {
            uint256 returnedDecimals = abi.decode(encodedDecimals, (uint256));
            if (returnedDecimals <= type(uint8).max) {
                return (true, uint8(returnedDecimals));
            }
        }
        return (false, 0);
    }

    function decimals() internal view virtual override returns (uint8) {
        return _decimals;
    }

    function asset() internal view virtual returns (address) {
        return address(_asset);
    }

    function totalAssets() internal view virtual returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) internal view virtual returns (uint256 shares) {
        return _convertToShares(assets, MathUpgradeable.Rounding.Down);
    }

    function convertToAssets(uint256 shares) internal view virtual returns (uint256 assets) {
        return _convertToAssets(shares, MathUpgradeable.Rounding.Down);
    }

    function maxMint(address) internal view virtual returns (uint256) {
        return type(uint256).max;
    }

    function previewDeposit(uint256 assets) internal view virtual returns (uint256) {
        return _convertToShares(assets, MathUpgradeable.Rounding.Down);
    }

    function previewMint(uint256 shares) internal view virtual returns (uint256) {
        return _convertToAssets(shares, MathUpgradeable.Rounding.Up);
    }

    function mint(uint256 shares, address receiver) public virtual returns (uint256) {
        require(shares <= maxMint(receiver), "ERC4626: mint more than max");

        uint256 assets = previewMint(shares);
        _deposit(_msgSender(), receiver, assets, shares);

        return assets;
    }

    function _convertToShares(
        uint256 assets,
        MathUpgradeable.Rounding rounding
    ) internal view virtual returns (uint256 shares) {
        uint256 supply = totalSupply();
        return
            (assets == 0 || supply == 0)
                ? _initialConvertToShares(assets, rounding)
                : assets.mulDiv(supply, totalAssets(), rounding);
    }

    function _initialConvertToShares(
        uint256 assets,
        MathUpgradeable.Rounding /*rounding*/
    ) internal view virtual returns (uint256 shares) {
        return assets;
    }

    function _convertToAssets(
        uint256 shares,
        MathUpgradeable.Rounding rounding
    ) internal view virtual returns (uint256 assets) {
        uint256 supply = totalSupply();
        return (supply == 0) ? _initialConvertToAssets(shares, rounding) : shares.mulDiv(totalAssets(), supply, rounding);
    }

    function _initialConvertToAssets(
        uint256 shares,
        MathUpgradeable.Rounding /*rounding*/
    ) internal view virtual returns (uint256 assets) {
        return shares;
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal virtual;
}

interface LiquidUnstakePool {
    function swapETHFormpETH(address receiver) external payable returns (uint256);
}

/// @title ETH staking manager and mpETH staking token
/// @author MetaPool
/// @notice Stake ETH and get mpETH as the representation of the portion owned through all the validators
/// @dev Implements ERC4626 and adapts some functions to simulate ETH native token as asset instead of an ERC20. Also allows the deposit of WETH
contract Staking is Initializable, ERC4626Upgradeable {
    /// @dev Parameters used by `_deposit()` and `_getmpETHFromPool()`.
    address payable public liquidUnstakePool;
    address public treasury;
    uint16 public depositFee; // basis points

    uint256 public totalUnderlying;
    uint64 public constant MIN_DEPOSIT = 0.01 ether;

    mapping(address => bool) public whitelistedAccounts;
    bool public whitelistEnabled;

    error DepositTooLow(uint256 _minAmount, uint256 _amountSent);
    error UserNotWhitelisted(address _user);
    error ZeroAddress(string _address);

    modifier checkWhitelisting() {
        if (whitelistEnabled && !whitelistedAccounts[msg.sender])
            revert UserNotWhitelisted(msg.sender);
        _;
    }

    function initialize(
        address payable _liquidPool,
        IERC20MetadataUpgradeable _weth,
        address _treasury
    ) external initializer {
        if (_treasury == address(0)) revert ZeroAddress("treasury");
        require(_weth.decimals() == 18, "wNative token error, implementation for 18 decimals");
        __ERC4626_init(IERC20Upgradeable(_weth));
        __ERC20_init("MetaPoolETH", "mpETH");

        if (_liquidPool == address(0)) revert ZeroAddress("liquidPool");
        liquidUnstakePool = _liquidPool;
        treasury = _treasury;
    }

    /// @notice Deposit ETH
    /// @dev Equivalent to deposit function but for native token
    function depositETH(address _receiver) public payable returns (uint256) {
        uint256 _shares = previewDeposit(msg.value);
        _deposit(msg.sender, _receiver, msg.value, _shares);
        return _shares;
    }

    /// @notice Confirm ETH or WETH deposit
    /// @dev Use ETH or get and convert WETH to ETH, get mpETH from pool and/or mint new mpETH
    function _deposit(
        address _caller,
        address _receiver,
        uint256 _assets,
        uint256 _shares
    ) internal override checkWhitelisting {
        if (_assets < MIN_DEPOSIT) revert DepositTooLow(MIN_DEPOSIT, _assets);
        (uint256 sharesFromPool, uint256 assetsToPool) = _getmpETHFromPool(_shares, address(this));
        uint256 sharesToMint = _shares - sharesFromPool;
        uint256 assetsToAdd = _assets - assetsToPool;

        if (sharesToMint > 0) _mint(address(this), sharesToMint);
        totalUnderlying += assetsToAdd;

        uint256 sharesToUser = _shares;

        if (msg.sender != liquidUnstakePool) {
            uint256 sharesToTreasury = (_shares * depositFee) / 10000;
            _transfer(address(this), treasury, sharesToTreasury);
            sharesToUser -= sharesToTreasury;
        }

        _transfer(address(this), _receiver, sharesToUser);

        emit Deposit(_caller, _receiver, _assets, _shares);
    }

    /// @notice Try to swap ETH for mpETH in the LiquidPool
    /// @dev Avoid try to get mpETH from LiquidPool if this is also the caller bcs LiquidPool.getEthForValidator called on pushToBeacon also calls depositETH, making a loop
    /// @return sharesFromPool Shares (mpETH) received from pool
    /// @return assetsToPool Assets (ETH) sent to pool to swap for shares
    function _getmpETHFromPool(
        uint256 _shares,
        address _receiver
    ) private returns (uint256 sharesFromPool, uint256 assetsToPool) {
        if (msg.sender != liquidUnstakePool) {
            sharesFromPool = MathUpgradeable.min(balanceOf(liquidUnstakePool), _shares);

            if (sharesFromPool > 0) {
                assetsToPool = previewMint(sharesFromPool);
                assert(
                    LiquidUnstakePool(liquidUnstakePool).swapETHFormpETH{value: assetsToPool}(
                        _receiver
                    ) == sharesFromPool
                );
            }
        }
    }
}