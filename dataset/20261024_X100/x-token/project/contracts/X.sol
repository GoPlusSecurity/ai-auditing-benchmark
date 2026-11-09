// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract X is ERC20, ERC20Permit {

    constructor()
        ERC20("X100", "X")
        ERC20Permit("X100")
    {
        _mint(_msgSender(), 14_000_000_000_000);
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}
