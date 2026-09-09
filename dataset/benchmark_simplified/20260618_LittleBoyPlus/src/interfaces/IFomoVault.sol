// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

interface IFomoVault {
    struct FomoState {
        uint32 timer;
        uint32 lastUpdate;
        address lastLpAdder;
    }

    function rebaseLastUpdate() external;

    function notifyTrade(bool isBuy, bool isSell, uint256 value, uint256 sellPart, uint256 spotPrice) external;

    function notifyLpAdd(address user, uint256 valueUsdt) external;
}
