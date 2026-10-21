// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import 'src/interfaces/external/IChainlinkVerifierFeeManager.sol';

contract ChainlinkVerifierProxyMock {
    IVerifierFeeManager public s_feeManager;

    constructor(IVerifierFeeManager _s_feeManager) {
        s_feeManager = _s_feeManager;
    }

    function verify(bytes memory signedReport, bytes memory) external payable returns (bytes memory verifierResponse) {
        (, bytes memory reportData,,,) = abi.decode(signedReport, (bytes32[3], bytes, bytes32[], bytes32[], bytes32));

        return reportData;
    }
}
