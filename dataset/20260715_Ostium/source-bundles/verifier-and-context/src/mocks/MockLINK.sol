// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract MockLINK is ERC20 {
    constructor() ERC20('LINK', 'LINK') {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function transferAndCall(address _to, uint256 _value, bytes memory) public virtual returns (bool success) {
        super.transfer(_to, _value);
        return true;
    }
}
