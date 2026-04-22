// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {XPLBase} from "./XPLBase.sol";

contract XPL is XPLBase {
    constructor(
        address _usdt,
        address _router,
        address _staking,
        address _marketingAddress
    ) XPLBase(_usdt, _router, _staking, _marketingAddress) {}
}