// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOFTCore} from "./IOFTCore.sol";
import {ISolidStateERC20} from "lib/solidstate-solidity/contracts/token/ERC20/ISolidStateERC20.sol";

/// @dev Interface of the OFT standard
interface IOFT is IOFTCore, ISolidStateERC20 {
    error OFT_InsufficientAllowance();
}
