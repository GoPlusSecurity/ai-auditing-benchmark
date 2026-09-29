    function registerInstance(V3Struct.ParsedV3QuoteStruct calldata _attestation)
        external
        returns (uint256)
    {
        (bool verified,) = IAttestation(automataDcapAttestation).verifyParsedQuote(_attestation);
        require(verified, SGX_INVALID_ATTESTATION());

        address[] memory addresses = new address[](1);
        addresses[0] = address(bytes20(_attestation.localEnclaveReport.reportData));

        return _addInstances(addresses, false)[0];
    }
