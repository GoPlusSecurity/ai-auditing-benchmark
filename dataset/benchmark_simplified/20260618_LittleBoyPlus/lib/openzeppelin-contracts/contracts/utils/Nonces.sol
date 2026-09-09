// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

abstract contract Nonces {
    error InvalidAccountNonce(address account, uint256 currentNonce);

    mapping(address account => uint256) private _nonces;
}
