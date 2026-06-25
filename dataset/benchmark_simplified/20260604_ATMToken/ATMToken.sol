// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

address constant _USDT = 0x55d398326f99059fF775485246999027B3197955;
address constant _ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IUniswapV2Pair {
    function balanceOf(address owner) external view returns (uint);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

library Helper {
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        uint256 amountInWithFee = amountIn * 9975;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountIn)
    {
        uint256 numerator = reserveIn * amountOut * 10000;
        uint256 denominator = (reserveOut - amountOut) * 9975;
        amountIn = (numerator / denominator) + 1;
    }
}

abstract contract ERC20 {
    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    string public name;

    string public symbol;

    uint8 public immutable decimals;

    uint256 public immutable totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _totalSupply) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _totalSupply;
        unchecked {
            balanceOf[msg.sender] += _totalSupply;
        }

        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        balanceOf[from] -= amount;
        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }
}

address constant USDT = _USDT;

contract Distributor {
    constructor() {
        IERC20(_USDT).approve(msg.sender, type(uint256).max);
    }
}

abstract contract BaseUSDT {
    bool public inSwapAndLiquify;
    IUniswapV2Router02 constant uniswapV2Router = IUniswapV2Router02(_ROUTER);
    address public immutable uniswapV2Pair;
    Distributor public immutable distributor;

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor() {
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), USDT);
        distributor = new Distributor();
    }
}

abstract contract BaseUSDTWA is BaseUSDT {
    constructor() {
        require(USDT < address(this), "vd");
    }

    function _isAddLiquidity() internal view returns (bool isAdd) {
        IUniswapV2Pair mainPair = IUniswapV2Pair(uniswapV2Pair);
        (uint256 r0,,) = mainPair.getReserves();
        uint256 bal = IUniswapV2Pair(USDT).balanceOf(address(mainPair));
        isAdd = bal >= (r0 + 1 ether);
    }

    function _isRemoveLiquidity() internal view returns (bool isRemove) {
        IUniswapV2Pair mainPair = IUniswapV2Pair(uniswapV2Pair);
        (uint256 r0,,) = mainPair.getReserves();
        uint256 bal = IUniswapV2Pair(USDT).balanceOf(address(mainPair));
        isRemove = r0 > bal;
    }
}

contract ATMToken is BaseUSDTWA, ERC20 {
    uint256 public constant MAX_BURN = 159000000 ether;
    uint256 public constant MAX_HOLDER = 100000 ether;
    address public constant DEAD = address(0xdead);

    bool public presale;
    uint40 public coldTime = 1 minutes;

    address public marketingAddress;
    address public dividendAddress;

    uint256 public swapAtAmount = 200 ether;
    uint256 public numTokensSellRate = 20; // 100%

    mapping(address => uint256) public tOwnedU;
    mapping(address => uint40) public lastBuyTime;

    address public immutable STAKING;

    mapping(address => bool) internal _isExcludedFromFee;
    mapping(uint256 => uint112) private _dailyCloseReserveU;

    constructor(
        address staking_,
        address marketingAddress_,
        address dividendAddress_
    ) ERC20("ATM", "ATM", 18, 210000000 ether) {
        require(staking_ != address(0), "zero staking");
        require(marketingAddress_ != address(0), "zero marketing");
        require(dividendAddress_ != address(0), "zero dividend");

        allowance[address(this)][address(uniswapV2Router)] = type(uint256).max;
        IERC20(USDT).approve(address(uniswapV2Router), type(uint256).max);

        STAKING = staking_;
        marketingAddress = marketingAddress_;
        dividendAddress = dividendAddress_;

        _isExcludedFromFee[msg.sender] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[STAKING] = true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }

        _transfer(from, to, amount);
        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        if (
            inSwapAndLiquify ||
            _isExcludedFromFee[sender] ||
            _isExcludedFromFee[recipient]
        ) {
            super._transfer(sender, recipient, amount);
            return;
        }

        uint256 maxAmount = (balanceOf[sender] * 9999) / 10000;
        if (amount > maxAmount) {
            amount = maxAmount;
        }

        if (uniswapV2Pair == sender) {
            require(presale, "pre");
            if (_isRemoveLiquidity()) {
                //remove liquidity
                uint256 tFee = (amount * 500) / 10000;
                uint256 bFee = burnAmt(tFee);
                if (bFee > 0) {
                    super._transfer(sender, DEAD, bFee);
                }
                if (tFee > bFee) {
                    uint256 mFee = tFee - bFee;
                    super._transfer(sender, address(this), mFee);
                }
                super._transfer(sender, recipient, amount - tFee);
            } else {
                // buy
                (uint112 reserveU, uint112 reserveThis, ) = IUniswapV2Pair(
                    uniswapV2Pair
                ).getReserves();
                _deliveryReserveU(reserveU);
                uint256 amountUBuy = Helper.getAmountIn(
                    amount,
                    reserveU,
                    reserveThis
                );
                tOwnedU[recipient] = tOwnedU[recipient] + amountUBuy;
                lastBuyTime[recipient] = uint40(block.timestamp);
                uint256 tFee = (amount * 500) / 10000;
                uint256 bFee = burnAmt(tFee);
                if (bFee > 0) {
                    super._transfer(sender, DEAD, bFee);
                }
                if (tFee > bFee) {
                    super._transfer(sender, address(this), tFee - bFee);
                }
                super._transfer(sender, recipient, amount - tFee);
            }
        } else if (uniswapV2Pair == recipient) {
            if (_isAddLiquidity()) {
                uint256 tFee = (amount * 3000) / 10000;
                if (tFee > 0) {
                    super._transfer(sender, address(this), tFee);
                }
                super._transfer(sender, recipient, amount - tFee);
            } else {
                require(
                    block.timestamp >= lastBuyTime[sender] + coldTime,
                    "cold"
                );
                //sell
                (uint112 reserveU, uint112 reserveThis, ) = IUniswapV2Pair(
                    uniswapV2Pair
                ).getReserves();
                uint256 tFee = (amount * 500) / 10000;
                uint256 amountUOut = Helper.getAmountOut(
                    amount - tFee,
                    reserveThis,
                    reserveU
                );
                _deliveryReserveU(reserveU);
                uint256 fee;
                if (tOwnedU[sender] >= amountUOut) {
                    unchecked {
                        tOwnedU[sender] = tOwnedU[sender] - amountUOut;
                    }
                } else if (tOwnedU[sender] > 0) {
                    uint256 profitU = amountUOut - tOwnedU[sender];
                    uint256 profitThis = Helper.getAmountOut(
                        profitU,
                        reserveU,
                        reserveThis
                    );
                    fee = profitThis / 4;
                    tOwnedU[sender] = 0;
                } else {
                    uint256 profitThis = Helper.getAmountOut(
                        amountUOut,
                        reserveU,
                        reserveThis
                    );
                    fee = profitThis / 4;
                }
                uint256 totalFee = tFee + fee;
                if (totalFee > 0) {
                    super._transfer(sender, address(this), totalFee);
                }
                uint256 contractTokenBalance = balanceOf[address(this)];
                if (contractTokenBalance > swapAtAmount) {
                    uint256 numTokensSellToFund = (amount * numTokensSellRate) /
                        100;
                    if (numTokensSellToFund > contractTokenBalance) {
                        numTokensSellToFund = contractTokenBalance;
                    }
                    _swapTokenForFund(numTokensSellToFund);
                }
                super._transfer(sender, recipient, amount - totalFee);
            }
        } else {
            // normal transfer
            super._transfer(sender, recipient, amount);
        }
        require(
            uniswapV2Pair == recipient || 
            balanceOf[recipient] <= MAX_HOLDER,
            "max holder"
        );
    }

    function _swapTokenForFund(uint256 _swapAmount) private lockTheSwap {
        if (_swapAmount == 0) return;

        IERC20 usdt = IERC20(USDT);
        uint256 initialBalance = usdt.balanceOf(address(this));
        _swapTokenForUsdt(_swapAmount, address(distributor));

        uint256 distributorBalance = usdt.balanceOf(address(distributor));
        if (distributorBalance > 0) {
            usdt.transferFrom(
                address(distributor),
                address(this),
                distributorBalance
            );
        }

        uint256 newBalance = usdt.balanceOf(address(this)) - initialBalance;

        if (newBalance > 0) {
            uint256 dividendAmount = (newBalance * 2) / 5;
            uint256 marketingAmount = newBalance - dividendAmount;

            if (dividendAmount > 0)
                usdt.transfer(dividendAddress, dividendAmount);
            if (marketingAmount > 0)
                usdt.transfer(marketingAddress, marketingAmount);
        }
    }

    function _swapTokenForUsdt(uint256 tokenAmount, address to) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = address(USDT);
        // make the swap
        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            to,
            block.timestamp
        );
    }

    function burnAmt(
        uint256 _burnAmount
    ) internal view returns (uint256 result) {
        uint256 burnAmount = balanceOf[DEAD];
        if (burnAmount < MAX_BURN) {
            return MAX_BURN - burnAmount > _burnAmount
                ? _burnAmount
                : MAX_BURN - burnAmount;
        }
    }

    function _deliveryReserveU(uint112 reserveU) private {
        uint256 zero = (block.timestamp / 1 days) * 1 days;
        _dailyCloseReserveU[zero] = reserveU;
        if (_dailyCloseReserveU[zero - 1 days] == 0) {
            _dailyCloseReserveU[zero - 1 days] = reserveU;
        }
    }
}
