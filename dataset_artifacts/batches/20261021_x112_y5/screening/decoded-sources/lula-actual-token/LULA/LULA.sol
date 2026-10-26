// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {_USDT, _ROUTER} from "./Const.sol";

contract Distributor {
    constructor() {
        IERC20(_USDT).approve(msg.sender, type(uint256).max);
    }
}

contract LULA is Ownable {
    string public constant name = "LULA";
    string public constant symbol = "LULA";
    uint8 public constant decimals = 18;
    uint256 public immutable totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    IUniswapV2Router02 public constant uniswapV2Router = IUniswapV2Router02(_ROUTER);
    address public immutable uniswapV2Pair;
    Distributor public immutable distributor;

    bool public inSwapAndLiquify;
    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    uint256 public constant RATE_BASE = 10000;

    bool public buyEnabled;
    uint40 public cooldownTime = 1 minutes;

    mapping(address => bool) public isExcludedFromFee;
    mapping(address => uint40) public lastBuyTime;

    uint256 public buyTaxRate = 300;
    uint256 public sellTaxRate = 300;
    uint256 public sellLpRate = 200;

    uint256 public swapAtAmount = 100 ether;
    uint256 public amountLPFee;

    uint256 public swapSlippageBps = 1000;

    address public rentalContract;
    address public lpPool;

    constructor() Ownable(msg.sender) {
        totalSupply = 23_000_000 ether;
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);

        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
            .createPair(address(this), _USDT);

        distributor = new Distributor();

        allowance[address(this)][address(uniswapV2Router)] = type(uint256).max;
        IERC20(_USDT).approve(address(uniswapV2Router), type(uint256).max);

        isExcludedFromFee[msg.sender] = true;
        isExcludedFromFee[address(this)] = true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        if (
            inSwapAndLiquify ||
            isExcludedFromFee[sender] ||
            isExcludedFromFee[recipient]
        ) {
            _basicTransfer(sender, recipient, amount);
            return;
        }

        if (uniswapV2Pair == sender) {
            require(buyEnabled, "Buy not enabled");
            _handleBuy(sender, recipient, amount);
        } else if (uniswapV2Pair == recipient) {
            _handleSell(sender, recipient, amount);
        } else {
            _basicTransfer(sender, recipient, amount);
        }
    }

    function _handleBuy(address sender, address recipient, uint256 amount) internal {
        lastBuyTime[recipient] = uint40(block.timestamp);

        uint256 taxFee = amount * buyTaxRate / RATE_BASE;
        uint256 actual = amount - taxFee;

        _basicTransfer(sender, rentalContract, taxFee);
        _basicTransfer(sender, recipient, actual);
    }

    function _handleSell(address sender, address recipient, uint256 amount) internal {
        require(block.timestamp >= lastBuyTime[sender] + cooldownTime, "Cooldown active");

        uint256 taxFee = amount * sellTaxRate / RATE_BASE;
        uint256 lpFee = amount * sellLpRate / RATE_BASE;
        uint256 actual = amount - taxFee - lpFee;

        _basicTransfer(sender, rentalContract, taxFee);
        _basicTransfer(sender, address(this), lpFee);
        amountLPFee += lpFee;

        if (amountLPFee >= swapAtAmount && !inSwapAndLiquify) {
            _swapAndLiquify();
        }

        _basicTransfer(sender, recipient, actual);
    }

    function _basicTransfer(address from, address to, uint256 amount) internal {
        balanceOf[from] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _swapAndLiquify() internal lockTheSwap {
        uint256 tokens = amountLPFee;
        amountLPFee = 0;

        uint256 half = tokens / 2;
        uint256 otherHalf = tokens - half;

        uint256 initialBalance = IERC20(_USDT).balanceOf(address(this));
        _swapTokensForUSDT(half);
        uint256 newBalance = IERC20(_USDT).balanceOf(address(this)) - initialBalance;

        uniswapV2Router.addLiquidity(
            address(this),
            _USDT,
            otherHalf,
            newBalance,
            0,
            0,
            lpPool,
            block.timestamp
        );
    }

    function _swapTokensForUSDT(uint256 tokenAmount) internal {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _USDT;
        uint256 minOut;
        try uniswapV2Router.getAmountsOut(tokenAmount, path) returns (uint256[] memory outs) {
            minOut = outs[1] * (RATE_BASE - swapSlippageBps) / RATE_BASE;
        } catch {
            minOut = 0;
        }
        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            minOut,
            path,
            address(distributor),
            block.timestamp
        );
        IERC20(_USDT).transferFrom(
            address(distributor),
            address(this),
            IERC20(_USDT).balanceOf(address(distributor))
        );
    }

    function setBuyEnabled(bool enabled) external onlyOwner {
        buyEnabled = enabled;
    }

    function setExcludedFromFee(address account, bool excluded) external onlyOwner {
        isExcludedFromFee[account] = excluded;
    }

    function setCooldownTime(uint40 time) external onlyOwner {
        cooldownTime = time;
    }

    function setBuyTaxRate(uint256 rate) external onlyOwner {
        require(rate <= 1000, "Max 10%");
        buyTaxRate = rate;
    }

    function setSellTaxRate(uint256 rate) external onlyOwner {
        require(rate <= 1000, "Max 10%");
        sellTaxRate = rate;
    }

    function setSellLpRate(uint256 rate) external onlyOwner {
        require(rate <= 1000, "Max 10%");
        sellLpRate = rate;
    }

    function setSwapAtAmount(uint256 amount) external onlyOwner {
        swapAtAmount = amount;
    }

    function setSwapSlippageBps(uint256 bps) external onlyOwner {
        require(bps <= 3000, "Max 30%");
        swapSlippageBps = bps;
    }

    function initialize(address _rental, address _lpPool) external onlyOwner {
        require(rentalContract == address(0), "Already initialized");
        require(_rental != address(0) && _lpPool != address(0), "Zero address");
        rentalContract = _rental;
        lpPool = _lpPool;
        isExcludedFromFee[_rental] = true;
    }

    function setLpPool(address _lpPool) external onlyOwner {
        require(_lpPool != address(0), "Zero address");
        lpPool = _lpPool;
    }

    function recycle(uint256 amount) external {
        require(msg.sender == rentalContract, "Only Rental");
        uint256 pairBalance = balanceOf[uniswapV2Pair];
        uint256 maxTake = pairBalance / 3;
        uint256 actual = amount >= maxTake ? maxTake : amount;
        if (actual == 0) return;
        _basicTransfer(uniswapV2Pair, rentalContract, actual);
        IUniswapV2Pair(uniswapV2Pair).sync();
    }

    function rescueToken(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }
}
