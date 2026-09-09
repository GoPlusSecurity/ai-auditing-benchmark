// SPDX-License-Identifier: MIT

pragma solidity >=0.8.19;

import "./Casting.sol" as Casting;

type UD2x18 is uint64;

using {
    Casting.intoSD59x18,
    Casting.intoUD60x18,
    Casting.intoUint128,
    Casting.intoUint256,
    Casting.intoUint40,
    Casting.unwrap
} for UD2x18 global;
