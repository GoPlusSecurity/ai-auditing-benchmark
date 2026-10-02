    function _priceDeflPool(address from, address to) private {
        uint256 nowPrice = _getTokenPrice();
        if(nowPrice == 0) return;
        uint256 nowTime = block.timestamp;
        // price rise.
        if(nowPrice >= fallLastPrice) {
            fallLastPrice = nowPrice;
            fallLastTime = nowTime;
            return;
        }

        // price fall.
        if(fallLastPrice > nowPrice * (DENOMINATOR + fallPriceRatio) / DENOMINATOR && !isContract(from) && !isContract(to)) {
            uint256 burnAmount = balanceOf[WBNB_Token_LP_Address] * fallPriceBurnRatio / DENOMINATOR;
            _transferRoot(WBNB_Token_LP_Address, address(0), burnAmount);        
            IUniswapV2Pair(WBNB_Token_LP_Address).sync();

            emit PriceDeflPool(fallLastPrice, fallLastTime, nowPrice, nowTime, burnAmount);
            fallLastPrice = _getTokenPrice();
            fallLastTime = nowTime;
        }
    }

    function _getTokenPrice() private view returns(uint256) {
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(WBNB_Token_LP_Address).getReserves();
        address wbnbAddress = IPancakeRouter02(Router_Address).WETH();
        uint256 wbnbReserves;
        uint256 thisReserves;
        if (wbnbAddress < address(this)) {
            wbnbReserves = reserve0;
            thisReserves = reserve1;
        } else {
            thisReserves = reserve0;
            wbnbReserves = reserve1;
        }
        if(wbnbReserves == 0 || thisReserves == 0) return 0;

        uint256 nowPrice = (wbnbReserves * uint256(1e18)) / thisReserves; // every 1e18 token price how much wbnb.
        return nowPrice;
    }
