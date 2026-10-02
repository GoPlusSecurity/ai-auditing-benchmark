    function calculateUSDTToETH(uint256 bnbAmount) public view returns (uint256 tokenAmount) {
        address[] memory path = new address[](2);
        path[0] = address(USDTToken);
        path[1] = address(ETHToken);
        return pancakeRouter.getAmountsOut(bnbAmount, path)[1];
    }

    function calculateETHToUSDT(uint256 eth) public view returns (uint256 tokenAmount) {
        address[] memory path = new address[](2);
        path[0] = address(ETHToken);
        path[1] = address(USDTToken);
        return pancakeRouter.getAmountsOut(eth, path)[1];
    }

    function earned(address account) public view returns(uint256, uint256) {
        MEMBER memory memberInfo = members[account];
        uint256 receivable = memberInfo._balance
        .mul(block.timestamp.sub(memberInfo._lastUpdateTime))
        .mul(rewardRate)
        .div(1e18);
        (uint256 receiveReward, uint256 receivableValue) = calculateAvableUsed(account, receivable);
        return (receiveReward, receivableValue);
    }

    function calculateAvableUsed(address account, uint256 receivableValue) public view returns(uint256, uint256) {
        if (receivableValue > members[account]._remain) {
            receivableValue = members[account]._remain;
        } 
        uint256 totalReward = receivableValue > 0 ? calculateUSDTToETH(receivableValue): 0;
        return (totalReward, receivableValue);
    }
