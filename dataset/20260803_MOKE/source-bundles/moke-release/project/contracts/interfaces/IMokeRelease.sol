// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IMokeRelease {
    function addReleaseQuota(address user, uint256 quotaUsdt) external;
    function claim() external payable;
    function settle() external;
    function setDailyRate(uint256 _rate) external;
    function getPendingRelease(address user) external view returns (uint256 mokeAmount);
    function getUserRelease(address user) external view returns (
        uint256 totalQuota,
        uint256 releasedQuota,
        uint256 pendingUsdt,
        uint256 lastClaimTime
    );
}
