// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20Permit} from "./IERC20Permit.sol";

import {ERC20} from "../ERC20.sol";

import {EIP712} from "../../../utils/cryptography/EIP712.sol";

import {Nonces} from "../../../utils/Nonces.sol";

abstract contract ERC20Permit is ERC20, IERC20Permit, EIP712, Nonces {
    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    error ERC2612ExpiredSignature(uint256 deadline);

    error ERC2612InvalidSigner(address signer, address owner);

    constructor(string memory name) EIP712(name, "1") {}
}
