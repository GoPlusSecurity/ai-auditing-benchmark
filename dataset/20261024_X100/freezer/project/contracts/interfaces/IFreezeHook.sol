// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @dev Receiver of freezing notifications from a {Freezer}.
 */
interface IFreezeHook {
    /**
     * @dev Called by the freezer after each deposit is recorded. A revert here reverts
     * the deposit, so implementations must decline quietly instead of reverting.
     * `firstFreezeAt` is the depositor's first-ever deposit time.
     */
    function onFreeze(address owner, address referrer, uint256 amount, uint256 firstFreezeAt) external;
}
