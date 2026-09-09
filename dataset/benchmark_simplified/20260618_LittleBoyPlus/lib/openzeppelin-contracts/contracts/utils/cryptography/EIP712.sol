// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ShortStrings, ShortString} from "../ShortStrings.sol";

import {IERC5267} from "../../interfaces/IERC5267.sol";

abstract contract EIP712 is IERC5267 {
    using ShortStrings for *;

    bytes32 private constant TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 private immutable _cachedDomainSeparator;

    uint256 private immutable _cachedChainId;

    address private immutable _cachedThis;

    bytes32 private immutable _hashedName;

    bytes32 private immutable _hashedVersion;

    ShortString private immutable _name;

    ShortString private immutable _version;

    string private _nameFallback;

    string private _versionFallback;

    constructor(string memory name, string memory version) {
        _name = name.toShortStringWithFallback(_nameFallback);
        _version = version.toShortStringWithFallback(_versionFallback);
        _hashedName = keccak256(bytes(name));
        _hashedVersion = keccak256(bytes(version));

        _cachedChainId = block.chainid;
        _cachedDomainSeparator = _buildDomainSeparator();
        _cachedThis = address(this);
    }

    function _buildDomainSeparator() private view returns (bytes32) {
        return keccak256(abi.encode(TYPE_HASH, _hashedName, _hashedVersion, block.chainid, address(this)));
    }
}
