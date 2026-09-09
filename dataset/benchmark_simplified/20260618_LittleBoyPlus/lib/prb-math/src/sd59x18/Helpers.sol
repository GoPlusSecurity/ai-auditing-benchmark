// SPDX-License-Identifier: MIT

pragma solidity >=0.8.19;

import {wrap} from "./Casting.sol";

import {SD59x18} from "./ValueType.sol";

function add(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    return wrap(x.unwrap() + y.unwrap());
}

function and(SD59x18 x, int256 bits) pure returns (SD59x18 result) {
    return wrap(x.unwrap() & bits);
}

function and2(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    return wrap(x.unwrap() & y.unwrap());
}

function eq(SD59x18 x, SD59x18 y) pure returns (bool result) {
    result = x.unwrap() == y.unwrap();
}

function gt(SD59x18 x, SD59x18 y) pure returns (bool result) {
    result = x.unwrap() > y.unwrap();
}

function gte(SD59x18 x, SD59x18 y) pure returns (bool result) {
    result = x.unwrap() >= y.unwrap();
}

function isZero(SD59x18 x) pure returns (bool result) {
    result = x.unwrap() == 0;
}

function lshift(SD59x18 x, uint256 bits) pure returns (SD59x18 result) {
    result = wrap(x.unwrap() << bits);
}

function lt(SD59x18 x, SD59x18 y) pure returns (bool result) {
    result = x.unwrap() < y.unwrap();
}

function lte(SD59x18 x, SD59x18 y) pure returns (bool result) {
    result = x.unwrap() <= y.unwrap();
}

function mod(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    result = wrap(x.unwrap() % y.unwrap());
}

function neq(SD59x18 x, SD59x18 y) pure returns (bool result) {
    result = x.unwrap() != y.unwrap();
}

function not(SD59x18 x) pure returns (SD59x18 result) {
    result = wrap(~x.unwrap());
}

function or(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    result = wrap(x.unwrap() | y.unwrap());
}

function rshift(SD59x18 x, uint256 bits) pure returns (SD59x18 result) {
    result = wrap(x.unwrap() >> bits);
}

function sub(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    result = wrap(x.unwrap() - y.unwrap());
}

function unary(SD59x18 x) pure returns (SD59x18 result) {
    result = wrap(-x.unwrap());
}

function uncheckedAdd(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    unchecked {
        result = wrap(x.unwrap() + y.unwrap());
    }
}

function uncheckedSub(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    unchecked {
        result = wrap(x.unwrap() - y.unwrap());
    }
}

function uncheckedUnary(SD59x18 x) pure returns (SD59x18 result) {
    unchecked {
        result = wrap(-x.unwrap());
    }
}

function xor(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    result = wrap(x.unwrap() ^ y.unwrap());
}
