// SPDX-License-Identifier: MIT

pragma solidity >=0.8.19;

import {SD1x18} from "./ValueType.sol";

error PRBMath_SD1x18_ToUD60x18_Underflow(SD1x18 x);

error PRBMath_SD1x18_ToUint128_Underflow(SD1x18 x);

error PRBMath_SD1x18_ToUint256_Underflow(SD1x18 x);

error PRBMath_SD1x18_ToUint40_Overflow(SD1x18 x);

error PRBMath_SD1x18_ToUint40_Underflow(SD1x18 x);
