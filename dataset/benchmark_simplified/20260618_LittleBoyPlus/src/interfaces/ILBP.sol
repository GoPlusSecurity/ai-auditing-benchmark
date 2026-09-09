// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILBP is IERC20 {
    function rawBalanceOf(address account) external view returns (uint256);
}
