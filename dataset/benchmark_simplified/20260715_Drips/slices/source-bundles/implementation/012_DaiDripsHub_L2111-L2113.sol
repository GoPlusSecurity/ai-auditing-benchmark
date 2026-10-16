    function reserve() public view returns (IERC20Reserve) {
        return IERC20Reserve(_reserveSlot().value);
    }
