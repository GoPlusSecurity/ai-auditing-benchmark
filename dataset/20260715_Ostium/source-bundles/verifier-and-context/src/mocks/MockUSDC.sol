// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import 'src/interfaces/IOstiumRegistry.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract MockUSDC is ERC20 {
    IOstiumRegistry public registry;

    error NotGov(address a);

    constructor(IOstiumRegistry _registry) ERC20('ostiumUSDC', 'ostUSDC') {
        registry = _registry;
    }

    modifier onlyGov() {
        _onlyGov(msg.sender);
        _;
    }

    function _onlyGov(address a) private view {
        if (a != registry.gov()) revert NotGov(a);
    }

    function mint(address to, uint256 amount) external onlyGov {
        _mint(to, amount);
    }

    function decimals() public pure override(ERC20) returns (uint8) {
        return 6;
    }
}
