// SPDX-License-Identifier: GPL-2.0-only

pragma solidity >=0.6.10 <0.8.0;

interface IRollupProcessor {
    function feeDistributor() external view returns (address);

    function escapeHatch(
        bytes calldata proofData,
        bytes calldata signatures,
        bytes calldata viewingKeys
    ) external;

    function setVerifier(address verifierAddress) external;

    function setSupportedAsset(address linkedToken, bool supportsPermit) external;

    function setAssetPermitSupport(uint256 assetId, bool supportsPermit) external;

    function getSupportedAsset(uint256 assetId) external view returns (address);

    function getEscapeHatchStatus() external view returns (bool, uint256);
}
