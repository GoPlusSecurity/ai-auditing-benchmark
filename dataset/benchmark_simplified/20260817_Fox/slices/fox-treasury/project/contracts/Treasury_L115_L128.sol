    function setStakingPool(address _stakingPool) external onlyOwner {    
        //require(stakingPoolMap[_stakingPool] == false, "Staking pool already set");

        stakingPoolMap[_stakingPool] = true;
    }

    function setTimeLockPool(uint256 _lockDays, address _timeLockPool) external onlyOwner {
        //require(timeLockPoolMap1[_lockDays] == address(0), "TimeLock pool already set");

        timeLockPoolMap1[_lockDays] = _timeLockPool;
        timeLockPoolMap2[_timeLockPool] = true;
        timeLockPoolList.push(_timeLockPool);
    }

