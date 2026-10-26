    function stake(uint256 _amount, uint256 _stakeDays, bool isReward) external onlyStakingPool{
        IERC20(foxToken).safeTransferFrom(msg.sender, address(this), _amount);
        IMintableERC20(stakedFoxToken).mint(msg.sender, _amount);
        if(isReward && _stakeDays >= 180){
            IMintableERC20(rewardFoxToken).mint(foxDistributor, _amount * REWARD_RATIO / BASE_100);
        }
    }

    function lpBonds(uint256 _lpFoxAmount,uint256 _stakeAmount, uint256 _stakeDays, address inviterAddress,uint256 inviterRewardAmount) external onlyStakingPool{
        IERC20(lpFoxToken).safeTransferFrom(msg.sender, DEAD, _lpFoxAmount);
        IMintableERC20(foxToken).mint(address(this), _stakeAmount + inviterRewardAmount);
        IMintableERC20(stakedFoxToken).mint(msg.sender, _stakeAmount);
        if(_stakeDays >= 180){
            IMintableERC20(rewardFoxToken).mint(foxDistributor, _stakeAmount * REWARD_RATIO / BASE_100);
        }
        if(inviterRewardAmount > 0){
            IERC20(foxToken).safeTransfer(inviterAddress, inviterRewardAmount);
        }
    }

