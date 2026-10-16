    function verify(bytes calldata signedReport) external view returns (bytes memory verifierResponse) {
        (bytes memory reportData, bytes32 r, bytes32 s, uint8 v) =
            abi.decode(signedReport, (bytes, bytes32, bytes32, uint8));

        bytes32 reportHash = keccak256(reportData);

        address signer = ecrecover(keccak256(abi.encodePacked('\x19Ethereum Signed Message:\n32', reportHash)), v, r, s);

        if (!isAuthorizedSigner[signer]) {
            revert NotAuthorizedSigner(signer);
        }

        return reportData;
    }
