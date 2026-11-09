// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev A contract whose accounting is denominated in a single primary ERC20 token.
 */
interface ITokenSource {
    /**
     * @dev Returns the primary token this contract operates on.
     */
    function token() external view returns (IERC20);
}
