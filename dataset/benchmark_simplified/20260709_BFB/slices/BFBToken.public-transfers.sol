    function transfer(address to, uint256 amount) public override returns (bool) {
        require(balanceOf[msg.sender] >= amount, 'balance error');
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address to, uint256 amount) public override returns (bool) {
        allowance[msg.sender][to] = amount;
        emit Approval(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        require(balanceOf[from] >= amount, 'balance error');
        require(allowance[from][msg.sender] >= amount, 'approve error');
        allowance[from][msg.sender] -= amount;
        _transfer(from, to, amount);
        return true;
    }

    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
