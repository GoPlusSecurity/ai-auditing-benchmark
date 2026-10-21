// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import 'src/interfaces/IOstiumVerifier.sol';

contract OstiumVerifierMock is IOstiumVerifier {
    constructor() {}

    function verify(bytes memory signedReport) external pure returns (bytes memory verifierResponse) {
        (bytes memory reportData,,,) = abi.decode(signedReport, (bytes, bytes32, bytes32, uint8));
        return reportData;
    }

    function isAuthorizedSigner(address) external pure returns (bool) {
        return true;
    }

    function registerAuthorizedSigner(address signerAddress) external {}
    function unregisterAuthorizedSigner(address signerAddress) external {}
    function registerAuthorizedSignersArray(address[] memory signerAddresses) external {}
    function unregisterAuthorizedSignersArray(address[] memory signerAddresses) external {}
}
