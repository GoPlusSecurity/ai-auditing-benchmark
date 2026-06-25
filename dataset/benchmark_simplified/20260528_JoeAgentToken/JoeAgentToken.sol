// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

abstract contract ERC20 is Context {
    mapping(address account => uint256) private _balances;
    mapping(address account => mapping(address spender => uint256)) private _allowances;
    uint256 private _totalSupply;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function balanceOf(address account) internal view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 value) internal virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    function approve(address spender, uint256 value) internal returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) revert("ERC20: transfer from the zero address");
        if (to == address(0)) revert("ERC20: transfer to the zero address");
        _update(from, to, value);
    }

    function _mint(address account, uint256 value) internal {
        if (account == address(0)) revert("ERC20: mint to the zero address");
        _update(address(0), account, value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) revert("ERC20: insufficient balance");
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

interface IWETH is IERC20 {
    function withdraw(uint256 wad) external;
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Pair {
    function sync() external;
}

interface IUniswapV2Router {
    function factory() external pure returns (address);

    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IJoeAgentDividendHook {
    function setLPWeight(address account, uint256 weight) external;
}

interface IJoeAgentStakingHook {
    function setWalletLpValue(address user, uint256 newValue) external;
}

interface ITokenDistributor {
    function claimETH(address to, uint256 amount, address weth) external;
}

contract JoeAgentToken is ERC20 {
    uint256 private constant DIVIDEND_WEIGHT_SCALE = 1 ether;
    uint256 private constant TOTAL_SUPPLY = 210_000_000 * 1 ether;
    uint256 private constant BASE_FEE = 10_000;
    address private constant DEAD = 0x000000000000000000000000000000000000dEaD;
    uint256 private constant TRADING_START_TS = 1778157000;
    uint256 private constant LAUNCH_TIER_STEP = 1 hours;
    uint256 private constant DEFAULT_EARLY_TRADING_DURATION = 5 minutes;

    struct Fee {
        uint256 high;
        uint256 middle;
        uint256 normal;
    }

    struct LPInfo {
        uint256 lpAmount;
        uint256 lastAddLpTime;
    }

    uint256 private dayDuration;
    uint256 private lpWeightBase;
    uint256 private startTradeBlock;
    uint256 private startTradeTime;
    uint256 private limitAmount;
    uint256 private lastBurnDay;
    uint256 private dailyBurnRate;
    uint256 private minSwapOut;
    address private WETH;
    address private mainPair;
    address private dividendContract;
    address private stakingContract;
    Fee private buyFee;
    Fee private sellFee;
    Fee private transferFee;
    Fee private removeFee;
    IUniswapV2Router private uniswapV2Router;
    ITokenDistributor private tokenDistributor;
    mapping(address => bool) private pairs;
    mapping(address => bool) private whiteList;
    mapping(address => bool) private blackList;
    mapping(address => LPInfo) private lpInfo;
    mapping(address => uint256) private lpPrincipalValue;
    mapping(address => bool) private tradingWhitelist;
    uint256 private earlyTradingDuration;

    bool private inSwap;
    modifier lockTheSwap() {
        inSwap = true;
        _;
        inSwap = false;
    }

    event DailyBurn(uint256 day, uint256 amount);
    event TaxCollected(address from, uint256 amount, string taxType);
    event LPValueObserved(address indexed account, uint256 lpValue, bool registrySyncOk);
    event FeeSwapProcessed(uint256 tokenAmount, uint256 nativeAmount);
    event ProtocolLpPositionUpdated(address indexed account, uint256 lpUnits, uint256 lpValue);
    event MainPairCreated(address indexed pair);

    constructor(
        address initOwner,
        address router,
        address weth,
        address distributor
    ) {
        dailyBurnRate = 10;
        minSwapOut = 0.01 ether;
        dayDuration = 1 days;
        lpWeightBase = 1 ether;

        WETH = weth;
        uniswapV2Router = IUniswapV2Router(router);

        _mint(initOwner, TOTAL_SUPPLY);

        tokenDistributor = ITokenDistributor(distributor);

        whiteList[address(this)] = true;
        whiteList[address(0)] = true;
        whiteList[DEAD] = true;
        whiteList[initOwner] = true;
        whiteList[address(tokenDistributor)] = true;

        buyFee = Fee(1500, 200, 200);
        sellFee = Fee(1500, 1000, 200);
        transferFee = Fee(0, 0, 200);
        removeFee = Fee(0, 0, 200);

        limitAmount = type(uint256).max;
    }

    function _enforceEarlyWindow(address party) internal view {
        uint256 d = earlyTradingDuration;
        if (d == 0) d = DEFAULT_EARLY_TRADING_DURATION;
        if (block.timestamp < startTradeTime + d) {
            require(tradingWhitelist[party], "early window: not whitelisted");
        }
    }

    function transfer(address to, uint256 value) internal virtual override returns (bool) {
        address from = _msgSender();
        uint256 newValue = _beforeTokenTransfer(from, to, value);
        _transfer(from, to, newValue);
        return true;
    }

    function _ensureMainPair() internal {
        if (mainPair != address(0)) return;
        address factoryPair = IUniswapV2Factory(uniswapV2Router.factory())
            .getPair(address(this), WETH);
        if (factoryPair != address(0)) {
            mainPair = factoryPair;
            pairs[factoryPair] = true;
            emit MainPairCreated(factoryPair);
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 value
    ) internal returns (uint256 newValue) {
        _ensureMainPair();

        if (startTradeBlock == 0
            && block.timestamp >= TRADING_START_TS
            && (pairs[from] || pairs[to])) {
            startTradeBlock = block.number;
            startTradeTime = TRADING_START_TS;
        }

        if (whiteList[from] || whiteList[to] || inSwap) {
            return value;
        }
        require(!blackList[from], "blacklisted");

        newValue = value;
        uint256 feeAmount;

        if (pairs[from]) {
            require(startTradeBlock > 0, "trading not started");
            _enforceEarlyWindow(to);
            feeAmount = tradingWhitelist[to] ? 0 : _calcFee(buyFee, value);
            if (feeAmount > 0) {
                _transfer(from, address(this), feeAmount);
                emit TaxCollected(from, feeAmount, "buy");
            }
        } else if (pairs[to]) {
            require(startTradeBlock > 0, "trading not started");
            _enforceEarlyWindow(from);
            feeAmount = tradingWhitelist[from] ? 0 : _calcFee(sellFee, value);
            if (feeAmount > 0) {
                _transfer(from, address(this), feeAmount);
                emit TaxCollected(from, feeAmount, "sell");
            }
            if (!inSwap && balanceOf(address(this)) >= minSwapOut) {
                _swapTokenForBNB();
            }
        } else {
            feeAmount = _calcFee(transferFee, value);
            if (feeAmount > 0) {
                _transfer(from, DEAD, feeAmount);
                emit TaxCollected(from, feeAmount, "transfer_burn");
            }
        }

        newValue = value - feeAmount;

        if (!pairs[to] && limitAmount > 0) {
            require(balanceOf(to) + newValue <= limitAmount, "exceeds wallet limit");
        }

        if (!pairs[from] && !pairs[to]) {
            _autoBurnDaily();
        }

        return newValue;
    }

    function _syncLPWeight(address account) internal {
        uint256 lpValue = quoteLPValue(account);
        uint256 lpWeight = quoteLPWeight(account);
        if (dividendContract != address(0)) {
            try IJoeAgentDividendHook(dividendContract).setLPWeight(account, lpWeight) {} catch {}
        }

        bool registrySyncOk = false;
        if (stakingContract != address(0)) {
            try IJoeAgentStakingHook(stakingContract).setWalletLpValue(account, lpValue) {
                registrySyncOk = true;
            } catch {}
        }

        emit LPValueObserved(account, lpValue, registrySyncOk);
    }

    function quoteLPValue(address account) internal view returns (uint256) {
        return lpPrincipalValue[account];
    }

    function quoteLPWeight(address account) internal view returns (uint256) {
        return _quoteLPWeight(lpPrincipalValue[account]);
    }

    function _quoteLPWeight(uint256 lpValue) internal view returns (uint256) {
        if (lpValue == 0 || lpWeightBase == 0) return 0;
        return (lpValue * DIVIDEND_WEIGHT_SCALE) / lpWeightBase;
    }

    function _calcFee(Fee memory fee, uint256 amount) internal view returns (uint256) {
        if (startTradeTime == 0) return 0;

        uint256 elapsed = block.timestamp - startTradeTime;
        uint256 feeRate;

        bool useTier = (fee.high > 0 || fee.middle > 0);

        if (useTier) {
            if      (elapsed < LAUNCH_TIER_STEP)       feeRate = 1500;
            else if (elapsed < 2 * LAUNCH_TIER_STEP)   feeRate = 1000;
            else if (elapsed < 3 * LAUNCH_TIER_STEP)   feeRate = 500;
            else if (elapsed < 4 * LAUNCH_TIER_STEP)   feeRate = 200;
            else                                        feeRate = fee.normal;
        } else {
            feeRate = fee.normal;
        }

        if (feeRate == 0) return 0;
        return amount * feeRate / BASE_FEE;
    }

    function _swapTokenForBNB() private lockTheSwap {
        uint256 tokenBalance = balanceOf(address(this));
        if (tokenBalance == 0) return;

        uint256 burnAmount = tokenBalance / 2;
        if (burnAmount > 0) {
            _transfer(address(this), DEAD, burnAmount);
            emit TaxCollected(address(this), burnAmount, "fee_burn");
        }
        uint256 swapAmount = tokenBalance - burnAmount;
        if (swapAmount == 0) return;

        uint256 nativeBefore = dividendContract == address(0) ? 0 : dividendContract.balance;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WETH;

        _approve(address(this), address(uniswapV2Router), swapAmount);

        try uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            swapAmount,
            0,
            path,
            address(tokenDistributor),
            block.timestamp + 1
        ) {} catch {}

        if (dividendContract != address(0)) {
            uint256 nativeBal = address(tokenDistributor).balance;
            if (nativeBal > 0) {
                tokenDistributor.claimETH(dividendContract, nativeBal, WETH);
            }
        }

        uint256 nativeAfter = dividendContract == address(0) ? 0 : dividendContract.balance;
        emit FeeSwapProcessed(swapAmount, nativeAfter - nativeBefore);
    }

    function _autoBurnDaily() internal {
        uint256 today = block.timestamp / dayDuration;
        if (today <= lastBurnDay) return;
        if (startTradeTime == 0) return;

        uint256 pairBalance = balanceOf(mainPair);
        if (pairBalance == 0) return;

        uint256 burnAmount = pairBalance * dailyBurnRate / BASE_FEE;
        if (burnAmount == 0) return;

        lastBurnDay = today;
        _transfer(mainPair, DEAD, burnAmount);
        IUniswapV2Pair(mainPair).sync();

        emit DailyBurn(today, burnAmount);
    }

    function removeLiquidityViaContract(
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        uint256 deadline
    ) external lockTheSwap {
        _removeLiquidityViaContract(msg.sender, liquidity, amountTokenMin, amountETHMin, deadline);
    }

    function _removeLiquidityViaContract(
        address user,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        uint256 deadline
    ) internal {
        require(liquidity > 0, "zero liquidity");
        require(lpInfo[user].lpAmount >= liquidity, "insufficient lp units");
        require(lpInfo[user].lastAddLpTime != block.timestamp, "cannot add/remove in same block");

        IERC20(mainPair).approve(address(uniswapV2Router), liquidity);

        uint256 joeBefore = balanceOf(address(this));
        uint256 ethBefore = address(this).balance;
        uint256 lpAmountBefore = lpInfo[user].lpAmount;
        uint256 principalBefore = lpPrincipalValue[user];

        uniswapV2Router.removeLiquidityETHSupportingFeeOnTransferTokens(
            address(this),
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );

        uint256 joeReceived = balanceOf(address(this)) - joeBefore;
        uint256 ethReceived = address(this).balance - ethBefore;

        uint256 feeAmount = _calcFee(removeFee, joeReceived);
        uint256 payout = joeReceived - feeAmount;
        emit TaxCollected(user, feeAmount, "remove_lp");

        if (payout > 0) {
            _transfer(address(this), user, payout);
        }
        if (ethReceived > 0) {
            (bool ok, ) = user.call{value: ethReceived}("");
            require(ok, "eth transfer failed");
        }

        uint256 principalReduction = lpAmountBefore == 0 ? 0 : (principalBefore * liquidity) / lpAmountBefore;
        lpInfo[user].lpAmount = lpAmountBefore - liquidity;
        lpPrincipalValue[user] = principalBefore > principalReduction ? principalBefore - principalReduction : 0;
        _syncLPWeight(user);
        emit ProtocolLpPositionUpdated(user, lpInfo[user].lpAmount, quoteLPValue(user));
    }

    receive() external payable {}
}
