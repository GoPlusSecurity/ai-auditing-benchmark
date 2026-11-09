// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface IVaultContract {
    enum ModuleStatus {
        NONE,        // not registered
        REGISTERED,  // registered
        ACTIVE,      // normal operation
        READ_ONLY,   // can read storage, cannot move tokens or write
        DEPRECATED,  // old module during soft upgrade
        DISABLED     // fully blocked
    }

    function getStats(address moduleAddress, address tokenAddress) external view returns (
        uint256 total_in,
        uint256 total_out,
        uint256 total_fee,
        uint256 withdraw_limit,
        uint256 withdrawable,
        ModuleStatus status,
        uint256 createdAt
    );
    function moduleDepositToken(address baseToken, uint256 amount, uint256 includedFee) external;
    function moduleWithdrawToken(address tokenAddress, address toAddress, uint256 amount) external;
    function moduleAvailableWithdrawToken(address tokenAddress, uint256) external view returns (uint256);
    function moduleRecordFee(address token, uint256 fee) external;

    function moduleReadStorageUint(bytes32 key) external view returns (uint256);
    function moduleWriteStorageUint(bytes32 key, uint256 value) external;
    function moduleReadStorageInt(bytes32 key) external view returns (int256);
    function moduleWriteStorageInt(bytes32 key, int256 value) external;
    function moduleReadStorageByte(bytes32 key) external view returns (bytes memory);
    function moduleWriteStorageByte(bytes32 key, bytes calldata value) external;
    function moduleReadStorageByte32(bytes32 key) external view returns (bytes32);
    function moduleWriteStorageByte32(bytes32 key, bytes32 value) external;
    function moduleReadStorageBool(bytes32 key) external view returns (bool);
    function moduleWriteStorageBool(bytes32 key, bool value) external;
    function moduleReadStorageString(bytes32 key) external view returns (string memory);
    function moduleWriteStorageString(bytes32 key, string calldata value) external;
}