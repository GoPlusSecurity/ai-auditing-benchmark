// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IMokeReferral {
    function bind(address referrer) external;
    function bindFor(address user, address referrer) external;
    function getReferrer(address user) external view returns (address);
    function getDirectReferrals(address user) external view returns (address[] memory);
    function getDirectReferralCount(address user) external view returns (uint256);
    function getTotalReferrals(address user) external view returns (uint256);
    function getTeamPerformance(address user) external view returns (uint256);
    function getReferrerChain(address user, uint256 depth) external view returns (address[] memory);
    function addTeamPerformance(address user, uint256 amount) external;
    function markParticipant(address user) external;
    function isParticipant(address user) external view returns (bool);
    function effectiveReferralCount(address user) external view returns (uint256);
}
