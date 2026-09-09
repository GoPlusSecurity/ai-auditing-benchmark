// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2;

import {IERC20} from "../IERC20.sol";

interface IERC20Metadata is IERC20 {
    function decimals() external view returns (uint8);
}
