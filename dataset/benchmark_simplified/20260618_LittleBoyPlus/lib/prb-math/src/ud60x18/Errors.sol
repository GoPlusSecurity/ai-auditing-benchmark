// SPDX-License-Identifier: MIT

pragma solidity >=0.8.19;

import {UD60x18} from "./ValueType.sol";

error PRBMath_UD60x18_Ceil_Overflow(UD60x18 x);

error PRBMath_UD60x18_Exp_InputTooBig(UD60x18 x);

error PRBMath_UD60x18_Exp2_InputTooBig(UD60x18 x);

error PRBMath_UD60x18_Gm_Overflow(UD60x18 x, UD60x18 y);

error PRBMath_UD60x18_IntoSD1x18_Overflow(UD60x18 x);

error PRBMath_UD60x18_IntoSD21x18_Overflow(UD60x18 x);

error PRBMath_UD60x18_IntoSD59x18_Overflow(UD60x18 x);

error PRBMath_UD60x18_IntoUD2x18_Overflow(UD60x18 x);

error PRBMath_UD60x18_IntoUD21x18_Overflow(UD60x18 x);

error PRBMath_UD60x18_IntoUint128_Overflow(UD60x18 x);

error PRBMath_UD60x18_IntoUint40_Overflow(UD60x18 x);

error PRBMath_UD60x18_Log_InputTooSmall(UD60x18 x);

error PRBMath_UD60x18_Sqrt_Overflow(UD60x18 x);
