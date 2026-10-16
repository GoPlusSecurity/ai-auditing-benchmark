// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import 'src/interfaces/external/IChainlinkFeeManager.sol';

contract ChainlinkVerifierFeeManagerMock {
    address public i_nativeAddress;
    address public i_linkAddress;

    constructor(address _i_nativeAddress, address _i_linkAddress) {
        i_nativeAddress = _i_nativeAddress;
        i_linkAddress = _i_linkAddress;
    }

    function getFeeAndReward(address, bytes memory, address quoteAddress)
        external
        view
        returns (IFeeManager.Asset memory, IFeeManager.Asset memory, uint256)
    {
        return (
            IFeeManager.Asset({assetAddress: quoteAddress, amount: 1}),
            IFeeManager.Asset({assetAddress: i_linkAddress, amount: 2}),
            0
        );
    }
}
