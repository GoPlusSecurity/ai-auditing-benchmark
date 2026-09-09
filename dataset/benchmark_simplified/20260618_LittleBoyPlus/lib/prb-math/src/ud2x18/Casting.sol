// SPDX-License-Identifier: MIT

pragma solidity >=0.8.19;

import "../Common.sol" as Common;

import "./Errors.sol" as Errors;

import {SD59x18} from "../sd59x18/ValueType.sol";

import {UD60x18} from "../ud60x18/ValueType.sol";

import {UD2x18} from "./ValueType.sol";

function intoSD59x18(UD2x18 x) pure returns (SD59x18 result) {
    result = SD59x18.wrap(int256(uint256(UD2x18.unwrap(x))));
}

function intoUD60x18(UD2x18 x) pure returns (UD60x18 result) {
    result = UD60x18.wrap(UD2x18.unwrap(x));
}

function intoUint128(UD2x18 x) pure returns (uint128 result) {
    result = uint128(UD2x18.unwrap(x));
}

function intoUint256(UD2x18 x) pure returns (uint256 result) {
    result = uint256(UD2x18.unwrap(x));
}

function intoUint40(UD2x18 x) pure returns (uint40 result) {
    uint64 xUint = UD2x18.unwrap(x);
    if (xUint > uint64(Common.MAX_UINT40)) {
        revert Errors.PRBMath_UD2x18_IntoUint40_Overflow(x);
    }
    result = uint40(xUint);
}

function unwrap(UD2x18 x) pure returns (uint64 result) {
    result = UD2x18.unwrap(x);
}
