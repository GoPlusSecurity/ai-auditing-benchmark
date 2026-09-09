// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

import {UD60x18, ud, pow} from "@prb/math/src/UD60x18.sol";

library PowMath {
    UD60x18 internal constant BASE_998 = UD60x18.wrap(998e15);

    uint256 internal constant MAX_T = 10_000;

    function pow998(uint256 t) internal pure returns (uint256) {
        if (t == 0) return 1e18;
        if (t > MAX_T) return 0;

        UD60x18 exponent = ud(t * 1e18);
        UD60x18 result = pow(BASE_998, exponent);
        return result.unwrap();
    }
}
