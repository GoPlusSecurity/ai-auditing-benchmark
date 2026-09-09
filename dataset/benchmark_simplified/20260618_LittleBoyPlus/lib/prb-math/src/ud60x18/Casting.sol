// SPDX-License-Identifier: MIT

pragma solidity >=0.8.19;

import "./Errors.sol" as CastingErrors;

import {MAX_UINT128, MAX_UINT40} from "../Common.sol";

import {uMAX_SD1x18} from "../sd1x18/Constants.sol";

import {SD1x18} from "../sd1x18/ValueType.sol";

import {uMAX_SD21x18} from "../sd21x18/Constants.sol";

import {SD21x18} from "../sd21x18/ValueType.sol";

import {uMAX_SD59x18} from "../sd59x18/Constants.sol";

import {SD59x18} from "../sd59x18/ValueType.sol";

import {uMAX_UD2x18} from "../ud2x18/Constants.sol";

import {uMAX_UD21x18} from "../ud21x18/Constants.sol";

import {UD2x18} from "../ud2x18/ValueType.sol";

import {UD21x18} from "../ud21x18/ValueType.sol";

import {UD60x18} from "./ValueType.sol";

function intoSD1x18(UD60x18 x) pure returns (SD1x18 result) {
    uint256 xUint = UD60x18.unwrap(x);
    if (xUint > uint256(int256(uMAX_SD1x18))) {
        revert CastingErrors.PRBMath_UD60x18_IntoSD1x18_Overflow(x);
    }
    result = SD1x18.wrap(int64(uint64(xUint)));
}

function intoSD21x18(UD60x18 x) pure returns (SD21x18 result) {
    uint256 xUint = UD60x18.unwrap(x);
    if (xUint > uint256(int256(uMAX_SD21x18))) {
        revert CastingErrors.PRBMath_UD60x18_IntoSD21x18_Overflow(x);
    }
    result = SD21x18.wrap(int128(uint128(xUint)));
}

function intoUD2x18(UD60x18 x) pure returns (UD2x18 result) {
    uint256 xUint = UD60x18.unwrap(x);
    if (xUint > uMAX_UD2x18) {
        revert CastingErrors.PRBMath_UD60x18_IntoUD2x18_Overflow(x);
    }
    result = UD2x18.wrap(uint64(xUint));
}

function intoUD21x18(UD60x18 x) pure returns (UD21x18 result) {
    uint256 xUint = UD60x18.unwrap(x);
    if (xUint > uMAX_UD21x18) {
        revert CastingErrors.PRBMath_UD60x18_IntoUD21x18_Overflow(x);
    }
    result = UD21x18.wrap(uint128(xUint));
}

function intoSD59x18(UD60x18 x) pure returns (SD59x18 result) {
    uint256 xUint = UD60x18.unwrap(x);
    if (xUint > uint256(uMAX_SD59x18)) {
        revert CastingErrors.PRBMath_UD60x18_IntoSD59x18_Overflow(x);
    }
    result = SD59x18.wrap(int256(xUint));
}

function intoUint256(UD60x18 x) pure returns (uint256 result) {
    result = UD60x18.unwrap(x);
}

function intoUint128(UD60x18 x) pure returns (uint128 result) {
    uint256 xUint = UD60x18.unwrap(x);
    if (xUint > MAX_UINT128) {
        revert CastingErrors.PRBMath_UD60x18_IntoUint128_Overflow(x);
    }
    result = uint128(xUint);
}

function intoUint40(UD60x18 x) pure returns (uint40 result) {
    uint256 xUint = UD60x18.unwrap(x);
    if (xUint > MAX_UINT40) {
        revert CastingErrors.PRBMath_UD60x18_IntoUint40_Overflow(x);
    }
    result = uint40(xUint);
}

function ud(uint256 x) pure returns (UD60x18 result) {
    result = UD60x18.wrap(x);
}

function unwrap(UD60x18 x) pure returns (uint256 result) {
    result = UD60x18.unwrap(x);
}

function wrap(uint256 x) pure returns (UD60x18 result) {
    result = UD60x18.wrap(x);
}
