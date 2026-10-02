    function getReward() public _updateReward(msg.sender) {
        require(msg.sender == tx.origin, "Not Allowed Request");
        MEMBER storage memberInfo = members[msg.sender];
        uint256 reward = memberInfo._rewards;
        require(reward > 0, "Error: You don't have any rewards to claim");
        require(!blist[msg.sender], "Error: not allowed claim");
        require(block.timestamp > memberInfo._receivedTime.add(intervalTime), "Error: limited claim time");

        uint256 fee = reward.mul(withRate).div(1000);
        reward = reward.sub(fee);
        memberInfo._rewards = 0;
        memberInfo._receivedTime = block.timestamp;
        ETHToken.transfer(msg.sender, reward);
        ETHToken.transfer(address(fundAddress), fee);
        emit GetRewardPaid(msg.sender, reward, fee);
    }
