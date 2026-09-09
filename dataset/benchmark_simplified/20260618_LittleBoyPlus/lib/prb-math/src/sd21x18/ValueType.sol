// SPDX-License-Identifier: MIT

pragma solidity >=0.8.19;

import "./Casting.sol" as Casting;

type SD21x18 is int128;

using {
    Casting.intoSD59x18,
    Casting.intoUD60x18,
    Casting.intoUint128,
    Casting.intoUint256,
    Casting.intoUint40,
    Casting.unwrap
} for SD21x18 global;
