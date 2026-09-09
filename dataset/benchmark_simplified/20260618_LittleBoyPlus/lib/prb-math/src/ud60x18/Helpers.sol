// SPDX-License-Identifier: MIT

pragma solidity >=0.8.19;

import {wrap} from "./Casting.sol";

import {UD60x18} from "./ValueType.sol";

function add(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap(x.unwrap() + y.unwrap());
}

function and(UD60x18 x, uint256 bits) pure returns (UD60x18 result) {
    result = wrap(x.unwrap() & bits);
}

function and2(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap(x.unwrap() & y.unwrap());
}

function eq(UD60x18 x, UD60x18 y) pure returns (bool result) {
    result = x.unwrap() == y.unwrap();
}

function gt(UD60x18 x, UD60x18 y) pure returns (bool result) {
    result = x.unwrap() > y.unwrap();
}

function gte(UD60x18 x, UD60x18 y) pure returns (bool result) {
    result = x.unwrap() >= y.unwrap();
}

function isZero(UD60x18 x) pure returns (bool result) {

    result = x.unwrap() == 0;
}

function lshift(UD60x18 x, uint256 bits) pure returns (UD60x18 result) {
    result = wrap(x.unwrap() << bits);
}

function lt(UD60x18 x, UD60x18 y) pure returns (bool result) {
    result = x.unwrap() < y.unwrap();
}

function lte(UD60x18 x, UD60x18 y) pure returns (bool result) {
    result = x.unwrap() <= y.unwrap();
}

function mod(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap(x.unwrap() % y.unwrap());
}

function neq(UD60x18 x, UD60x18 y) pure returns (bool result) {
    result = x.unwrap() != y.unwrap();
}

function not(UD60x18 x) pure returns (UD60x18 result) {
    result = wrap(~x.unwrap());
}

function or(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap(x.unwrap() | y.unwrap());
}

function rshift(UD60x18 x, uint256 bits) pure returns (UD60x18 result) {
    result = wrap(x.unwrap() >> bits);
}

function sub(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap(x.unwrap() - y.unwrap());
}

function uncheckedAdd(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    unchecked {
        result = wrap(x.unwrap() + y.unwrap());
    }
}

function uncheckedSub(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    unchecked {
        result = wrap(x.unwrap() - y.unwrap());
    }
}

function xor(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap(x.unwrap() ^ y.unwrap());
}
