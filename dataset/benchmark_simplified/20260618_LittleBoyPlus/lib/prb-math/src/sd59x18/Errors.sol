// SPDX-License-Identifier: MIT

pragma solidity >=0.8.19;

import {SD59x18} from "./ValueType.sol";

error PRBMath_SD59x18_Abs_MinSD59x18();

error PRBMath_SD59x18_Ceil_Overflow(SD59x18 x);

error PRBMath_SD59x18_Div_InputTooSmall();

error PRBMath_SD59x18_Div_Overflow(SD59x18 x, SD59x18 y);

error PRBMath_SD59x18_Exp_InputTooBig(SD59x18 x);

error PRBMath_SD59x18_Exp2_InputTooBig(SD59x18 x);

error PRBMath_SD59x18_Floor_Underflow(SD59x18 x);

error PRBMath_SD59x18_Gm_NegativeProduct(SD59x18 x, SD59x18 y);

error PRBMath_SD59x18_Gm_Overflow(SD59x18 x, SD59x18 y);

error PRBMath_SD59x18_IntoSD1x18_Overflow(SD59x18 x);

error PRBMath_SD59x18_IntoSD1x18_Underflow(SD59x18 x);

error PRBMath_SD59x18_IntoSD21x18_Overflow(SD59x18 x);

error PRBMath_SD59x18_IntoSD21x18_Underflow(SD59x18 x);

error PRBMath_SD59x18_IntoUD2x18_Overflow(SD59x18 x);

error PRBMath_SD59x18_IntoUD2x18_Underflow(SD59x18 x);

error PRBMath_SD59x18_IntoUD21x18_Overflow(SD59x18 x);

error PRBMath_SD59x18_IntoUD21x18_Underflow(SD59x18 x);

error PRBMath_SD59x18_IntoUD60x18_Underflow(SD59x18 x);

error PRBMath_SD59x18_IntoUint128_Overflow(SD59x18 x);

error PRBMath_SD59x18_IntoUint128_Underflow(SD59x18 x);

error PRBMath_SD59x18_IntoUint256_Underflow(SD59x18 x);

error PRBMath_SD59x18_IntoUint40_Overflow(SD59x18 x);

error PRBMath_SD59x18_IntoUint40_Underflow(SD59x18 x);

error PRBMath_SD59x18_Log_InputTooSmall(SD59x18 x);

error PRBMath_SD59x18_Mul_InputTooSmall();

error PRBMath_SD59x18_Mul_Overflow(SD59x18 x, SD59x18 y);

error PRBMath_SD59x18_Powu_Overflow(SD59x18 x, uint256 y);

error PRBMath_SD59x18_Sqrt_NegativeInput(SD59x18 x);

error PRBMath_SD59x18_Sqrt_Overflow(SD59x18 x);
