//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "hardhat/console.sol";
import "./base/ERC20Token.sol";
import "./interfaces/IERC20Errors.sol";

contract Token is ERC20Token{
    constructor(string memory __name,string memory __symbol, uint256 __totalSupply)
    ERC20Token(__name,__symbol,__totalSupply)
    {

    }

    modifier onlyOwner(){
        if(msg.sender != owner()){
            revert ERC20AccessDeny(msg.sender);
        }
        _;
    }
}