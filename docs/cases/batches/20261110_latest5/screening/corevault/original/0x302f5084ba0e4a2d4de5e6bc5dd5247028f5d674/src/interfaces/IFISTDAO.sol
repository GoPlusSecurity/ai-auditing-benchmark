// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title  IFISTDAO -- minimal interface for the FISTDAO parent token
/// @notice Used by Treasury to burn directly after the 10% deposit buy (requirements doc section 2)
interface IFISTDAO is IERC20 {
  function burn(uint256 amount) external;
}
