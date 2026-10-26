    function _approveFor(
        address owner,
        address spender,
        uint256 amount /*(ERC20BasicApproveExtension, ERC20Internal)*/
    ) internal virtual override {
        if (owner == address(0) || spender == address(0)) {
            revert InvalidOwnerOrSpender();
        }
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
