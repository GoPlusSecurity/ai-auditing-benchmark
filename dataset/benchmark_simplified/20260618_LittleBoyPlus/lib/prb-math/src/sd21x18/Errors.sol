// SPDX-License-Identifier: MIT

pragma solidity >=0.8.19;

import {SD21x18} from "./ValueType.sol";

error PRBMath_SD21x18_ToUint128_Underflow(SD21x18 x);

error PRBMath_SD21x18_ToUD60x18_Underflow(SD21x18 x);

error PRBMath_SD21x18_ToUint256_Underflow(SD21x18 x);

error PRBMath_SD21x18_ToUint40_Overflow(SD21x18 x);

error PRBMath_SD21x18_ToUint40_Underflow(SD21x18 x);
