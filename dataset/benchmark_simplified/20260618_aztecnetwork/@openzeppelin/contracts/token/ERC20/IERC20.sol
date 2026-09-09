// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}
