// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "zero");
        _transferOwnership(newOwner);
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IUniswapV2Pair {
    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function sync() external;
}

interface IUniswapV2Factory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);

    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);
}

/// @title NemTokenV2
/// @notice NemToken economics with dump defenses and admin-controlled buy/sell switches.
///         - Base sell trade tax 5%; anti-dump: drop>=5% → tax = drop*2 (e.g. -25% → 50%)
///         - LP sell-destroy rate adjustable (default 70% of sell net, max 300%); flushed amount all burned
///         - MIN_HOLD auto-reserved on wallet transfer/sell (input full bal → send bal-1)
///         - buyEnabled / sellEnabled can be set true or false by tradingAdmin (not one-way)
contract NemTokenV2 is Ownable {
    string public constant name = "Newmont";
    string public constant symbol = "NEM";
    uint8 public constant decimals = 18;

    uint256 public constant TOTAL_SUPPLY = 210_000_000 * 1e18;
    uint256 public constant BUY_ENABLE_CIRCULATING = 2_100_000 * 1e18;
    uint256 public constant MIN_HOLD = 1e18;

    /// @dev Base sell trade tax = 5% (normal slippage)
    uint256 public constant TRADE_TAX_BPS = 500;
    /// @dev Anti-dump starts after 5% drop; taxBps = dropBps * 2
    uint256 public constant ANTI_DUMP_TRIGGER_BPS = 500;
    uint256 public constant ANTI_DUMP_MAX_BPS = 6000;
    /// @dev LP sell-destroy vs sell net: default 70%, max 300%
    uint256 public constant MAX_LP_SELL_DESTROY_BPS = 30000;
    /// @dev Single flush cannot pull more than 20% of LP token balance
    uint256 public constant LP_RECYCLE_MAX_POOL_BPS = 2000;

    uint256 public constant REFERENCE_DAY_OFFSET = 8 hours;
    address public constant deadAddress =
        0x000000000000000000000000000000000000dEaD;
    address public constant usdt = 0x55d398326f99059fF775485246999027B3197955;
    /// @dev PancakeSwap V2 Factory (BSC). Pair is created/bound once in constructor and never changed.
    address public constant factory =
        0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;

    uint256 public deflationRateBps = 210;
    uint256 public destroyRateBps = 50;
    uint256 public constant MAX_DEFLATION_BPS = 5000;
    /// @dev Of each sell net accrued to pending: pull this % from LP and burn (default 7000=70%).
    ///      0 = disable pool pull (pending still cleared on flush). Flushed tokens are 100% burned.
    uint256 public lpSellDestroyRateBps = 7000;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    mapping(address => uint256) public cumulativeBought;
    mapping(address => uint256) public cumulativeSold;

    address public immutable pair;

    address public deflationContract;

    address public tradingAdmin;

    address public taxAdmin;
    /// @dev Ops admin: rotates all role addresses; deflation/trading/tax/withdraw cannot replace themselves.
    address public contractAdmin;
    address public withdrawContract;

    uint256 public lastDeflationDay;
    uint256 public totalDeflated;
    mapping(uint256 => uint256) public dailyDeflationAmount;
    mapping(uint256 => uint256) public dailyDeflationRateBps;
    mapping(uint256 => uint256) public dailyContractKeepAmount;
    mapping(uint256 => uint256) public dailyStaticFundAmount;
    mapping(uint256 => uint256) public dailyDestroyAmount;

    uint256 public totalSellDestroyed;
    uint256 public totalSellContractKept;
    mapping(uint256 => uint256) public dailySellDestroyAmount;
    mapping(uint256 => uint256) public dailySellContractKeepAmount;
    uint256 public pendingLpSellRecycle;

    /// @dev Admin fixed-amount pool deflation: at most 2 times for the contract lifetime.
    uint256 public constant MAX_MANUAL_POOL_DEFLATIONS = 2;
    uint256 public manualPoolDeflationCount;
    uint256 public totalManualPoolDeflated;
    mapping(uint256 => uint256) public manualPoolDeflationAmount;

    address public tradeCommunityAddr;
    address public tradeFoundationAddr;
    address public tradePlatformAddr;
    address public tradeChildAddr;

    address public profitCommunityAddr;
    address public profitFoundationAddr;
    address public profitPlatformAddr;
    address public profitChildAddr;

    address public antiDumpAddr;

    mapping(uint8 => uint256) private _taxAccrued;
    mapping(uint256 => mapping(uint8 => uint256)) private _dailyTax;

    bool public buyEnabled;
    bool public sellEnabled = true;
 
    uint256 public referencePrice;
    uint256 public lastReferenceDay;

    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isBuyWhitelisted;
    mapping(address => bool) public isSellWhitelisted;
    mapping(address => bool) public isBuyFeeExempt;
    mapping(address => bool) public isSellFeeExempt;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event BuyEnabled(uint256 circulating);
    event SellEnabled(bool enabled);
    event BuyWhitelistUpdated(address indexed account, bool enabled);
    event SellWhitelistUpdated(address indexed account, bool enabled);
    event BuyFeeExemptUpdated(address indexed account, bool enabled);
    event SellFeeExemptUpdated(address indexed account, bool enabled);
    event ReferencePriceUpdated(uint256 price);
    event TaxAddressesUpdated();
    event TaxAccrued(
        uint8 indexed poolType,
        uint256 amount,
        uint256 totalAccrued
    );
    event DailyTaxAccrued(
        uint256 indexed day,
        uint8 indexed poolType,
        uint256 amount,
        uint256 dayTotal
    );
    event ProfitTaxTaken(
        address indexed account,
        uint256 profitAmount,
        uint256 taxAmount
    );
    event TradeStatsUpdated(
        address indexed account,
        uint256 bought,
        uint256 sold
    );
    event DeflationContractUpdated(
        address indexed previous,
        address indexed current
    );
    event WithdrawContractUpdated(
        address indexed previous,
        address indexed current
    );
    event DeflationRateUpdated(uint256 rateBps);
    event DeflationDestroyRateUpdated(uint256 destroyBps);
    event LpSellDestroyRateUpdated(uint256 rateBps);
    event DailyDeflation(
        uint256 indexed day,
        address indexed pool,
        uint256 rateBps,
        uint256 destroyBps,
        uint256 poolBefore,
        uint256 amount,
        uint256 contractKeepAmt,
        uint256 destroyAmt
    );
    /// @notice Admin pulls a fixed NEM amount from the LP to this token contract (max 2 times).
    event ManualPoolDeflation(
        uint256 indexed index,
        address indexed caller,
        address indexed pool,
        uint256 poolBefore,
        uint256 amount,
        uint256 remainingQuota
    );
    event SellRecycled(
        uint256 indexed day,
        uint256 destroyAmt,
        uint256 keepAmt,
        uint256 dayDestroyTotal,
        uint256 dayKeepTotal
    );
    event LpSellRecycleFlushed(
        uint256 pendingBefore,
        uint256 rateBps,
        uint256 destroyedAmt,
        uint256 poolBal
    );
    event SystemWithdraw(address indexed to, uint256 amount);
    event DeadRescued(address indexed to, uint256 amount);
    event TradingAdminUpdated(
        address indexed previous,
        address indexed current
    );
    event TaxAdminUpdated(address indexed previous, address indexed current);
    event ContractAdminUpdated(
        address indexed previous,
        address indexed current
    );
    event BnbReceived(address indexed from, uint256 amount);
    event BnbWithdrawn(
        address indexed caller,
        address indexed to,
        uint256 amount
    );

    modifier onlyTradingAdmin() {
        require(msg.sender == tradingAdmin, "only trading");
        _;
    }

    modifier onlyTaxAdmin() {
        require(msg.sender == taxAdmin, "only tax");
        _;
    }

    modifier onlyContractAdminOrOwner() {
        require(
            msg.sender == owner() || msg.sender == contractAdmin,
            "not owner"
        );
        _;
    }

    modifier onlyOwnerOrWithdraw() {
        require(
            msg.sender == owner() ||
                msg.sender == contractAdmin ||
                msg.sender == withdrawContract,
            "not owner/admin/withdraw"
        );
        _;
    }

    constructor(address recipient) {
        require(recipient != address(0), "zero");
        totalSupply = TOTAL_SUPPLY;
        balanceOf[recipient] = TOTAL_SUPPLY;
        emit Transfer(address(0), recipient, TOTAL_SUPPLY);

        address p = IUniswapV2Factory(factory).getPair(address(this), usdt);
        if (p == address(0)) {
            p = IUniswapV2Factory(factory).createPair(address(this), usdt);
        }
        require(p != address(0), "pair zero");
        pair = p;

        isExcludedFromFee[address(this)] = true;
        isExcludedFromFee[recipient] = true;
        isExcludedFromFee[deadAddress] = true;
        isExcludedFromFee[p] = false;
        isBuyWhitelisted[recipient] = true;
        isSellWhitelisted[recipient] = true;
        isBuyFeeExempt[recipient] = true;
        isBuyFeeExempt[address(this)] = true;
        isSellFeeExempt[recipient] = true;
        isSellFeeExempt[address(this)] = true;
        isSellFeeExempt[deadAddress] = true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) external returns (bool) {
        _approve(
            msg.sender,
            spender,
            allowance[msg.sender][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) external returns (bool) {
        uint256 current = allowance[msg.sender][spender];
        require(current >= subtractedValue, "allowance");
        unchecked {
            _approve(msg.sender, spender, current - subtractedValue);
        }
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "allowance");
            unchecked {
                _approve(from, msg.sender, allowed - amount);
            }
        }
        _transfer(from, to, amount);
        return true;
    }

    function _approve(
        address owner_,
        address spender,
        uint256 amount
    ) internal {
        allowance[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    function circulatingSupply() public view returns (uint256) {
        uint256 deadBal = balanceOf[deadAddress];
        return totalSupply > deadBal ? totalSupply - deadBal : 0;
    }

    function maybeBuyEnabled() public view returns (bool) {
        return buyEnabled || circulatingSupply() <= BUY_ENABLE_CIRCULATING;
    }

    function currentPairPrice() public view returns (uint256) {
        if (pair == address(0)) return 0;
        (uint112 r0, uint112 r1, ) = IUniswapV2Pair(pair).getReserves();
        address t0 = IUniswapV2Pair(pair).token0();
        uint256 tokenReserve = t0 == address(this) ? uint256(r0) : uint256(r1);
        uint256 usdtReserve = t0 == address(this) ? uint256(r1) : uint256(r0);
        if (tokenReserve == 0) return 0;
        return (usdtReserve * 1e18) / tokenReserve;
    }

    function taxAccrued(uint8 poolType) public view returns (uint256) {
        return _taxAccrued[poolType];
    }

    function getDailyTax(
        uint256 day,
        uint8 poolType
    ) public view returns (uint256) {
        return _dailyTax[day][poolType];
    }

    function getDailyTaxBundle(
        uint256 day
    )
        external
        view
        returns (
            uint256 tradeCommunity,
            uint256 tradeFoundation,
            uint256 tradePlatform,
            uint256 tradeChild,
            uint256 profitCommunity,
            uint256 profitFoundation,
            uint256 profitPlatform,
            uint256 profitChild,
            uint256 antiDump,
            uint256 tradeTotal,
            uint256 profitTotal
        )
    {
        tradeCommunity = _dailyTax[day][1];
        tradeFoundation = _dailyTax[day][2];
        tradePlatform = _dailyTax[day][3];
        tradeChild = _dailyTax[day][4];
        profitCommunity = _dailyTax[day][5];
        profitFoundation = _dailyTax[day][6];
        profitPlatform = _dailyTax[day][7];
        profitChild = _dailyTax[day][8];
        antiDump = _dailyTax[day][9];
        tradeTotal =
            tradeCommunity +
            tradeFoundation +
            tradePlatform +
            tradeChild;
        profitTotal =
            profitCommunity +
            profitFoundation +
            profitPlatform +
            profitChild;
    }

    function tradeStats(
        address account
    )
        external
        view
        returns (uint256 bought, uint256 sold, uint256 unrealizedProfit)
    {
        bought = cumulativeBought[account];
        sold = cumulativeSold[account];
        unrealizedProfit = sold > bought ? sold - bought : 0;
    }

    function currentDay() public view returns (uint256) {
        return (block.timestamp + 8 hours) / 1 days;
    }

    function referenceDay() public view returns (uint256) {
        return (block.timestamp - REFERENCE_DAY_OFFSET) / 1 days;
    }

    function needsReferencePriceUpdate() public view returns (bool) {
        return lastReferenceDay < referenceDay();
    }

    function pendingDeflation(uint256 rateBps) public view returns (uint256) {
        if (pair == address(0)) return 0;
        if (rateBps == 0) rateBps = deflationRateBps;
        if (rateBps == 0) return 0;
        return (balanceOf[pair] * rateBps) / 10000;
    }

    function canDeflateToday(
        uint256 rateBps,
        uint256 destroyBps
    ) public view returns (bool ok, string memory reason) {
        if (pair == address(0)) return (false, "pair zero");
        if (deadAddress == address(0)) return (false, "dead zero");
        if (rateBps == 0 && destroyBps == 0) {
            rateBps = deflationRateBps;
            destroyBps = destroyRateBps;
        } else if (rateBps == 0) {
            rateBps = deflationRateBps;
        }
        if (rateBps == 0 || rateBps > MAX_DEFLATION_BPS)
            return (false, "bad rate");
        if (destroyBps > rateBps || destroyBps > MAX_DEFLATION_BPS)
            return (false, "bad destroy");
        if (lastDeflationDay >= currentDay()) return (false, "already done");
        uint256 poolBal = balanceOf[pair];
        if (poolBal == 0) return (false, "pool empty");
        if ((poolBal * rateBps) / 10000 == 0) return (false, "amount zero");
        return (true, "");
    }

    /// @notice Preview whether admin fixed-amount pool deflation can run.
    function canManualPoolDeflate(
        uint256 amount
    ) public view returns (bool ok, string memory reason) {
        if (pair == address(0)) return (false, "pair zero");
        if (manualPoolDeflationCount >= MAX_MANUAL_POOL_DEFLATIONS)
            return (false, "limit reached");
        if (amount == 0) return (false, "amount zero");
        uint256 poolBal = balanceOf[pair];
        if (poolBal == 0) return (false, "pool empty");
        if (amount > poolBal) return (false, "exceeds pool");
        return (true, "");
    }

    function getDailyDeflation(
        uint256 day
    ) external view returns (uint256 amount, uint256 rateBps, bool executed) {
        amount = dailyDeflationAmount[day];
        rateBps = dailyDeflationRateBps[day];
        executed = amount > 0;
    }

    function getDailyDeflationSplit(
        uint256 day
    )
        external
        view
        returns (
            uint256 contractKeepAmt,
            uint256 staticFundAmt,
            uint256 destroyAmt
        )
    {
        contractKeepAmt = dailyContractKeepAmount[day];
        staticFundAmt = dailyStaticFundAmount[day];
        destroyAmt = dailyDestroyAmount[day];
    }

    function getDailySellRecycle(
        uint256 day
    ) external view returns (uint256 destroyAmt, uint256 keepAmt) {
        destroyAmt = dailySellDestroyAmount[day];
        keepAmt = dailySellContractKeepAmount[day];
    }

    function initDeflationContract(
        address addr
    ) external onlyContractAdminOrOwner {
        require(deflationContract == address(0), "initialized");
        _setDeflationContract(addr);
    }

    /// @notice One-time first bind of ops admin (multisig / ops). Requires contractAdmin == address(0).
    /// @dev After init, use setContractAdmin to rotate. Caller must be owner (while contractAdmin is still zero).
    function initContractAdmin(address addr) external onlyContractAdminOrOwner {
        require(contractAdmin == address(0), "initialized");
        require(addr != address(0), "zero");
        contractAdmin = addr;
        emit ContractAdminUpdated(address(0), addr);
        tradingAdmin = addr;
        emit TradingAdminUpdated(address(0), addr);
        taxAdmin = addr;
        emit TaxAdminUpdated(address(0), addr);
    }

    function setContractAdmin(address addr) external onlyContractAdminOrOwner {
        require(addr != address(0), "zero");
        address prev = contractAdmin;
        contractAdmin = addr;
        emit ContractAdminUpdated(prev, addr);
        tradingAdmin = addr;
        emit TradingAdminUpdated(address(0), addr);
        taxAdmin = addr;
        emit TaxAdminUpdated(address(0), addr);
    }

    function setDeflationContract(
        address addr
    ) external onlyContractAdminOrOwner {
        _setDeflationContract(addr);
    }

    function setWithdrawContract(
        address addr
    ) external onlyContractAdminOrOwner {
        require(addr != address(0), "zero");
        address prev = withdrawContract;
        withdrawContract = addr;
        isExcludedFromFee[addr] = true;
        isSellFeeExempt[addr] = true;
        emit WithdrawContractUpdated(prev, addr);
    }

    function setTradingAdmin(address addr) external onlyContractAdminOrOwner {
        require(addr != address(0), "zero");
        address prev = tradingAdmin;
        tradingAdmin = addr;
        emit TradingAdminUpdated(prev, addr);
    }

    function setTaxAdmin(address addr) external onlyContractAdminOrOwner {
        require(addr != address(0), "zero");
        address prev = taxAdmin;
        taxAdmin = addr;
        emit TaxAdminUpdated(prev, addr);
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        require(newOwner != address(0), "zero");
        _transferOwnership(newOwner);
    }

    function renounceOwnership() public override onlyOwner {
        _transferOwnership(address(0));
    }

    function _setDeflationContract(address addr) internal {
        require(addr != address(0), "zero");
        address prev = deflationContract;
        deflationContract = addr;
        isExcludedFromFee[addr] = true;
        emit DeflationContractUpdated(prev, addr);
    }

    function setDeflationRateBps(
        uint256 rateBps
    ) external onlyContractAdminOrOwner {
        require(rateBps > 0 && rateBps <= MAX_DEFLATION_BPS, "bad rate");
        require(destroyRateBps <= rateBps, "destroy gt rate");
        deflationRateBps = rateBps;
        emit DeflationRateUpdated(rateBps);
    }

    function setDestroyRateBps(
        uint256 destroyBps
    ) external onlyContractAdminOrOwner {
        require(destroyBps <= MAX_DEFLATION_BPS, "bad destroy");
        require(destroyBps <= deflationRateBps, "destroy gt rate");
        destroyRateBps = destroyBps;
        emit DeflationDestroyRateUpdated(destroyBps);
    }

    /// @notice LP sell-destroy rate vs sell net (bps). Default 7000=70%, max 30000=300%. Pass 0 to disable pool pull.
    function setLpSellDestroyRateBps(
        uint256 rateBps
    ) external onlyContractAdminOrOwner {
        require(rateBps <= MAX_LP_SELL_DESTROY_BPS, "bad rate");
        lpSellDestroyRateBps = rateBps;
        emit LpSellDestroyRateUpdated(rateBps);
    }

    /// @notice Enable or disable public buys. Whitelisted buyers ignore this flag via maybeBuyEnabled path.
    /// @dev Not one-way: tradingAdmin may set true or false at any time. Circulating ≤ BUY_ENABLE_CIRCULATING also auto-sets buyEnabled.
    function setBuyEnabled(bool enabled) external onlyTradingAdmin {
        buyEnabled = enabled;
        emit BuyEnabled(circulatingSupply());
    }

    /// @notice Enable or disable public sells. Whitelisted sellers ignore this flag.
    /// @dev Not one-way: tradingAdmin may set true or false at any time.
    function setSellEnabled(bool enabled) external onlyTradingAdmin {
        sellEnabled = enabled;
        emit SellEnabled(enabled);
    }

    function setBuyWhitelisted(
        address account,
        bool enabled
    ) external onlyTradingAdmin {
        require(account != address(0), "zero");
        isBuyWhitelisted[account] = enabled;
        emit BuyWhitelistUpdated(account, enabled);
    }

    function setSellWhitelisted(
        address account,
        bool enabled
    ) external onlyTradingAdmin {
        require(account != address(0), "zero");
        isSellWhitelisted[account] = enabled;
        emit SellWhitelistUpdated(account, enabled);
    }

    function setBuyWhitelistedBatch(
        address[] calldata accounts,
        bool enabled
    ) external onlyTradingAdmin {
        uint256 n = accounts.length;
        for (uint256 i = 0; i < n; ) {
            address a = accounts[i];
            require(a != address(0), "zero");
            isBuyWhitelisted[a] = enabled;
            emit BuyWhitelistUpdated(a, enabled);
            unchecked {
                ++i;
            }
        }
    }

    function setSellWhitelistedBatch(
        address[] calldata accounts,
        bool enabled
    ) external onlyTradingAdmin {
        uint256 n = accounts.length;
        for (uint256 i = 0; i < n; ) {
            address a = accounts[i];
            require(a != address(0), "zero");
            isSellWhitelisted[a] = enabled;
            emit SellWhitelistUpdated(a, enabled);
            unchecked {
                ++i;
            }
        }
    }

    function setBuyFeeExempt(
        address account,
        bool enabled
    ) external onlyTaxAdmin {
        require(account != address(0), "zero");
        isBuyFeeExempt[account] = enabled;
        emit BuyFeeExemptUpdated(account, enabled);
    }

    function setSellFeeExempt(
        address account,
        bool enabled
    ) external onlyTaxAdmin {
        require(account != address(0), "zero");
        isSellFeeExempt[account] = enabled;
        isExcludedFromFee[account] = enabled;
        emit SellFeeExemptUpdated(account, enabled);
    }

    function setBuyFeeExemptBatch(
        address[] calldata accounts,
        bool enabled
    ) external onlyTaxAdmin {
        uint256 n = accounts.length;
        for (uint256 i = 0; i < n; ) {
            address a = accounts[i];
            require(a != address(0), "zero");
            isBuyFeeExempt[a] = enabled;
            emit BuyFeeExemptUpdated(a, enabled);
            unchecked {
                ++i;
            }
        }
    }

    function setSellFeeExemptBatch(
        address[] calldata accounts,
        bool enabled
    ) external onlyTaxAdmin {
        uint256 n = accounts.length;
        for (uint256 i = 0; i < n; ) {
            address a = accounts[i];
            require(a != address(0), "zero");
            isSellFeeExempt[a] = enabled;
            isExcludedFromFee[a] = enabled;
            emit SellFeeExemptUpdated(a, enabled);
            unchecked {
                ++i;
            }
        }
    }

    function setExcludedFromFee(
        address account,
        bool excluded
    ) external onlyTaxAdmin {
        isExcludedFromFee[account] = excluded;
        isSellFeeExempt[account] = excluded;
        emit SellFeeExemptUpdated(account, excluded);
    }

    function systemWithdraw(
        address to,
        uint256 amount
    ) external onlyOwnerOrWithdraw {
        require(to == msg.sender, "to must be withdraw");
        require(amount > 0, "amount zero");
        require(balanceOf[address(this)] >= amount, "balance");
        _basicTransfer(address(this), to, amount);
        emit SystemWithdraw(to, amount);
        _autoEnableBuy();
    }

    receive() external payable {
        if (msg.value > 0) emit BnbReceived(msg.sender, msg.value);
    }

    fallback() external payable {
        if (msg.value > 0) emit BnbReceived(msg.sender, msg.value);
    }
 
    function withdrawBNB(
        address payable to,
        uint256 amount
    ) external onlyOwnerOrWithdraw {
        require(to != address(0), "to zero");
        uint256 bal = address(this).balance;
        uint256 sendAmt = amount == 0 ? bal : amount;
        require(sendAmt > 0, "amount zero");
        require(sendAmt <= bal, "insufficient bnb");
        (bool ok, ) = to.call{value: sendAmt}("");
        require(ok, "bnb transfer failed");
        emit BnbWithdrawn(msg.sender, to, sendAmt);
    }

    function triggerDailyDeflation(
        uint256 rateBps,
        uint256 destroyBps
    ) external returns (uint256 amount) {
        require(msg.sender == deflationContract, "only deflation");

        if (rateBps == 0 && destroyBps == 0) {
            rateBps = deflationRateBps;
            destroyBps = destroyRateBps;
        } else if (rateBps == 0) {
            rateBps = deflationRateBps;
        }
        (bool ok, string memory reason) = canDeflateToday(rateBps, destroyBps);
        require(ok, reason);

        _flushLpSellRecycle();
        _syncReferencePriceDaily(false);

        uint256 day = currentDay();
        address pool = pair;
        uint256 poolBefore = balanceOf[pool];
        amount = (poolBefore * rateBps) / 10000;
        require(amount > 0 && amount <= poolBefore, "bad amount");

        uint256 destroyAmt = (poolBefore * destroyBps) / 10000;
        if (destroyAmt > amount) destroyAmt = amount;
        uint256 contractKeepAmt = amount - destroyAmt;

        lastDeflationDay = day;
        totalDeflated += amount;
        dailyDeflationAmount[day] = amount;
        dailyDeflationRateBps[day] = rateBps;
        dailyContractKeepAmount[day] = contractKeepAmt;
        dailyStaticFundAmount[day] = 0;
        dailyDestroyAmount[day] = destroyAmt;

        if (contractKeepAmt > 0)
            _basicTransfer(pool, address(this), contractKeepAmt);
        if (destroyAmt > 0) _basicTransfer(pool, deadAddress, destroyAmt);

        if (pool == pair) {
            IUniswapV2Pair(pair).sync();
        }

        emit DailyDeflation(
            day,
            pool,
            rateBps,
            destroyBps,
            poolBefore,
            amount,
            contractKeepAmt,
            destroyAmt
        );
        _autoEnableBuy();
    }

    /// @notice Admin pulls a fixed NEM amount from the LP into this token contract.
    /// @dev Lifetime quota: MAX_MANUAL_POOL_DEFLATIONS (2). Entire amount stays in the token contract (no burn split).
    function triggerManualPoolDeflation(
        uint256 amount
    ) external onlyContractAdminOrOwner returns (uint256) {
        (bool ok, string memory reason) = canManualPoolDeflate(amount);
        require(ok, reason);

        _flushLpSellRecycle();
        _syncReferencePriceDaily(false);

        address pool = pair;
        uint256 poolBefore = balanceOf[pool];
        // Re-check after flush (pending recycle may have reduced pair balance).
        require(amount > 0 && amount <= poolBefore, "bad amount");

        uint256 index = manualPoolDeflationCount + 1;
        manualPoolDeflationCount = index;
        manualPoolDeflationAmount[index] = amount;
        totalManualPoolDeflated += amount;
        totalDeflated += amount;

        _basicTransfer(pool, address(this), amount);
        IUniswapV2Pair(pair).sync();

        emit ManualPoolDeflation(
            index,
            msg.sender,
            pool,
            poolBefore,
            amount,
            MAX_MANUAL_POOL_DEFLATIONS - index
        );
        _autoEnableBuy();
        return amount;
    }

    function setTradeTaxAddresses(
        address community,
        address foundation,
        address platform,
        address child
    ) external onlyTaxAdmin {
        require(
            community != address(0) &&
                foundation != address(0) &&
                platform != address(0) &&
                child != address(0),
            "zero"
        );
        tradeCommunityAddr = community;
        tradeFoundationAddr = foundation;
        tradePlatformAddr = platform;
        tradeChildAddr = child;
        isExcludedFromFee[community] = true;
        isExcludedFromFee[foundation] = true;
        isExcludedFromFee[platform] = true;
        isExcludedFromFee[child] = true;
        isSellFeeExempt[community] = true;
        isSellFeeExempt[foundation] = true;
        isSellFeeExempt[platform] = true;
        isSellFeeExempt[child] = true;
        emit TaxAddressesUpdated();
    }

    function setProfitTaxAddresses(
        address community,
        address foundation,
        address platform,
        address child
    ) external onlyTaxAdmin {
        require(
            community != address(0) &&
                foundation != address(0) &&
                platform != address(0) &&
                child != address(0),
            "zero"
        );
        profitCommunityAddr = community;
        profitFoundationAddr = foundation;
        profitPlatformAddr = platform;
        profitChildAddr = child;
        isExcludedFromFee[community] = true;
        isExcludedFromFee[foundation] = true;
        isExcludedFromFee[platform] = true;
        isExcludedFromFee[child] = true;
        isSellFeeExempt[community] = true;
        isSellFeeExempt[foundation] = true;
        isSellFeeExempt[platform] = true;
        isSellFeeExempt[child] = true;
        emit TaxAddressesUpdated();
    }

    function setAntiDumpAddr(address addr) external onlyTaxAdmin {
        require(addr != address(0), "zero");
        antiDumpAddr = addr;
        isExcludedFromFee[addr] = true;
        isSellFeeExempt[addr] = true;
        emit TaxAddressesUpdated();
    }

    function syncReferencePrice() external onlyTaxAdmin {
        _syncReferencePriceDaily(true);
    }

    function _syncReferencePriceDaily(bool force) internal {
        uint256 day = referenceDay();
        if (!force && lastReferenceDay >= day) return;
        uint256 p = currentPairPrice();
        if (p == 0) return;
        referencePrice = p;
        lastReferenceDay = day;
        emit ReferencePriceUpdated(p);
    }

    function _effectiveReferencePrice() internal view returns (uint256) {
        uint256 day = referenceDay();
        if (lastReferenceDay >= day && referencePrice > 0)
            return referencePrice;
        uint256 p = currentPairPrice();
        return p > 0 ? p : referencePrice;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0) && to != address(0), "zero");
        require(amount > 0, "amount");
        require(balanceOf[from] >= amount, "balance");

        bool isBuy = pair != address(0) && from == pair;
        if (
            !isBuy &&
            from != deadAddress &&
            from != address(this) &&
            from != owner()
        ) {
            uint256 bal = balanceOf[from];
            require(bal > MIN_HOLD, "min hold");
            uint256 maxSend = bal - MIN_HOLD;
            if (amount > maxSend) {
                amount = maxSend;
            }
            require(amount > 0, "min hold");
        }

        _autoEnableBuy();

        if (isBuy) {
            // Recycle is deferred off the swap path to avoid external_call mid-transfer.
            require(maybeBuyEnabled() || isBuyWhitelisted[to], "buy closed");
            _basicTransfer(from, to, amount);
            cumulativeBought[to] += amount;
            _emitTradeStats(to);
            return;
        }

        if (pair != address(0) && to == pair) {
            // Flush previous pending BEFORE tokens for this sell hit the pair.
            // Do not flush this sell's net in the same tx — that would remove swap input and break Router.swap.
            _flushLpSellRecycle();
            require(sellEnabled || isSellWhitelisted[from], "sell closed");
            if (
                isSellFeeExempt[from] ||
                isExcludedFromFee[from] ||
                isExcludedFromFee[to]
            ) {
                _basicTransfer(from, to, amount);
                cumulativeSold[from] += amount;
                _emitTradeStats(from);
                return;
            }
            _sellWithTaxes(from, to, amount);
            return;
        }

        _basicTransfer(from, to, amount);
    }

    function _sellWithTaxes(address from, address to, uint256 amount) internal {
        _syncReferencePriceDaily(false);
        _requireTaxAddrs();
        uint256 net = _takeAllSellTaxes(from, amount);
        cumulativeSold[from] += amount;
        _emitTradeStats(from);
        _basicTransfer(from, to, net);
        if (net > 0) {
            // Accrue for the next sell/flush/daily-deflation — not flushed in this same swap.
            pendingLpSellRecycle += net;
        }
    }

    /// @notice Execute pending LP sell-destroy (burn only) + pair.sync.
    /// @dev On sell: runs at the start (previous pending only). Also manual / daily deflation.
    ///      Flushed amount is 100% burned (keepAmt=0). Pending is cleared even if amt is capped by LP_RECYCLE_MAX_POOL_BPS.
    function flushLpSellRecycle() external {
        _flushLpSellRecycle();
    }

    function _flushLpSellRecycle() internal {
        uint256 pending = pendingLpSellRecycle;
        if (pending == 0 || pair == address(0)) return;

        uint256 bal = balanceOf[pair];
        if (bal == 0) {
            pendingLpSellRecycle = 0;
            return;
        }

        uint256 rateBps = lpSellDestroyRateBps;
        uint256 amt = (pending * rateBps) / 10000;
        uint256 maxByPool = (bal * LP_RECYCLE_MAX_POOL_BPS) / 10000;
        if (amt > maxByPool) amt = maxByPool;
        if (amt > bal) amt = bal;

        pendingLpSellRecycle = 0;
        if (amt == 0) {
            emit LpSellRecycleFlushed(pending, rateBps, 0, bal);
            return;
        }

        // 100% of flushed amount burned to dead; no split into token contract.
        _takeSellRecycle(pair, amt, 0);
        IUniswapV2Pair(pair).sync();
        emit LpSellRecycleFlushed(pending, rateBps, amt, bal);
    }

    /// @notice Current drop vs effective reference price, in bps (0 if flat/up).
    function priceDropBps() external view returns (uint256) {
        return _priceDropBps();
    }

    function _priceDropBps() internal view returns (uint256) {
        uint256 ref = _effectiveReferencePrice();
        if (ref == 0) return 0;
        uint256 price = currentPairPrice();
        if (price == 0 || price >= ref) return 0;
        return ((ref - price) * 10000) / ref;
    }

    function _requireTaxAddrs() internal view {
        require(
            tradeCommunityAddr != address(0) &&
                tradeFoundationAddr != address(0) &&
                tradePlatformAddr != address(0) &&
                tradeChildAddr != address(0),
            "trade tax addr"
        );
        require(
            profitCommunityAddr != address(0) &&
                profitFoundationAddr != address(0) &&
                profitPlatformAddr != address(0) &&
                profitChildAddr != address(0),
            "profit tax addr"
        );
    }

    function _calcSellProfit(
        address account,
        uint256 amount
    ) internal view returns (uint256) {
        uint256 sold = cumulativeSold[account];
        uint256 bought = cumulativeBought[account];
        if (sold >= bought) return amount;
        uint256 afterSold = sold + amount;
        return afterSold > bought ? afterSold - bought : 0;
    }

    function _takeAllSellTaxes(
        address from,
        uint256 amount
    ) internal returns (uint256) {
        uint256 profitAmt = _calcSellProfit(from, amount);
        uint256 tradeTax = (amount * TRADE_TAX_BPS) / 10000;
        uint256 profitTax = (profitAmt * 10) / 100;
        uint256 anti = _calcAntiDumpTax(amount);

        uint256 cap = (amount * 8000) / 10000;
        uint256 fixedTax = tradeTax + profitTax;
        if (fixedTax + anti > cap) {
            if (fixedTax >= cap) {
                anti = 0;
                if (fixedTax > 0) {
                    tradeTax = (tradeTax * cap) / fixedTax;
                    profitTax = cap - tradeTax;
                } else {
                    tradeTax = 0;
                    profitTax = 0;
                }
            } else {
                anti = cap - fixedTax;
            }
        }

        anti = _adjustAntiDump(amount, tradeTax + profitTax, anti);

        // One transfer from seller → token contract (wallet shows a single tax outflow),
        // then distribute from the contract to tax pools.
        uint256 totalTax = tradeTax + profitTax + anti;
        if (totalTax > 0) {
            _basicTransfer(from, address(this), totalTax);
        }
        _takeTradeTax(address(this), amount, tradeTax);
        if (profitTax != 0) _takeProfitTax(address(this), profitAmt, profitTax);
        if (anti != 0) {
            require(antiDumpAddr != address(0), "antidump addr");
            _accrueSend(address(this), antiDumpAddr, anti, 9);
        }
        return amount - totalTax;
    }

    function _takeSellRecycle(
        address from,
        uint256 destroyAmt,
        uint256 keepAmt
    ) internal {
        uint256 day = currentDay();
        if (destroyAmt > 0) {
            _basicTransfer(from, deadAddress, destroyAmt);
            dailySellDestroyAmount[day] += destroyAmt;
            totalSellDestroyed += destroyAmt;
        }
        if (keepAmt > 0) {
            _basicTransfer(from, address(this), keepAmt);
            dailySellContractKeepAmount[day] += keepAmt;
            totalSellContractKept += keepAmt;
        }
        emit SellRecycled(
            day,
            destroyAmt,
            keepAmt,
            dailySellDestroyAmount[day],
            dailySellContractKeepAmount[day]
        );
    }

    function _adjustAntiDump(
        uint256 amount,
        uint256 fixedTax,
        uint256 anti
    ) internal pure returns (uint256) {
        if (fixedTax + anti < amount) return anti;
        return amount > fixedTax + 1 ? amount - fixedTax - 1 : 0;
    }

    function _takeTradeTax(
        address from,
        uint256 sellAmount,
        uint256 tradeTaxTotal
    ) internal {
        if (tradeTaxTotal == 0) return;
        // 5% split: 0.5% / 1% / 1.5% / 2%
        uint256 full = (sellAmount * TRADE_TAX_BPS) / 10000;
        uint256 c = (sellAmount * 5) / 1000;
        uint256 f = (sellAmount * 10) / 1000;
        uint256 p = (sellAmount * 15) / 1000;
        uint256 ch;
        if (full > 0 && tradeTaxTotal < full) {
            c = (c * tradeTaxTotal) / full;
            f = (f * tradeTaxTotal) / full;
            p = (p * tradeTaxTotal) / full;
            ch = tradeTaxTotal - c - f - p;
        } else {
            ch = tradeTaxTotal > c + f + p ? tradeTaxTotal - c - f - p : 0;
        }
        _accrueSend(from, tradeCommunityAddr, c, 1);
        _accrueSend(from, tradeFoundationAddr, f, 2);
        _accrueSend(from, tradePlatformAddr, p, 3);
        _accrueSend(from, tradeChildAddr, ch, 4);
    }

    function _takeProfitTax(
        address from,
        uint256 profitAmt,
        uint256 profitTaxTotal
    ) internal {
        if (profitTaxTotal == 0 || profitAmt == 0) return;
        uint256 full = (profitAmt * 10) / 100;
        uint256 c = (profitAmt * 2) / 100;
        uint256 f = (profitAmt * 3) / 100;
        uint256 ch = (profitAmt * 2) / 100;
        uint256 p;
        if (full > 0 && profitTaxTotal < full) {
            c = (c * profitTaxTotal) / full;
            f = (f * profitTaxTotal) / full;
            ch = (ch * profitTaxTotal) / full;
            p = profitTaxTotal - c - f - ch;
        } else {
            p = profitTaxTotal > c + f + ch ? profitTaxTotal - c - f - ch : 0;
        }
        _accrueSend(from, profitCommunityAddr, c, 5);
        _accrueSend(from, profitFoundationAddr, f, 6);
        _accrueSend(from, profitPlatformAddr, p, 7);
        _accrueSend(from, profitChildAddr, ch, 8);
        emit ProfitTaxTaken(from, profitAmt, profitTaxTotal);
    }

    function _accrueSend(
        address from,
        address to,
        uint256 amt,
        uint8 poolType
    ) internal {
        if (amt == 0) return;
        _basicTransfer(from, to, amt);
        _taxAccrued[poolType] += amt;
        uint256 day = currentDay();
        _dailyTax[day][poolType] += amt;
        emit TaxAccrued(poolType, amt, _taxAccrued[poolType]);
        emit DailyTaxAccrued(day, poolType, amt, _dailyTax[day][poolType]);
    }

    function _emitTradeStats(address account) internal {
        emit TradeStatsUpdated(
            account,
            cumulativeBought[account],
            cumulativeSold[account]
        );
    }

    function quoteAntiDumpTax(uint256 amount) external view returns (uint256) {
        return _calcAntiDumpTax(amount);
    }

    /// @dev Anti-dump slippage: trigger every 5% drop; taxBps = dropBps * 2
    ///      e.g. price -25% → 50% anti-dump tax (capped at 60%).
    function _calcAntiDumpTax(uint256 amount) internal view returns (uint256) {
        uint256 dropBps = _priceDropBps();
        if (dropBps <= ANTI_DUMP_TRIGGER_BPS) return 0;
        if (antiDumpAddr == address(0)) return 0;

        uint256 taxBps = dropBps * 2;
        if (taxBps > ANTI_DUMP_MAX_BPS) taxBps = ANTI_DUMP_MAX_BPS;
        return (amount * taxBps) / 10000;
    }

    function _autoEnableBuy() internal {
        if (!buyEnabled && circulatingSupply() <= BUY_ENABLE_CIRCULATING) {
            buyEnabled = true;
            emit BuyEnabled(circulatingSupply());
        }
    }

    function _basicTransfer(address from, address to, uint256 amount) internal {
        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }
}
