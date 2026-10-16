    function _transfer(address user, int128 amt) internal override {
        IERC20Reserve erc20Reserve = reserve();
        require(address(erc20Reserve) != address(0), "Reserve unset");
        if (amt > 0) {
            uint256 withdraw = uint128(amt);
            erc20Reserve.withdraw(withdraw);
            erc20.transfer(user, withdraw);
        } else if (amt < 0) {
            uint256 deposit = uint128(-amt);
            erc20.transferFrom(user, address(this), deposit);
            erc20Reserve.deposit(deposit);
        }
    }
