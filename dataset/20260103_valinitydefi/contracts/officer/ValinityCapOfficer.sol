// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ReentrancyGuardTransient } from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import { RegistrarClientInitializable } from "../RegistrarClient.sol";
import { ValinityAcquisitionOfficer } from "./ValinityAcquisitionOfficer.sol";
import { ValinityToken } from "../token/ValinityToken.sol";
import { ValinityReserveTreasury } from "../treasury/ValinityReserveTreasury.sol";
import { ValinityAssetRegistry } from "../ValinityAssetRegistry.sol";

contract ValinityCapOfficer is UUPSUpgradeable, AccessControl, ReentrancyGuardTransient, RegistrarClientInitializable {
    struct AssetInfo {
        address asset;
        uint256 value;
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OFFICER_ROLE = keccak256("OFFICER_ROLE");

    bytes32 internal constant VAO = keccak256("ValinityAcquisitionOfficer");
    bytes32 internal constant VAR = keccak256("ValinityAssetRegistry");
    bytes32 internal constant VAT = keccak256("ValinityAcquisitionTreasury");
    bytes32 internal constant VRT = keccak256("ValinityReserveTreasury");
    bytes32 internal constant VYTOKEN = keccak256("ValinityToken");

    uint8 internal constant DEFAULT_DECIMALS = 18;

    mapping(address => uint256) internal _caps;

    uint64 public lastReductionTimestamp;
    uint256 public assetCapFloor;
    uint32 public assetCapReductionInterval;

    error InvalidAddress();
    error InvalidAsset();
    error UnsupportedAsset();
    error ZeroAmount();
    error CapUnderflow();
    error ReductionTooSoon();
    error InvalidFloor();
    error InvalidInterval();

    event CapUpdated(address indexed asset, uint256 oldCap, uint256 newCap);
    event FeesProcessed(uint256 amount);
    event FeesMigrated(address indexed from, address indexed to, uint256 amount);
    event FeesSentToTreasury(address indexed treasury, uint256 amount);
    event CapReductionApplied(address indexed asset, uint256 reductionAmount, uint256 newCap);
    event AssetCapFloorUpdated(uint256 value);
    event AssetCapReductionIntervalUpdated(uint32 value);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address registrarAddress, address adminAddress) public initializer {
        __RegistrarClient_init(registrarAddress);

        if (adminAddress == address(0)) {
            revert InvalidAddress();
        }

        _grantRole(DEFAULT_ADMIN_ROLE, adminAddress);
        _grantRole(ADMIN_ROLE, adminAddress);
        _setRoleAdmin(OFFICER_ROLE, ADMIN_ROLE);

        lastReductionTimestamp = uint64(block.timestamp);
        assetCapFloor = 10_000 * 10 ** 18;
        assetCapReductionInterval = 27 days;
    }

    function getAssetCap(address asset) public view returns (uint256) {
        return _caps[asset];
    }

    function setAssetCap(address asset, uint256 amount) external onlyRole(ADMIN_ROLE) {
        if (asset == address(0)) {
            revert InvalidAsset();
        }
        if (!ValinityAssetRegistry(_registrar.getContract(VAR)).isSupported(asset)) {
            revert UnsupportedAsset();
        }

        uint256 oldCap = _caps[asset];
        _caps[asset] = amount;

        emit CapUpdated(asset, oldCap, amount);
    }

    function setAssetCapFloor(uint256 newFloor) external onlyRole(ADMIN_ROLE) {
        if (newFloor == assetCapFloor) return;
        if (newFloor == 0) {
            revert InvalidFloor();
        }
        assetCapFloor = newFloor;
        emit AssetCapFloorUpdated(newFloor);
    }

    function setAssetCapReductionInterval(uint32 newInterval) external onlyRole(ADMIN_ROLE) {
        if (newInterval == assetCapReductionInterval) return;
        if (newInterval == 0) {
            revert InvalidInterval();
        }
        assetCapReductionInterval = newInterval;
        emit AssetCapReductionIntervalUpdated(newInterval);
    }

    function increaseAssetCap(address asset, uint256 amount) external onlyRole(OFFICER_ROLE) {
        if (asset == address(0)) {
            revert InvalidAsset();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }

        uint256 oldCap = _caps[asset];
        uint256 newCap = oldCap + amount;
        _caps[asset] = newCap;

        emit CapUpdated(asset, oldCap, newCap);
    }

    function decreaseAssetCap(address asset, uint256 amount) external onlyRole(OFFICER_ROLE) {
        if (asset == address(0)) {
            revert InvalidAsset();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }

        uint256 oldCap = _caps[asset];

        if (oldCap < amount || oldCap - amount < assetCapFloor) {
            revert CapUnderflow();
        }

        uint256 newCap = oldCap - amount;
        _caps[asset] = newCap;

        emit CapUpdated(asset, oldCap, newCap);
    }

    function getAssetCollateralized(address asset) external view returns (uint256) {
        return ValinityReserveTreasury(_registrar.getContract(VRT)).collateralizedOf(asset);
    }

    function getTotalUncollateralized() external view returns (uint256) {
        ValinityToken vyToken = ValinityToken(_registrar.getContract(VYTOKEN));
        address vatAddress = _registrar.getContract(VAT);
        address vrtAddress = _registrar.getContract(VRT);

        uint256 totalBalance = vyToken.balanceOf(vatAddress) + vyToken.balanceOf(vrtAddress) + vyToken.balanceOf(address(this));
        return vyToken.totalSupply() - totalBalance;
    }

    /**
     * Apply cap reductions using accumulated transaction fees
     * 1. Check the cooldown
     * 2. Calculate total VY fees since last call
     * 3. Process assets with lowest LTV-F
     */
    function applyCapReductions() external nonReentrant {
        // Check cooldown period
        if (uint64(block.timestamp) < lastReductionTimestamp + assetCapReductionInterval) {
            revert ReductionTooSoon();
        }

        uint256 currentBalance = ValinityToken(_registrar.getContract(VYTOKEN)).balanceOf(address(this));

        if (currentBalance == 0) {
            // Update timestamp even if no fees to process
            lastReductionTimestamp = uint64(block.timestamp);
            return;
        }

        // Get all supported assets
        address[] memory assets = ValinityAssetRegistry(_registrar.getContract(VAR)).getAssets();

        uint256 remainingFees = _processLowestLTVFAssets(assets, currentBalance);
        uint256 feesProcessed = currentBalance - remainingFees;

        lastReductionTimestamp = uint64(block.timestamp);

        // Send processed fees to VAT
        if (feesProcessed > 0) {
            address vatAddress = _registrar.getContract(VAT);
            ValinityToken(_registrar.getContract(VYTOKEN)).transfer(vatAddress, feesProcessed);
            emit FeesSentToTreasury(vatAddress, feesProcessed);
        }

        emit FeesProcessed(feesProcessed);
    }

    function migrateTo(address to) external onlyRole(ADMIN_ROLE) {
        if (to == address(0)) {
            revert InvalidAddress();
        }

        uint256 balance = ValinityToken(_registrar.getContract(VYTOKEN)).balanceOf(address(this));

        if (balance > 0) {
            ValinityToken(_registrar.getContract(VYTOKEN)).transfer(to, balance);
        }

        emit FeesMigrated(address(this), to, balance);
    }

    function _processLowestLTVFAssets(address[] memory assets, uint256 remainingFees) internal returns (uint256) {
        // Create array of assets with their LTV-F values
        AssetInfo[] memory assetsByLTVF = new AssetInfo[](assets.length);
        uint256 count = 0;
        ValinityAcquisitionOfficer vao = ValinityAcquisitionOfficer(_registrar.getContract(VAO));

        for (uint256 i = 0; i < assets.length; i++) {
            assetsByLTVF[count] = AssetInfo({ asset: assets[i], value: vao.getLTVF(assets[i]) });
            count++;
        }

        if (count == 0) {
            return remainingFees;
        }

        // Sort by LTV-F (lowest first)
        _sortAssetsByValue(assetsByLTVF, count, true);

        // Calculate max reduction for the lowest-LTVF Asset (first in list)
        // Formula: `max(0, collateralCap_L × (1 − (LTVF_L / LTVF_high)))`
        // Where:
        // - collateralCap_L = VY collateral cap of the lowest-LTVF asset
        // - LTVF_L = current Lowest LTV across all assets
        // - LTVF_H = current Highest LTV across all assets
        uint256 lowestLTVFMaxReduction = 0;
        if (count > 1) {
            uint256 highestLTVF = assetsByLTVF[count - 1].value;
            uint256 lowestLTVF = assetsByLTVF[0].value;

            if (highestLTVF > lowestLTVF) {
                address lowestAsset = assetsByLTVF[0].asset;
                uint256 lowestCap = _caps[lowestAsset];
                uint256 reductionRatio = ((highestLTVF - lowestLTVF) * 1e18) / highestLTVF;
                lowestLTVFMaxReduction = (lowestCap * reductionRatio) / 1e18;
            }
        }

        // Apply reductions
        for (uint256 i = 0; i < count && remainingFees > 0; i++) {
            address asset = assetsByLTVF[i].asset;
            uint256 currentCap = _caps[asset];

            // Can't reduce below floor
            if (currentCap <= assetCapFloor) {
                continue;
            }

            uint256 maxReduction = currentCap - assetCapFloor;

            // For the asset with the lowest LTV-F, apply the calculated max reduction
            if (i == 0 && lowestLTVFMaxReduction > 0 && lowestLTVFMaxReduction < maxReduction) {
                maxReduction = lowestLTVFMaxReduction;
            }

            uint256 applied = _applyReductionToAsset(asset, currentCap, maxReduction, remainingFees);
            remainingFees -= applied;
        }

        return remainingFees;
    }

    function _applyReductionToAsset(address asset, uint256 currentCap, uint256 maxReduction, uint256 remainingFees) internal returns (uint256) {
        uint256 reductionAmount = remainingFees > maxReduction ? maxReduction : remainingFees;

        if (reductionAmount == 0) {
            return 0;
        }

        uint256 newCap = currentCap - reductionAmount;
        _caps[asset] = newCap;

        emit CapReductionApplied(asset, reductionAmount, newCap);
        emit CapUpdated(asset, currentCap, newCap);

        return reductionAmount;
    }

    function _sortAssetsByValue(AssetInfo[] memory assets, uint256 length, bool ascending) internal pure {
        // Simple bubble sort - could be optimized for larger arrays
        for (uint256 i = 0; i < length - 1; i++) {
            for (uint256 j = 0; j < length - i - 1; j++) {
                bool shouldSwap = ascending ? assets[j].value > assets[j + 1].value : assets[j].value < assets[j + 1].value;

                if (shouldSwap) {
                    AssetInfo memory temp = assets[j];
                    assets[j] = assets[j + 1];
                    assets[j + 1] = temp;
                }
            }
        }
    }

    function _getAssetDecimals(address asset) internal view returns (uint8) {
        try IERC20Metadata(asset).decimals() returns (uint8 dec) {
            return dec;
        } catch {
            return DEFAULT_DECIMALS;
        }
    }

    function _scaleDecimals(uint256 amount, uint8 fromDecimals, uint8 toDecimals) internal pure returns (uint256) {
        if (fromDecimals > toDecimals) {
            return amount / 10 ** (fromDecimals - toDecimals);
        } else if (fromDecimals < toDecimals) {
            return amount * 10 ** (toDecimals - fromDecimals);
        }
        return amount;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(ADMIN_ROLE) {}
}
