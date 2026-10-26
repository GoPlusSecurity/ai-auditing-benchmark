// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

contract ChainlinkRegistryMock {
    constructor() {}

    function triggerPerformUpKeep(address keeperContract, bytes calldata performData) external {
        (bool success,) = address(keeperContract).call(abi.encodeWithSignature('performUpkeep(bytes)', performData));

        require(success, 'ChainlinkRegistryMock error');
    }
}
