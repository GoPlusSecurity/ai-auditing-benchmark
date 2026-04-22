// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import { ValinityToken } from "../token/ValinityToken.sol";
import { RegistrarClient } from "../RegistrarClient.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract ValinityAcquisitionTreasury is AccessControl, RegistrarClient {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OFFICER_ROLE = keccak256("OFFICER_ROLE");
    bytes32 private constant VYTOKEN = keccak256("ValinityToken");

    error InvalidAddress();
    error InvalidAmount();

    event TokenTransferred(address indexed to, uint256 amount);
    event TreasuryMigrated(address oldTreasury, address newTreasury, uint256 amount);

    constructor(address registrarAddress, address adminAddress) RegistrarClient(registrarAddress) {
        if (adminAddress == address(0)) {
            revert InvalidAddress();
        }
        _grantRole(DEFAULT_ADMIN_ROLE, adminAddress);
        _grantRole(ADMIN_ROLE, adminAddress);
        _setRoleAdmin(OFFICER_ROLE, ADMIN_ROLE);
    }

    function transferToken(address to, uint256 amount) external onlyRole(OFFICER_ROLE) {
        if (to == address(0)) {
            revert InvalidAddress();
        }
        if (amount == 0) {
            revert InvalidAmount();
        }

        ValinityToken(_registrar.getContract(VYTOKEN)).transfer(to, amount);

        emit TokenTransferred(to, amount);
    }

    function migrateTo(address newTreasury) external onlyRole(ADMIN_ROLE) {
        if (newTreasury == address(0)) {
            revert InvalidAddress();
        }

        uint256 balance = ValinityToken(_registrar.getContract(VYTOKEN)).balanceOf(address(this));

        if (balance > 0) {
            ValinityToken(_registrar.getContract(VYTOKEN)).transfer(newTreasury, balance);
        }

        emit TreasuryMigrated(address(this), newTreasury, balance);
    }
}
