// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBToken is IERC20 {
  function mint(address to, uint256 amount) external;
  function burnFrom(address from, uint256 amount) external;
  // The project's BToken has EIP-2612 permit built in; external BNI lacks this, so in production B goes through the "wallet direct push + CREATE2 proxy" zero-approval path
  function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
}
