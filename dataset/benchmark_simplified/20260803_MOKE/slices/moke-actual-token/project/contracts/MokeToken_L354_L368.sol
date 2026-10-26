    function addReleasedBalance(address user, uint256 amount) external override {
        require(
            msg.sender == releaseContract || canManageReleasedBalance[msg.sender],
            "Not authorized"
        );
        releasedMokeBalance[user] += amount;
        emit ReleasedBalanceAdded(user, amount);
    }

    function releaseFromPair(address to, uint256 amount) external {
        require(msg.sender == releaseContract, "Only release contract");
        require(xMokePair != address(0), "X/MOKE pair not set");
        super._update(xMokePair, to, amount);
    }

