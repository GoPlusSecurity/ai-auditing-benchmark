     */
    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) internal override returns (uint256 validationData) {
        if (userOp.callData.length < 4 || userOp.signature.length < 22) {
            return 1;
        }
        bytes4 methodId = bytes4(userOp.callData[0:4]);
        bytes32 ethHash = ECDSA.toEthSignedMessageHash(userOpHash);

        address signer;
        bool valid;
        (valid, signer, ) = checkValidSodiumSignature(
            ethHash,
            userOp.signature
        );

        if (!valid) {
            return 1;
        }

        if (methodId == this.executeWithSodiumAuthRecover.selector) {
            address sessionKey;
            bytes memory addressBytes = userOp.callData[16:36];
            assembly {
                sessionKey := mload(add(addressBytes, 20))
            }
            return sessionKey == signer ? 0 : 1;
        }

        if (methodId == this.executeWithSodiumAuthSession.selector) {
            address sessionKey;
            bytes memory addressBytes = userOp.callData[16:36];
            assembly {
                sessionKey := mload(add(addressBytes, 20))
            }

            bool isSafe = _safeSession.owner == address(0);
            IUserOperationValidator validator = internalReadUserOperationValidator();
            if (!isSafe) {
                // Use the on-chain security center to verify that the operation is secure.
                // Allow session access if safe
                isSafe = validator.validateUserOp(userOp) < 2;
            }
            return sessionKey == signer && isSafe ? 0 : 1;
        }

        if (methodId == this.executeWithModule.selector) {
            address module;
            bytes memory addressBytes = userOp.callData[16:36];
            assembly {
                module := mload(add(addressBytes, 20))
            }

            // if no enabled modules
            if (!isModuleEnabled(module)) {
                return 1;
            }

            return IModule(module).validateSignature(userOp, userOpHash);
        }

        if (methodId == this.execute.selector) {
            (bool existing, bool isSafe) = isSessionOwner(signer);
            IUserOperationValidator validator = internalReadUserOperationValidator();
            if (!isSafe) {
                // Use the on-chain security center to verify that the operation is secure.
                // Allow session access if safe
                isSafe = validator.validateUserOp(userOp) < 2;
            }
            return existing && isSafe ? 0 : 1;
        }

        revert("invalid methodId");
