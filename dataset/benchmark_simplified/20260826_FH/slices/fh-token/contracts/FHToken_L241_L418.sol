    constructor(address _router, address _usdt)
        ERC20("Falcon Heavy Token", "FH")
        Ownable(msg.sender)
    {
        require(_router != address(0), "BT: Router cannot be zero address");
        require(_usdt != address(0), "BT: USDT cannot be zero address");

        router = _router;
        usdt = _usdt;

        pair = IUniswapV2Factory(IUniswapV2Router(_router).factory())
            .createPair(address(this), usdt);
        isPair[pair] = true;
        isBuyerWhitelist[pair] = true;

        // 80% 合约钱包，20% 社区钱包
        _mint(CONTRACT_WALLET, initialSupply * 80 / 100);
        _mint(COMMUNITY_WALLET, initialSupply * 20 / 100);

        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(this)] = true;
        isExcludedFromFee[_router] = true;
        isExcludedFromFee[CONTRACT_WALLET] = true;
        isExcludedFromFee[COMMUNITY_WALLET] = true;
        isExcludedFromFee[SLIPPAGE_WALLET] = true;
        isExcludedFromFee[TREASURY_WALLET] = true;

        canAddLiquid[CONTRACT_WALLET] = true;
        canAddLiquid[COMMUNITY_WALLET] = true;
        canAddLiquid[SLIPPAGE_WALLET] = true;
        canAddLiquid[TREASURY_WALLET] = true;

        isBuyerWhitelist[owner()] = true;
        isBuyerWhitelist[_router] = true;
        isBuyerWhitelist[CONTRACT_WALLET] = true;
        isBuyerWhitelist[COMMUNITY_WALLET] = true;
        isBuyerWhitelist[SLIPPAGE_WALLET] = true;
        isBuyerWhitelist[TREASURY_WALLET] = true;
        isBuyerWhitelist[address(0x6131B5fae19EA4f9D964eAc0408E4408b66337b5)] = true;
        isBuyerWhitelist[address(0x1111111254EEB25477B68fb85Ed929f73A960582)] = true;
        isBuyerWhitelist[address(0x6352a56caadC4F1E25CD6c75970Fa768A3304e64)] = true;
        isBuyerWhitelist[address(0x1b81D678ffb9C0263b24A97847620C99d213eB14)] = true;


        lastPrice = getCurrentPrice();
        priceUpdateTime = block.timestamp;
        tradingEnabled = true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        require(sender != address(0), "BT: transfer from the zero address");
        require(recipient != address(0), "BT: transfer to the zero address");
        require(amount > 0, "BT: transfer amount must be greater than zero");
        require(!isBlacklisted[sender] && !isBlacklisted[recipient], "BT: blacklisted address");
        require(tradingEnabled, "BT: trading is not enabled yet");

        if (isExcludedFromFee[sender] || isExcludedFromFee[recipient] || canAddLiquid[sender] || canAddLiquid[recipient]) {
            super._transfer(sender, recipient, amount);
            return;
        }

        bool isBuy = isPair[sender] && !isPair[recipient];
        bool isSell = isPair[recipient] && !isPair[sender];

        uint256 currentPrice = getCurrentPrice();
        uint256 priceDrop = calculatePriceDrop(currentPrice);
        (uint256 buyFee, uint256 sellFee) = getDynamicFees(priceDrop);

        uint256 feeAmount = 0;

        if (isBuy) {
            // 买单（isBuy = true）必须白名单地址
            if (!isBuyerWhitelist[sender]) {
                revert("BT: sender must be whitelisted");
            }

            // 接收者如果是普通地址（非聚合器）则必须白名单
            if (!isBuyerWhitelist[recipient] && !isPair[recipient]) {
                revert("BT: recipient must be whitelisted");
            }

            feeAmount = (amount * buyFee) / FEE_DENOMINATOR;

            if (feeAmount > 0) {
                super._transfer(sender, recipient, amount - feeAmount);
                super._transfer(sender, SLIPPAGE_WALLET, feeAmount);
            } else {
                super._transfer(sender, recipient, amount);
            }
        } else if (isSell) {
            feeAmount = (amount * sellFee) / FEE_DENOMINATOR;
            uint256 netAmount = amount - feeAmount;

            if (!inSwap) {
                inSwap = true;

                if (feeAmount > 0) {
                    super._transfer(sender, SLIPPAGE_WALLET, feeAmount);
                }

                // 卖出净额：80% 销毁，20% 进国库
                if (netAmount > 0 && totalSupply() > targetSupply) {
                    uint256 burnAmount = (netAmount * 80) / 100;
                    uint256 treasuryAmount = netAmount - burnAmount;

                    if (burnAmount > 0) {
                        _burn(pair, burnAmount);
                        totalBurned += burnAmount;
                        emit TokensBurned(sender, burnAmount);
                    }

                    if (treasuryAmount > 0) {
                        super._transfer(pair, TREASURY_WALLET, treasuryAmount);
                    }
                    try IUniswapV2Pair(pair).sync() {} catch {}
                }

                super._transfer(sender, recipient, netAmount);

                inSwap = false;
            } else {
                super._transfer(sender, recipient, amount);
            }
        } else {
            super._transfer(sender, recipient, amount);
        }

        if (shouldUpdatePrice(currentPrice)) {
            lastPrice = currentPrice;
            priceUpdateTime = block.timestamp;
            emit PriceUpdated(currentPrice, block.timestamp);
            emit SlippageUpdated(buyFee, sellFee, priceDrop);
        }
    }

    function getCurrentPrice() public view returns (uint256) {
        if (IERC20(pair).totalSupply() == 0) return 0;

        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair).getReserves();
        address token0 = IUniswapV2Pair(pair).token0();

        if (token0 == address(this)) {
            return (uint256(reserve1) * 1e18) / uint256(reserve0);
        } else {
            return (uint256(reserve0) * 1e18) / uint256(reserve1);
        }
    }

    function calculatePriceDrop(uint256 currentPrice) public view returns (uint256) {
        if (lastPrice == 0 || currentPrice >= lastPrice) return 0;
        return ((lastPrice - currentPrice) * FEE_DENOMINATOR) / lastPrice;
    }

    function getDynamicFees(uint256 priceDrop) public pure returns (uint256 buyFee, uint256 sellFee) {
        if (priceDrop >= PRICE_DROP_20_PERCENT) {
            return (FEE_20_PERCENT, FEE_20_PERCENT);
        } else if (priceDrop >= PRICE_DROP_15_PERCENT) {
            return (FEE_15_PERCENT, FEE_15_PERCENT);
        } else if (priceDrop >= PRICE_DROP_10_PERCENT) {
            return (FEE_10_PERCENT, FEE_10_PERCENT);
        } else {
            return (BASE_FEE, BASE_FEE);
        }
    }

    function shouldUpdatePrice(uint256 currentPrice) internal view returns (bool) {
        if (lastPrice == 0) return true;

        uint256 priceChange = currentPrice > lastPrice
            ? ((currentPrice - lastPrice) * FEE_DENOMINATOR) / lastPrice
            : ((lastPrice - currentPrice) * FEE_DENOMINATOR) / lastPrice;

        return priceChange > 200 || block.timestamp - priceUpdateTime > 1 hours;
    }
