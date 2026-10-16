    function setExemption(address account, bool status) external onlyOwner {
        if (account == address(0)) revert ZeroAddress();
        isExemptFromRestriction[account] = status;
        emit ExemptionUpdated(account, status);
    }
