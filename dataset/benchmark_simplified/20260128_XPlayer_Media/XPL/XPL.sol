// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Self-contained simplified XPL contract.
 * All previously imported contracts/interfaces are inlined in this file.
 */

contract XPL is XPLBase {
    constructor(
        address _staking,
        address _nodeShareAddress,
        address _pair,
        address _marketingAddress
    ) XPLBase(_pair, _staking, _nodeShareAddress, _marketingAddress) {}
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ERC20 is Context {
    mapping(address => uint256) private _balances;
    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    event Transfer(address indexed from, address indexed to, uint256 value);

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

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function _mint(address account, uint256 value) internal {
        require(account != address(0), "ERC20: mint to the zero address");
        _update(address(0), account, value);
    }

    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            require(fromBalance >= value, "ERC20: insufficient balance");
            unchecked {
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                _totalSupply -= value;
            }
        } else {
            unchecked {
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }
}

interface IUniswapV2Pair {
    function sync() external;
}

/**
 * @dev Simplified XPL base contract.
 * Keeps only DynamicBurnPool and its direct call chain.
 */
abstract contract XPLBase is ERC20, Ownable {
    event AutoEvent(string _evnet_type, uint256 _time);

    address private constant DEAD_ADDRESS =
        0x000000000000000000000000000000000000dEaD;

    IUniswapV2Pair public uniswapV2Pair;
    address public staking;
    address public nodeShareAddress;
    address public marketingAddress;

    uint256 public constant MAX_TOTAL_SUPPLY = 21000000 ether;
    uint256 public MIN_TOTAL_SUPPLY = 1000000 ether;

    constructor(
        address _pair,
        address _staking,
        address _nodeShareAddress,
        address _marketingAddress
    ) ERC20("XPlayer Token", "XPL") Ownable(msg.sender) {
        require(_pair != address(0), "k005");
        uniswapV2Pair = IUniswapV2Pair(_pair);
        staking = _staking;
        nodeShareAddress = _nodeShareAddress;
        marketingAddress = _marketingAddress;

        _mint(owner(), MAX_TOTAL_SUPPLY);
    }

    function DynamicBurnPool(uint256 _amount) public {
        require(
            msg.sender == owner() ||
                msg.sender == staking ||
                msg.sender == nodeShareAddress ||
                msg.sender == marketingAddress,
            "k012"
        );
        if (_shouldFee()) {
            super._update(address(uniswapV2Pair), DEAD_ADDRESS, _amount);
            uniswapV2Pair.sync();
            emit AutoEvent("_autoBurnPoolByOwner", block.timestamp);
        }
    }

    function _shouldFee() private view returns (bool) {
        if (
            balanceOf(address(0)) + balanceOf(DEAD_ADDRESS) >=
            MAX_TOTAL_SUPPLY - MIN_TOTAL_SUPPLY
        ) {
            return false;
        }
        return true;
    }
}