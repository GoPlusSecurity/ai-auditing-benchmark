// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IMokeAC.sol";

/**
 * @title MokeAC
 * @dev Activation Code token (MOKE-AC)
 * - Unlimited supply, minted as dynamic rewards
 * - 1 token = 1 USDT value
 * - Freely tradeable/transferable
 * - Burned when consumed during participation
 */
contract MokeAC is ERC20, ERC20Burnable, Ownable, Pausable, IMokeAC {
    using SafeERC20 for IERC20;

    mapping(address => bool) public isMinter;

    event MinterSet(address indexed minter, bool status);
    event EmergencyWithdraw(address indexed token, uint256 amount, address indexed to);

    constructor() ERC20("MOKE Activation Code", "MOKE-AC") Ownable(msg.sender) {}

    modifier onlyMinter() {
        require(isMinter[msg.sender] || msg.sender == owner(), "Not minter");
        _;
    }

    function setMinter(address minter, bool status) external onlyOwner {
        require(minter != address(0), "Invalid minter");
        isMinter[minter] = status;
        emit MinterSet(minter, status);
    }

    function mint(address to, uint256 amount) external override onlyMinter whenNotPaused {
        _mint(to, amount);
    }

    function burnFrom(address account, uint256 amount) public override(ERC20Burnable, IMokeAC) {
        super.burnFrom(account, amount);
    }

    function balanceOf(address account) public view override(ERC20, IMokeAC) returns (uint256) {
        return super.balanceOf(account);
    }

    function transfer(address to, uint256 amount) public override(ERC20, IMokeAC) returns (bool) {
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override(ERC20, IMokeAC) returns (bool) {
        return super.transferFrom(from, to, amount);
    }

    function approve(address spender, uint256 amount) public override(ERC20, IMokeAC) returns (bool) {
        return super.approve(spender, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            (bool sent,) = payable(owner()).call{value: amount}("");
            require(sent, "BNB transfer failed");
        } else {
            IERC20(token).safeTransfer(owner(), amount);
        }
        emit EmergencyWithdraw(token, amount, owner());
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    receive() external payable {}
}
