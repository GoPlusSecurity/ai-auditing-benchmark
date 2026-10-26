    function paidCall(address target, uint256 amount, bytes calldata data) external payable returns (bytes memory) {
        if (!BytesUtil.doFirstParamEqualsAddress(data, _msgSender())) {
            revert FirstParamNotSender();
        }

        if (amount > 0) {
            _addAllowanceIfNeeded(_msgSender(), target, amount);
        }

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returnData) = target.call{value: msg.value}(data);
        if (!success) {
            revert CallFailed(string(returnData));
        }

        return returnData;
    }
