    function deposit(uint256 amt) public override onlyUser {
        balance += amt;
        emit Deposited(_msgSender(), amt);
        require(erc20.transferFrom(_msgSender(), address(this), amt), "Reserve: transfer failed");
    }
