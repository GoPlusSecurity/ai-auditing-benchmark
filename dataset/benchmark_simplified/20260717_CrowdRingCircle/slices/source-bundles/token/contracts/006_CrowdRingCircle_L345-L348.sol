    function setBuyRestriction(bool enabled) external onlyOwner {
        buyRestrictionEnabled = enabled;
        emit BuyRestrictionToggled(enabled);
    }
