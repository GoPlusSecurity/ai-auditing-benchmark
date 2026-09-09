// SPDX-License-Identifier: MIT

pragma solidity >=0.8.19;

import "./Errors.sol" as CastingErrors;

import {MAX_UINT128, MAX_UINT40} from "../Common.sol";

import {uMAX_SD1x18, uMIN_SD1x18} from "../sd1x18/Constants.sol";

import {SD1x18} from "../sd1x18/ValueType.sol";

import {uMAX_SD21x18, uMIN_SD21x18} from "../sd21x18/Constants.sol";

import {SD21x18} from "../sd21x18/ValueType.sol";

import {uMAX_UD2x18} from "../ud2x18/Constants.sol";

import {UD2x18} from "../ud2x18/ValueType.sol";

import {uMAX_UD21x18} from "../ud21x18/Constants.sol";

import {UD21x18} from "../ud21x18/ValueType.sol";

import {UD60x18} from "../ud60x18/ValueType.sol";

import {SD59x18} from "./ValueType.sol";

function intoInt256(SD59x18 x) pure returns (int256 result) {
    result = SD59x18.unwrap(x);
}

function intoSD1x18(SD59x18 x) pure returns (SD1x18 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < uMIN_SD1x18) {
        revert CastingErrors.PRBMath_SD59x18_IntoSD1x18_Underflow(x);
    }
    if (xInt > uMAX_SD1x18) {
        revert CastingErrors.PRBMath_SD59x18_IntoSD1x18_Overflow(x);
    }
    result = SD1x18.wrap(int64(xInt));
}

function intoSD21x18(SD59x18 x) pure returns (SD21x18 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < uMIN_SD21x18) {
        revert CastingErrors.PRBMath_SD59x18_IntoSD21x18_Underflow(x);
    }
    if (xInt > uMAX_SD21x18) {
        revert CastingErrors.PRBMath_SD59x18_IntoSD21x18_Overflow(x);
    }
    result = SD21x18.wrap(int128(xInt));
}

function intoUD2x18(SD59x18 x) pure returns (UD2x18 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < 0) {
        revert CastingErrors.PRBMath_SD59x18_IntoUD2x18_Underflow(x);
    }
    if (xInt > int256(uint256(uMAX_UD2x18))) {
        revert CastingErrors.PRBMath_SD59x18_IntoUD2x18_Overflow(x);
    }
    result = UD2x18.wrap(uint64(uint256(xInt)));
}

function intoUD21x18(SD59x18 x) pure returns (UD21x18 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < 0) {
        revert CastingErrors.PRBMath_SD59x18_IntoUD21x18_Underflow(x);
    }
    if (xInt > int256(uint256(uMAX_UD21x18))) {
        revert CastingErrors.PRBMath_SD59x18_IntoUD21x18_Overflow(x);
    }
    result = UD21x18.wrap(uint128(uint256(xInt)));
}

function intoUD60x18(SD59x18 x) pure returns (UD60x18 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < 0) {
        revert CastingErrors.PRBMath_SD59x18_IntoUD60x18_Underflow(x);
    }
    result = UD60x18.wrap(uint256(xInt));
}

function intoUint256(SD59x18 x) pure returns (uint256 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < 0) {
        revert CastingErrors.PRBMath_SD59x18_IntoUint256_Underflow(x);
    }
    result = uint256(xInt);
}

function intoUint128(SD59x18 x) pure returns (uint128 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < 0) {
        revert CastingErrors.PRBMath_SD59x18_IntoUint128_Underflow(x);
    }
    if (xInt > int256(uint256(MAX_UINT128))) {
        revert CastingErrors.PRBMath_SD59x18_IntoUint128_Overflow(x);
    }
    result = uint128(uint256(xInt));
}

function intoUint40(SD59x18 x) pure returns (uint40 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < 0) {
        revert CastingErrors.PRBMath_SD59x18_IntoUint40_Underflow(x);
    }
    if (xInt > int256(uint256(MAX_UINT40))) {
        revert CastingErrors.PRBMath_SD59x18_IntoUint40_Overflow(x);
    }
    result = uint40(uint256(xInt));
}

function unwrap(SD59x18 x) pure returns (int256 result) {
    result = SD59x18.unwrap(x);
}

function wrap(int256 x) pure returns (SD59x18 result) {
    result = SD59x18.wrap(x);
}
