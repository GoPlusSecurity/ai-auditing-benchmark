// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ValinityAssetRegistry is AccessControl, UUPSUpgradeable, Initializable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct AssetConfig {
        bool acquisitionPaused;
    }

    address[] internal _assets;
    mapping(address => AssetConfig) internal _configs;
    mapping(address => bool) internal _supported;

    event AssetConfigSet(address indexed asset, AssetConfig config);
    event AssetAdded(address indexed asset, AssetConfig config);
    event AssetRemoved(address indexed asset);

    error InvalidAddress();
    error InvalidAsset();
    error AssetAlreadySupported();
    error AssetNotSupported();
    error InvalidERC20Contract();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address adminAddress) external initializer {
        if (adminAddress == address(0)) {
            revert InvalidAddress();
        }
        _grantRole(DEFAULT_ADMIN_ROLE, adminAddress);
        _grantRole(ADMIN_ROLE, adminAddress);
    }

    function getAssets() external view returns (address[] memory) {
        return _assets;
    }

    function getConfig(address asset) external view returns (AssetConfig memory) {
        return _configs[asset];
    }

    function setConfig(address asset, AssetConfig calldata config) external onlyRole(ADMIN_ROLE) {
        if (asset == address(0)) {
            revert InvalidAsset();
        }
        if (!_supported[asset]) {
            revert AssetNotSupported();
        }

        _configs[asset] = config;
        emit AssetConfigSet(asset, config);
    }

    function addAsset(address asset, AssetConfig calldata config) external onlyRole(ADMIN_ROLE) {
        if (asset == address(0)) {
            revert InvalidAsset();
        }
        if (_supported[asset]) {
            revert AssetAlreadySupported();
        }

        // Make sure asset address is ERC20 and not externally owned
        if (asset.code.length == 0) {
            revert InvalidERC20Contract();
        }
        try IERC20(asset).totalSupply() returns (uint256) {} catch {
            revert InvalidERC20Contract();
        }

        _assets.push(asset);
        _configs[asset] = config;
        _supported[asset] = true;

        emit AssetAdded(asset, config);
    }

    function removeAsset(address asset) external onlyRole(ADMIN_ROLE) {
        if (asset == address(0)) {
            revert InvalidAsset();
        }
        if (!_supported[asset]) {
            revert AssetNotSupported();
        }

        for (uint256 i = 0; i < _assets.length; i++) {
            if (_assets[i] == asset) {
                _assets[i] = _assets[_assets.length - 1];
                _assets.pop();
                break;
            }
        }

        delete _configs[asset];
        _supported[asset] = false;

        emit AssetRemoved(asset);
    }

    function isSupported(address asset) external view returns (bool) {
        return _supported[asset];
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(ADMIN_ROLE) {}
}
