// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ValinityReserveTreasury is AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OFFICER_ROLE = keccak256("OFFICER_ROLE");

    mapping(address => uint256) private _collateralizedVY;

    error InvalidAddress();
    error InvalidAsset();
    error InvalidRecipient();
    error InsufficientBalance();
    error InsufficientCollateralizedVY();
    error ZeroAmount();

    event TokenTransferred(address indexed asset, address indexed to, uint256 amount);
    event CollateralizedVYUpdated(address indexed asset, int256 delta);
    event TreasuryMigrated(address indexed oldTreasury, address indexed newTreasury, address[] tokens);

    constructor(address adminAddress) {
        if (adminAddress == address(0)) {
            revert InvalidAddress();
        }
        _grantRole(DEFAULT_ADMIN_ROLE, adminAddress);
        _grantRole(ADMIN_ROLE, adminAddress);
        _setRoleAdmin(OFFICER_ROLE, ADMIN_ROLE);
    }

    function transferToken(address asset, address to, uint256 amount) external onlyRole(OFFICER_ROLE) {
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (asset == address(0)) {
            revert InvalidAsset();
        }

        IERC20 token = IERC20(asset);

        token.safeTransfer(to, amount);

        emit TokenTransferred(asset, to, amount);
    }

    function increaseCollateralizedVY(address asset, uint256 vyAmount) external onlyRole(OFFICER_ROLE) {
        if (asset == address(0)) {
            revert InvalidAsset();
        }
        if (vyAmount == 0) {
            revert ZeroAmount();
        }

        _collateralizedVY[asset] += vyAmount;

        emit CollateralizedVYUpdated(asset, int256(vyAmount));
    }

    function decreaseCollateralizedVY(address asset, uint256 vyAmount) external onlyRole(OFFICER_ROLE) {
        if (asset == address(0)) {
            revert InvalidAsset();
        }
        if (vyAmount == 0) {
            revert ZeroAmount();
        }
        if (_collateralizedVY[asset] < vyAmount) {
            revert InsufficientCollateralizedVY();
        }

        _collateralizedVY[asset] -= vyAmount;

        emit CollateralizedVYUpdated(asset, -int256(vyAmount));
    }

    function collateralizedOf(address asset) external view returns (uint256) {
        return _collateralizedVY[asset];
    }

    function migrateTo(address newTreasury, address[] calldata tokens) external onlyRole(ADMIN_ROLE) {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0)) {
                revert InvalidAsset();
            }

            IERC20 token = IERC20(tokens[i]);
            uint256 balance = token.balanceOf(address(this));

            if (balance > 0) {
                token.safeTransfer(newTreasury, balance);
            }
        }

        emit TreasuryMigrated(address(this), newTreasury, tokens);
    }
}
