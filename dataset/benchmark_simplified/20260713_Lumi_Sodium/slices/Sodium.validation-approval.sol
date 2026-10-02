    function _approvePaymasterToken(UserOperation calldata userOp) private {
        bytes calldata paymasterAndData = userOp.paymasterAndData;
        if (paymasterAndData.length != 20 + 4 + 20) {
            return;
        } else if (bytes4(paymasterAndData[20:24]) == bytes4(0x095ea7b3)) {
            IERC20Paymaster paymaster = IERC20Paymaster(
                address(bytes20(paymasterAndData[:20]))
            );

            IERC20Metadata payToken = IERC20Metadata(
                address(bytes20(paymasterAndData[24:]))
            );

            (uint256 miniAllowance, uint256 suggestApproveValue) = paymaster
                .getTokenAllowanceCast(payToken);

            if (
                payToken.allowance(address(this), address(paymaster)) <
                miniAllowance
            ) {
                payToken.approve(address(paymaster), suggestApproveValue);
            }
        }
    }

    /**
     * Validate user's signature and nonce.
     * subclass doesn't need to override this method. Instead, it should override the specific internal validation methods.
     */
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external virtual override returns (uint256 validationData) {
        _requireFromEntryPoint();
        validationData = _validateSignature(userOp, userOpHash);
        _validateNonce(userOp.nonce);
        _payPrefund(missingAccountFunds);
        _approvePaymasterToken(userOp);
    }
