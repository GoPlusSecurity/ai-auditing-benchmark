        r = r | _time << 120;
        r = r | _price << 24;
        supraSValueFeedStorage.restrictedSetSupraStorage(_pair, bytes32(r));
    }

    /// @dev Requires the provided message to be verified using the contract's authority public key and BLS signature.
    /// @param _message The message to be verified.
    /// @param _signature The BLS signature of the message.
    /// @dev This function verifies the BLS signature by calling the BLS precompile contract and checks if the message matches the provided signature.
    /// @dev If the signature verification fails or if there is an issue with the BLS precompile contract call, the function reverts with an error.
    function requireHashVerified_V1(bytes memory _message, uint256[2] calldata _signature) public view {
        bool callSuccess;
        bool checkSuccess;
        (checkSuccess, callSuccess) =
            BLS.verifySingle(_signature, publicKey, BLS.hashToPoint(domain, _message), blsPrecompileGasCost);
        if (!callSuccess) {
            revert BLSInvalidPublicKeyorSignaturePoints();
        }
        if (!checkSuccess) {
            revert BLSIncorrectInputMessaage();
        }
    }

    /// @dev Requires the provided message to be verified using the contract's authority public key and BLS signature.
    /// @param _message The message to be verified.
    /// @param _signature The BLS signature of the message.
    /// @dev This function verifies the BLS signature by calling the BLS precompile contract and checks if the message matches the provided signature.
    /// @dev If the signature verification fails or if there is an issue with the BLS precompile contract call, the function reverts with an error.
    function requireHashVerified_V2(bytes32 _message, uint256[2] calldata _signature, uint256 committee_id)
        public
        view
    {
        bool callSuccess;
        bool checkSuccess;
        (checkSuccess, callSuccess) = BLS.verifySingle(
            _signature,
            committee_public_key[committee_id],
            BLS.hashToPoint(domain, abi.encode(_message)),
            blsPrecompileGasCost
        );
        if (!callSuccess) {
            revert BLSInvalidPublicKeyorSignaturePoints();
        }
        if (!checkSuccess) {
            revert BLSIncorrectInputMessaage();
        }
    }

