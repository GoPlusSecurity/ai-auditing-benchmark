// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "./ERC20.sol";
import {IERC20} from "./IERC20.sol";
import {Ownable} from "./Ownable.sol";
import {IUniswapV2Router02} from "./IUniswapV2Router02.sol";
import {IUniswapV2Pair} from "./IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "./IUniswapV2Factory.sol";
import {Helper} from "./Helper.sol";
import {Math} from "./Math.sol";
import {NodeDistribute} from "./NodeDistribute.sol";
import {TokenDistributor} from "./TokenDistributor.sol";
import {EnumerableSet} from "./EnumerableSet.sol";
import {IMarketingDistributor} from "./IMarketingDistributor.sol";
import {INodeDistribute} from "./INodeDistribute.sol";

struct RewardContext {
    uint256 balance;
    IUniswapV2Pair holdToken;
    uint256 holdTokenTotal;
    uint112 r0;
    uint112 r1;
    address token0;
    uint256 usdtReserve;
    address shareHolder;
    uint256 tokenBalance;
    uint256 amount;
    uint256 shareholderCount;
    uint256 gasUsed;
    uint256 iterations;
    uint256 gasLeft;
    uint256 fistValue;
}

abstract contract XPLBase is ERC20, Ownable {
    event SwapFailed(string reason, uint256 tokenAmount, uint256 timestamp);
    event TokensBurned(uint256 timestamp, uint256 amount);
    event InvestmentUpdated(
        address indexed user,
        uint256 indexed timestamp,
        uint256 previousInvestment,
        uint256 newInvestment,
        uint256 changeAmount,
        string changeType
    );
    event addHolderEvent(address _user, uint256 _index, uint256 _time);
    event typeEvent(
        bool is_add,
        bool is_remove,
        bool is_buy,
        bool is_sell,
        bool is_transfer
    );
    event PoolStatusEvent(
        uint256 rOther,
        uint256 rThis,
        uint256 balanceOther,
        uint256 balanceThis
    );
    event rewardEvent(
        address _to,
        uint256 timestamp,
        uint256 amount,
        string _type
    );

    event processLPRewardEvent(
        address _tx_origin,
        uint256 _time,
        uint256 _times,
        uint256 _hoderLength,
        uint256 _endIndex
    );
    event processLPRewardEventItem(
        address _user,
        uint256 _rewardAmount,
        uint256 _index
    );

    event AutoEvent(string _evnet_type, uint256 _time);
    error NotAllowedBuy();

    address private constant DEAD_ADDRESS =
        0x000000000000000000000000000000000000dEaD;
    address public USDT;
    address public staking;
    IMarketingDistributor public marketingAddress;
    INodeDistribute public nodeShareAddress;
    IUniswapV2Router02 public uniswapV2Router;
    IUniswapV2Pair public uniswapV2Pair;
    TokenDistributor public _tokenDistributor;

    uint256 public constant MAX_TOTAL_SUPPLY = 21000000 ether;
    uint256 public MIN_TOTAL_SUPPLY = 1000000 ether;
    uint256 public BASIS_POINTS = 10000;
    uint256 public BUY_NODE_FEE = 100; //1%
    uint256 public BUY_MARKETING_FEE = 200; //2%
    uint256 public SELL_NODE_FEE = 100; //1%
    uint256 public SELL_MARKETING_FEE = 200; //2%
    uint256 public removeLiquidityFee = 5000; // 50%
    uint256 public PROFIT_TAX_RATE = 1500;
    uint256 public NODE_SHARE = 1;
    uint256 public MARKETING_SHARE = 2;
    uint256 public BURN_INTERVAL = 1 hours;
    uint256 public BURN_RATE = 83333;
    uint256 public BURN_RATE_TOTAL = 100000000;
    uint256 public holderRewardCondition;
    uint256 public progressRewardBlock;
    uint256 public processRewardWaitBlock = 1;
    uint256 public lpRewardGas = 1000000;
    uint256 public totalTokenFeeForNode;
    uint256 public totalTokenFeeForMarketing;
    uint256 public totalTokenFeeForLP;
    uint256 public totalRewardUSDTForLP;
    uint256 public currentIndex;
    uint256 public lastBurnTime = block.timestamp;
    uint256 public swapAtAmount;
    uint256 public presaleStartTime;
    uint256 public presaleDuration = 15 days;
    uint256 public lprewardStartTime = 15 days;
    uint256 public firstBurnTime;
    bool private _inSwap;
    bool public canAutoSwap = true;
    bool public canAutoBurn = true;
    bool public canDistributeLP = true;
    bool public emitTypeEvent = false;
    bool public emitPoolStatusEvent;
    bool public presaleActive;

    mapping(address => uint256) public userBuyValueList;
    mapping(address => uint256) public userSellValueList;
    mapping(address => bool) public feeWhitelisted;
    mapping(address => uint256) public holderIndex;
    mapping(address => uint256) public addPoolList;

    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private excludedHolders;
    address[] public holders;

    modifier lockSwap() {
        _inSwap = true;
        _;
        _inSwap = false;
    }

    constructor(
        address _usdt,
        address _router,
        address _staking,
        address _marketingAddress
    ) ERC20("XPlayer Token", "XPL") Ownable(msg.sender) {
        require(
            _usdt != address(0) && _router != address(0),
            "USDT and router cannot be zero"
        );
        USDT = _usdt;
        uniswapV2Router = IUniswapV2Router02(_router);
        _mint(owner(), MAX_TOTAL_SUPPLY);
        _tokenDistributor = new TokenDistributor(_usdt);
        staking = _staking;
        marketingAddress = IMarketingDistributor(_marketingAddress);
        feeWhitelisted[address(marketingAddress)] = true;
        feeWhitelisted[owner()] = true;
        feeWhitelisted[address(this)] = true;
        feeWhitelisted[address(uniswapV2Router)] = true;
        presaleStartTime = block.timestamp;
        presaleActive = true;
        excludedHolders.add(address(0));
        excludedHolders.add(DEAD_ADDRESS);
    }

    function setPresaleActive(bool _presaleActive) external onlyOwner {
        presaleActive = _presaleActive;
    }

    function setPresaleDuration(uint256 _presaleDuration) external onlyOwner {
        presaleDuration = _presaleDuration;
    }

    function setEmitTypeEvent(bool _emitTypeEvent) external onlyOwner {
        emitTypeEvent = _emitTypeEvent;
    }

    function setEmitPoolStatusEvent(
        bool _emitPoolStatusEvent
    ) external onlyOwner {
        emitPoolStatusEvent = _emitPoolStatusEvent;
    }

    function setShare(
        uint256 _NODE_SHARE,
        uint256 _MARKETING_SHARE
    ) external onlyOwner {
        NODE_SHARE = _NODE_SHARE;
        MARKETING_SHARE = _MARKETING_SHARE;
    }

    function setRemoveLiquidityFee(
        uint256 _removeLiquidityFee
    ) external onlyOwner {
        removeLiquidityFee = _removeLiquidityFee;
    }

    function setLpRewardStartTime(
        uint256 _lprewardStartTime
    ) external onlyOwner {
        lprewardStartTime = _lprewardStartTime;
    }

    function setMinTotalSupply(uint256 _MIN_TOTAL_SUPPLY) external onlyOwner {
        require(_MIN_TOTAL_SUPPLY <= MAX_TOTAL_SUPPLY, "k001");
        MIN_TOTAL_SUPPLY = _MIN_TOTAL_SUPPLY;
    }

    function setProfitTaxRate(uint256 _PROFIT_TAX_RATE) external onlyOwner {
        require(_PROFIT_TAX_RATE <= 10000, "k002");
        PROFIT_TAX_RATE = _PROFIT_TAX_RATE;
    }

    function setTUSDT(address _USDT) external onlyOwner {
        require(_USDT != address(0), "k003");
        USDT = _USDT;
    }

    function setBuyFee(
        uint256 _BUY_NODE_FEE,
        uint256 _BUY_MARKETING_FEE
    ) external onlyOwner {
        BUY_NODE_FEE = _BUY_NODE_FEE;
        BUY_MARKETING_FEE = _BUY_MARKETING_FEE;
    }

    function setSellFee(
        uint256 _SELL_MARKETING_FEE,
        uint256 _SELL_NODE_FEE
    ) external onlyOwner {
        SELL_MARKETING_FEE = _SELL_MARKETING_FEE;
        SELL_NODE_FEE = _SELL_NODE_FEE;
    }

    function setTStaking(address _staking) external onlyOwner {
        require(_staking != address(0), "k004");
        staking = _staking;
    }

    function setBurnInterval(uint256 _burnInterval) external onlyOwner {
        BURN_INTERVAL = _burnInterval;
    }

    function setBurnRate(uint256 _burnRate) external onlyOwner {
        BURN_RATE = _burnRate;
    }

    function setTPair(address _pair) external onlyOwner {
        require(_pair != address(0), "k005");
        uniswapV2Pair = IUniswapV2Pair(_pair);
    }

    function setTMarketingAddress(
        IMarketingDistributor _marketingAddress
    ) external onlyOwner {
        require(address(_marketingAddress) != address(0), "k006");
        marketingAddress = _marketingAddress;
        feeWhitelisted[address(_marketingAddress)] = true;
    }

    function setTNodeDistributePlusAddress(
        address _nodeShareAddress
    ) external onlyOwner {
        require(_nodeShareAddress != address(0), "k007");
        nodeShareAddress = INodeDistribute(_nodeShareAddress);
        feeWhitelisted[_nodeShareAddress] = true;
    }

    function setFeeWhitelisted(
        address account,
        bool whitelisted
    ) external onlyOwner {
        feeWhitelisted[account] = whitelisted;
    }

    function setBatchFeeWhitelisted(
        address[] memory accounts,
        bool _whitelisted
    ) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            feeWhitelisted[accounts[i]] = _whitelisted;
        }
    }

    function setSwapAtAmount(uint256 _swapAtAmount) external onlyOwner {
        swapAtAmount = _swapAtAmount;
    }

    function recoverStuckTokens(address token, uint256 amount) external {
        require(msg.sender == owner() || msg.sender == staking, "k009");
        if (token == address(this)) return;
        IERC20(token).transfer(owner(), amount);
    }

    function recycle(uint256 amount) external {
        require(msg.sender == staking, "k008");
        uint256 pairBalance = balanceOf(address(uniswapV2Pair));
        uint256 maxRecyclable = pairBalance / 3;
        uint256 recycleAmount = amount >= maxRecyclable
            ? maxRecyclable
            : amount;
        address recipient = staking;

        if (recycleAmount > 0) {
            _update(address(uniswapV2Pair), recipient, recycleAmount);
            uniswapV2Pair.sync();
        }
    }

    function getUniswapV2Pair() external view returns (address) {
        return address(uniswapV2Pair);
    }

    function getUSDTReserve() public view returns (uint112 usdtReserve) {
        try uniswapV2Pair.getReserves() returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32
        ) {
            return uniswapV2Pair.token0() == USDT ? reserve0 : reserve1;
        } catch {
            return 0;
        }
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut) {
        return Helper.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn) {
        return Helper.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function isContract(address account) external view returns (bool) {
        return Helper.isContract(account);
    }

    function transfer(
        address to,
        uint256 value
    ) public override returns (bool) {
        address sender = _msgSender();
        _update(sender, to, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _update(from, to, value);
        return true;
    }

    function setX(
        bool _canAutoSwap,
        bool _canAutoBurn,
        bool _canDistributeLP
    ) external onlyOwner {
        canAutoSwap = _canAutoSwap;
        canAutoBurn = _canAutoBurn;
        canDistributeLP = _canDistributeLP;
    }

    event AddPoolEvent(address _user, uint256 _amount, uint256 _timestamp);
    event RemovePoolEvent(address _user, uint256 _amount, uint256 _timestamp);

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override {
        bool isZeroAddress = from == address(0) || to == address(0);
        bool is_add = false;
        bool is_remove = false;
        bool is_buy = false;
        bool is_sell = false;
        bool is_transfer = false;
        if (isZeroAddress) {
            super._update(from, to, value);
            return;
        }
        bool isWhitelisted = feeWhitelisted[from] || feeWhitelisted[to];
        if (isWhitelisted) {
            super._update(from, to, value);
            return;
        }
        if (
            address(uniswapV2Pair) != address(0) && to == address(uniswapV2Pair)
        ) {
            uint256 addLPLiquidity = _isAddLiquidity(value);
            if (addLPLiquidity > 0) {
                is_add = true;
                addPoolList[from] += addLPLiquidity;
                emit AddPoolEvent(from, addLPLiquidity, block.timestamp);
                addHolder(from);
            }
        }
        if (
            address(uniswapV2Pair) != address(0) &&
            from == address(uniswapV2Pair)
        ) {
            uint256 removeLPLiquidity = _isRemoveLiquidity(value);
            if (removeLPLiquidity > 0) {
                if (addPoolList[to] > removeLPLiquidity) {
                    addPoolList[to] -= removeLPLiquidity;
                } else {
                    addPoolList[to] = 0;
                }
                emit RemovePoolEvent(to, removeLPLiquidity, block.timestamp);
                is_remove = true;
            }
        }
        if (from == address(uniswapV2Pair) || to == address(uniswapV2Pair)) {
            if (to == address(uniswapV2Pair) && !is_add) {
                is_sell = true;
            }
            if (from == address(uniswapV2Pair) && !is_remove) {
                is_buy = true;
            }
            if (emitPoolStatusEvent) {
                (
                    uint256 rOther,
                    uint256 rThis,
                    uint256 balanceOther,
                    uint256 balanceThis
                ) = _getReserves();
                emit PoolStatusEvent(rOther, rThis, balanceOther, balanceThis);
            }
        }
        if (!is_add && !is_remove && !is_buy && !is_sell) {
            is_transfer = true;
        }

        if (emitTypeEvent) {
            emit typeEvent(is_add, is_remove, is_buy, is_sell, is_transfer);
        }

        if (is_sell || is_transfer) {
            if (is_sell && canAutoSwap) {
                _autoSwap();
            }
            if (canAutoBurn && _shouldFee()) {
                _autoBurnPool();
            }
        }
        if (is_buy) {
            _handleBuy(from, to, value);
        } else if (is_sell) {
            _handleSell(from, to, value);
        } else if (is_remove && _shouldFee() && removeLiquidityFee > 0) {
            _handleRemoveLiquidity(from, to, value);
        } else {
            super._update(from, to, value);
        }

        if (from != address(this) && canDistributeLP && holders.length > 0) {
            _processLPReward(lpRewardGas);
        }
    }

    function _handleRemoveLiquidity(
        address from,
        address to,
        uint256 amount
    ) private {
        uint256 removeFee = (amount * removeLiquidityFee) / BASIS_POINTS;
        uint256 userAmount = amount - removeFee;
        super._update(from, to, userAmount);
        super._update(from, DEAD_ADDRESS, removeFee);
        emit AutoEvent("_autoRemoveLiquidity", block.timestamp);
    }

    function _autoSwap() private {
        if (
            address(uniswapV2Pair) == address(0) ||
            address(marketingAddress) == address(0) ||
            address(nodeShareAddress) == address(0)
        ) {
            return;
        }
        if (
            nodeShareAddress.tokenDistributorForUSDT() == address(0) ||
            nodeShareAddress.tokenDistributorForXPL() == address(0)
        ) {
            return;
        }
        uint256 totalTokenFee = totalTokenFeeForNode +
            totalTokenFeeForMarketing;
        if (!_inSwap && totalTokenFee > swapAtAmount) {
            totalTokenFee = _getMin(totalTokenFee, balanceOf(address(this)));
            uint256 usdtAmount = _swapTokensForUSDT(totalTokenFee);
            {
                uint256 marketingReard = (usdtAmount *
                    totalTokenFeeForMarketing) / totalTokenFee;
                if (marketingReard > 0) {
                    IERC20(USDT).transfer(
                        address(marketingAddress),
                        marketingReard
                    );
                    marketingAddress.distributeToken();
                    emit rewardEvent(
                        address(marketingAddress),
                        block.timestamp,
                        marketingReard,
                        "marketing"
                    );
                }
                uint256 nodeReard = (usdtAmount * totalTokenFeeForNode) /
                    totalTokenFee;
                if (nodeReard > 0) {
                    _distributeNodeforUSDT(nodeReard);
                    emit rewardEvent(
                        nodeShareAddress.tokenDistributorForUSDT(),
                        block.timestamp,
                        nodeReard,
                        "node_share"
                    );
                }
            }
            totalTokenFeeForMarketing = 0;
            totalTokenFeeForNode = 0;
            emit AutoEvent("_autoSwap", block.timestamp);
        }
    }

    function _distributeNodeforXPL(uint256 _amount) private {
        if (address(nodeShareAddress) == address(0)) {
            return;
        }
        if (nodeShareAddress.tokenDistributorForXPL() == address(0)) {
            return;
        }
        super._update(
            address(this),
            nodeShareAddress.tokenDistributorForXPL(),
            _amount
        );
        nodeShareAddress.distributeShare(1);
    }

    function _distributeNodeforUSDT(uint256 _amount) private {
        IERC20(USDT).transfer(
            nodeShareAddress.tokenDistributorForUSDT(),
            _amount
        );
        nodeShareAddress.distributeShare(0);
    }

    function DynamicBurnPool(uint256 _amount) public {
        require(
            msg.sender == owner() ||
                msg.sender == staking ||
                msg.sender == address(nodeShareAddress) ||
                msg.sender == address(marketingAddress),
            "k012"
        );
        if (_shouldFee()) {
            super._update(address(uniswapV2Pair), DEAD_ADDRESS, _amount);
            uniswapV2Pair.sync();
            emit AutoEvent("_autoBurnPoolByOwner", block.timestamp);
        }
    }

    function _autoBurnPool() private {
        uint256 _timestamp = block.timestamp;
        uint256 remainingSupply = MAX_TOTAL_SUPPLY -
            (balanceOf(address(0)) + balanceOf(DEAD_ADDRESS));
        if (remainingSupply < MIN_TOTAL_SUPPLY) {
            return;
        }
        if (_timestamp - lastBurnTime < BURN_INTERVAL) {
            return;
        }

        uint256 burnAmount = (balanceOf(address(uniswapV2Pair)) * BURN_RATE) /
            BURN_RATE_TOTAL;
        if (remainingSupply - burnAmount < MIN_TOTAL_SUPPLY) {
            return;
        }
        uint256 halfAmount = burnAmount / 2;
        super._update(address(uniswapV2Pair), DEAD_ADDRESS, halfAmount);
        super._update(address(uniswapV2Pair), address(this), halfAmount);
        uniswapV2Pair.sync();
        if (firstBurnTime == 0) {
            _distributeNodeforXPL(halfAmount);
        } else {
            uint256 timeDiff = _timestamp - firstBurnTime;
            if (timeDiff <= lprewardStartTime) {
                _distributeNodeforXPL(halfAmount);
            } else {
                _distributeNodeforXPL((halfAmount * 60) / 100);
                totalTokenFeeForLP += (halfAmount * 40) / 100;
            }
        }
        emit AutoEvent("_autoBurnPool", _timestamp);
        lastBurnTime = _timestamp;

        if (firstBurnTime == 0) {
            firstBurnTime = _timestamp;
        }
    }

    function _getProfitTaxRate() public view returns (uint256) {
        uint256 burnedAmount = balanceOf(DEAD_ADDRESS) + balanceOf(address(0));
        if (burnedAmount >= MAX_TOTAL_SUPPLY - MIN_TOTAL_SUPPLY) {
            return 0;
        }
        uint256 t = burnedAmount / (2000000 * 10 ** 18);
        if (150 * t >= PROFIT_TAX_RATE) {
            return 0;
        }
        uint256 profitTaxRate = PROFIT_TAX_RATE - 150 * t;
        return profitTaxRate;
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

    function _handleBuy(address from, address to, uint256 amount) private {
        require(!presaleActive || to == staking, "k009");
        require(
            block.timestamp >= presaleStartTime + presaleDuration ||
                to == staking,
            "k010"
        );
        uint256 marketingFee = _shouldFee()
            ? (amount * BUY_MARKETING_FEE) / BASIS_POINTS
            : 0;
        if (marketingFee > 0) {
            super._update(from, address(this), marketingFee);
            totalTokenFeeForMarketing += marketingFee;
        }
        uint256 buyNodeFee = _shouldFee()
            ? (amount * BUY_NODE_FEE) / BASIS_POINTS
            : 0;
        if (buyNodeFee > 0) {
            super._update(from, address(this), buyNodeFee);
            totalTokenFeeForNode += buyNodeFee;
        }
        uint256 totalFees = marketingFee + buyNodeFee;
        uint256 netAmount = amount - totalFees;
        super._update(from, to, netAmount);
        if (to != staking) {
            _updateBuyInvestmentAndEmitEvent(to, netAmount);
        }
    }

    event SellEvent(
        address from,
        address to,
        uint256 timestamp,
        uint256 amount,
        uint256 netAmount,
        uint256 marketingFee,
        uint256 nodeFee,
        uint256 profitTaxInBONUS,
        uint256 profitTaxUSDT,
        uint256 estimatedUSDTFromSale,
        uint256 actualUSDTReceived
    );

    event TaxEvent(
        uint256 timestamp,
        address user,
        uint256 estimatedUSDTFromSale,
        uint256 profitTaxUSDT
    );

    function _handleSell(address from, address to, uint256 amount) private {
        uint256 marketingFee = _shouldFee()
            ? (amount * SELL_MARKETING_FEE) / BASIS_POINTS
            : 0;
        if (marketingFee > 0) {
            super._update(from, address(this), marketingFee);
            totalTokenFeeForMarketing += marketingFee;
        }
        uint256 nodeFee = _shouldFee()
            ? (amount * SELL_NODE_FEE) / BASIS_POINTS
            : 0;
        if (nodeFee > 0) {
            super._update(from, address(this), nodeFee);
            totalTokenFeeForNode += nodeFee;
        }
        uint256 netAmountAfterTradingFees = amount - marketingFee - nodeFee;
        uint256 profitTaxInBONUS;
        uint256 netAmount;
        if (from != staking) {
            uint256 estimatedUSDTFromSale = _estimateSwapOutput(
                netAmountAfterTradingFees
            );
            uint256 userCurrentInvestment = userBuyValueList[from];
            uint256 profitTaxUSDT;
            if (estimatedUSDTFromSale > userCurrentInvestment) {
                uint256 profitAmount = estimatedUSDTFromSale -
                    userCurrentInvestment;
                profitTaxUSDT =
                    (profitAmount * _getProfitTaxRate()) /
                    BASIS_POINTS;
                profitTaxInBONUS =
                    (profitTaxUSDT * netAmountAfterTradingFees) /
                    estimatedUSDTFromSale;
            }
            if (profitTaxInBONUS > 0) {
                super._update(from, address(this), profitTaxInBONUS);
                totalTokenFeeForMarketing +=
                    (profitTaxInBONUS * MARKETING_SHARE) /
                    (NODE_SHARE + MARKETING_SHARE);
                totalTokenFeeForNode +=
                    (profitTaxInBONUS * NODE_SHARE) /
                    (NODE_SHARE + MARKETING_SHARE);
            }

            uint256 actualUSDTReceived = estimatedUSDTFromSale - profitTaxUSDT;
            emit TaxEvent(
                block.timestamp,
                from,
                estimatedUSDTFromSale,
                profitTaxUSDT
            );
            _updateInvestmentAfterSell(from, actualUSDTReceived);
            netAmount = amount - marketingFee - nodeFee - profitTaxInBONUS;
            // uint256 _timestamp = block.timestamp;
            // emit SellEvent(
            //     from,
            //     to,
            //     _timestamp,
            //     amount,
            //     netAmount,
            //     marketingFee,
            //     nodeFee,
            //     profitTaxInBONUS,
            //     profitTaxUSDT,
            //     estimatedUSDTFromSale,
            //     actualUSDTReceived
            // );
        } else {
            netAmount = amount - marketingFee - nodeFee - profitTaxInBONUS;
        }

        super._update(from, to, netAmount);
    }

    function _estimateSwapOutput(
        uint256 tokenAmount
    ) private view returns (uint256 usdtAmount) {
        try uniswapV2Pair.getReserves() returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32
        ) {
            (uint112 reserveUSDT, uint112 reserveToken) = uniswapV2Pair
                .token0() == USDT
                ? (reserve0, reserve1)
                : (reserve1, reserve0);

            if (reserveToken > 0 && reserveUSDT > 0) {
                return
                    Helper.getAmountOut(tokenAmount, reserveToken, reserveUSDT);
            }
        } catch {}
        return 0;
    }

    function _estimateBuyUSDTCost(
        uint256 tokenAmount
    ) private view returns (uint256 usdtCost) {
        try uniswapV2Pair.getReserves() returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32
        ) {
            (uint112 reserveUSDT, uint112 reserveToken) = uniswapV2Pair
                .token0() == USDT
                ? (reserve0, reserve1)
                : (reserve1, reserve0);

            if (reserveToken > 0 && reserveUSDT > 0) {
                uint256 grossTokenAmount;
                if (_shouldFee()) {
                    grossTokenAmount =
                        (tokenAmount * BASIS_POINTS) /
                        (BASIS_POINTS - BUY_MARKETING_FEE - BUY_NODE_FEE);
                } else {
                    grossTokenAmount = tokenAmount;
                }
                return
                    Helper.getAmountIn(
                        grossTokenAmount,
                        reserveUSDT,
                        reserveToken
                    );
            }
        } catch {}
        return tokenAmount;
    }

    function updateBuyInvestment(address to, uint256 estimatedUSDTCost) public {
        require(msg.sender == staking, "k011");
        _updateBuyInvestment(to, estimatedUSDTCost);
    }

    function _updateBuyInvestment(
        address to,
        uint256 estimatedUSDTCost
    ) private {
        uint256 previousInvestment = userBuyValueList[to];
        userBuyValueList[to] = previousInvestment + estimatedUSDTCost;
        emit InvestmentUpdated(
            to,
            block.timestamp,
            previousInvestment,
            userBuyValueList[to],
            estimatedUSDTCost,
            "Buy"
        );
    }

    function _updateBuyInvestmentAndEmitEvent(
        address to,
        uint256 netAmount
    ) private {
        uint256 estimatedUSDTCost = _estimateBuyUSDTCost(netAmount);
        _updateBuyInvestment(to, estimatedUSDTCost);
    }

    function _updateInvestmentAfterSell(
        address user,
        uint256 actualUSDTReceived
    ) private {
        userSellValueList[user] += actualUSDTReceived;
        uint256 previousInvestment = userBuyValueList[user];
        userBuyValueList[user] = previousInvestment <= actualUSDTReceived
            ? 0
            : previousInvestment - actualUSDTReceived;
        emit InvestmentUpdated(
            user,
            block.timestamp,
            previousInvestment,
            userBuyValueList[user],
            actualUSDTReceived,
            "Sell"
        );
    }

    function _transferTokenFromDistributor(
        IERC20 _token,
        address _to,
        TokenDistributor tokenDistributor_
    ) private returns (uint256) {
        uint256 newBal = _token.balanceOf(address(tokenDistributor_));
        if (newBal != 0) {
            _token.transferFrom(address(tokenDistributor_), _to, newBal);
        }
        return newBal;
    }

    function _swapTokensForUSDT(
        uint256 tokenAmount
    ) private lockSwap returns (uint256 usdtReceived) {
        if (tokenAmount == 0 || balanceOf(address(this)) < tokenAmount)
            return 0;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = USDT;

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        try
            uniswapV2Router
                .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    tokenAmount,
                    0,
                    path,
                    address(_tokenDistributor),
                    block.timestamp + 300
                )
        {
            uint256 swappedAmount = _transferTokenFromDistributor(
                IERC20(USDT),
                address(this),
                _tokenDistributor
            );
            return swappedAmount;
        } catch Error(string memory reason) {
            emit SwapFailed(reason, tokenAmount, block.timestamp);
            return 0;
        } catch {
            emit SwapFailed("Unknown swap error", tokenAmount, block.timestamp);
            return 0;
        }
    }

    function _getReserves()
        public
        view
        returns (
            uint256 rOther,
            uint256 rThis,
            uint256 balanceOther,
            uint256 balanceThis
        )
    {
        (uint r0, uint256 r1, ) = uniswapV2Pair.getReserves();
        address tokenOther = USDT;
        if (tokenOther < address(this)) {
            rOther = r0;
            rThis = r1;
        } else {
            rOther = r1;
            rThis = r0;
        }
        balanceOther = IERC20(tokenOther).balanceOf(address(uniswapV2Pair));
        balanceThis = balanceOf(address(uniswapV2Pair));
    }

    function _isAddLiquidity(
        uint256 amount
    ) internal view returns (uint256 liquidity) {
        (
            uint256 rOther,
            uint256 rThis,
            uint256 balanceOther,

        ) = _getReserves();
        uint256 amountOther;
        if (rOther > 0 && rThis > 0) {
            amountOther = (amount * rOther) / rThis;
        }
        if (balanceOther >= rOther + amountOther) {
            (liquidity, ) = _calLiquidity(balanceOther, amount, rOther, rThis);
        }
    }

    function _calLiquidity(
        uint256 balanceA,
        uint256 amount,
        uint256 r0,
        uint256 r1
    ) private view returns (uint256 liquidity, uint256 feeToLiquidity) {
        uint256 pairTotalSupply = IUniswapV2Pair(uniswapV2Pair).totalSupply();
        address feeTo = IUniswapV2Factory(uniswapV2Router.factory()).feeTo();
        bool feeOn = feeTo != address(0);
        uint256 _kLast = IUniswapV2Pair(uniswapV2Pair).kLast();
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = Math.sqrt(r0 * r1);
                uint256 rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = pairTotalSupply *
                        (rootK - rootKLast) *
                        8;
                    uint256 denominator = rootK * 17 + (rootKLast * 8);
                    feeToLiquidity = numerator / denominator;
                    if (feeToLiquidity > 0) pairTotalSupply += feeToLiquidity;
                }
            }
        }
        uint256 amount0 = balanceA - r0;
        if (pairTotalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount) - 1000;
        } else {
            liquidity = Math.min(
                (amount0 * pairTotalSupply) / r0,
                (amount * pairTotalSupply) / r1
            );
        }
    }

    function _isRemoveLiquidity(
        uint256 amount
    ) internal view returns (uint256 liquidity) {
        (uint256 rOther, , uint256 balanceOther, ) = _getReserves();
        if (balanceOther <= rOther) {
            liquidity =
                (amount * IUniswapV2Pair(uniswapV2Pair).totalSupply()) /
                (balanceOf(address(uniswapV2Pair)) - amount);
        }
    }

    function _getMin(uint256 _a, uint256 _b) private pure returns (uint256 _c) {
        _c = _a;
        if (_b < _a) {
            _c = _b;
        }
    }

    event X2(uint256 totalTokenFeeForLP, uint256 amount);

    function _processLPReward(uint256 gas) private {
        if (progressRewardBlock + processRewardWaitBlock > block.number) {
            return;
        }
        RewardContext memory ctx;
        ctx.balance = _getMin(
            IERC20(address(this)).balanceOf(address(this)),
            totalTokenFeeForLP
        );

        totalTokenFeeForLP = ctx.balance;
        if (ctx.balance == 0 || ctx.balance < holderRewardCondition) {
            return;
        }
        ctx.holdToken = IUniswapV2Pair(uniswapV2Pair);
        ctx.holdTokenTotal = ctx.holdToken.totalSupply() - getAdjustedBalance();
        if (ctx.holdTokenTotal == 0) {
            return;
        }
        ctx.shareholderCount = holders.length;
        if (ctx.shareholderCount == 0) {
            return;
        }
        ctx.gasUsed = 0;
        ctx.iterations = 0;
        ctx.gasLeft = gasleft();
        while (ctx.gasUsed < gas && ctx.iterations < ctx.shareholderCount) {
            if (currentIndex >= ctx.shareholderCount) {
                currentIndex = 0;
            }
            ctx.shareHolder = holders[currentIndex];
            ctx.tokenBalance = _getMin(
                ctx.holdToken.balanceOf(ctx.shareHolder),
                addPoolList[ctx.shareHolder]
            );
            if (
                ctx.tokenBalance > 0 &&
                !excludedHolders.contains(ctx.shareHolder)
            ) {
                ctx.amount =
                    (ctx.balance * ctx.tokenBalance) /
                    ctx.holdTokenTotal;
                emit X2(totalTokenFeeForLP, ctx.amount);
                if (ctx.amount > 0 && totalTokenFeeForLP >= ctx.amount) {
                    totalTokenFeeForLP -= ctx.amount;
                    super._update(address(this), ctx.shareHolder, ctx.amount);
                    // IERC20(USDT).transfer(ctx.shareHolder, ctx.amount);
                    emit processLPRewardEventItem(
                        ctx.shareHolder,
                        ctx.amount,
                        currentIndex
                    );
                }
            }
            ctx.gasUsed = ctx.gasUsed + (ctx.gasLeft - gasleft());
            ctx.gasLeft = gasleft();
            currentIndex++;
            ctx.iterations++;
        }
        emit processLPRewardEvent(
            tx.origin,
            block.timestamp,
            ctx.iterations,
            ctx.shareholderCount,
            currentIndex
        );
        progressRewardBlock = block.number;
    }

    function setHolderRewardCondition(
        uint256 _holderRewardCondition
    ) external onlyOwner {
        holderRewardCondition = _holderRewardCondition;
    }

    function addExcludedHolder(address[] calldata _holders) external onlyOwner {
        for (uint256 i = 0; i < _holders.length; i++) {
            excludedHolders.add(_holders[i]);
        }
    }

    function removeExcludedHolder(
        address[] calldata _holders
    ) external onlyOwner {
        for (uint256 i = 0; i < _holders.length; i++) {
            excludedHolders.remove(_holders[i]);
        }
    }

    function isExcludedHolder(address _holder) external view returns (bool) {
        return excludedHolders.contains(_holder);
    }

    function addHolder(address adr) private {
        if (
            0 == holderIndex[adr] &&
            adr != address(0) &&
            adr != address(this) &&
            adr != address(DEAD_ADDRESS) &&
            adr != staking
        ) {
            if (0 == holders.length || holders[0] != adr) {
                emit addHolderEvent(adr, holders.length, block.timestamp);
                holderIndex[adr] = holders.length;
                holders.push(adr);
            }
        }
    }

    function getAdjustedBalance() public view returns (uint256) {
        uint256 _adjustedBalance = 0;
        address[] memory _excludedHolders = excludedHolders.values();
        uint256 _length = _excludedHolders.length;
        for (uint256 i = 0; i < _length; i++) {
            address _holder = _excludedHolders[i];
            _adjustedBalance += IUniswapV2Pair(uniswapV2Pair).balanceOf(
                _holder
            );
        }
        return _adjustedBalance;
    }

    function canSwap() public view returns (bool) {
        return
            presaleActive &&
            block.timestamp >= presaleStartTime + presaleDuration;
    }
}
