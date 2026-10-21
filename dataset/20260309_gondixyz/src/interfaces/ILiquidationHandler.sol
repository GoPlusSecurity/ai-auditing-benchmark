// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.21;

import "./loans/IMultiSourceLoan.sol";

/// @title Interface for liquidation handlers.
/// @author Florida St
/// @notice Liquidation Handler
interface ILiquidationHandler {
    /// @return Liquidator contract address
    function getLiquidator() external returns (address);

    /// @notice Updates the liquidation contract.
    /// @param loanLiquidator New liquidation contract.
    function updateLiquidationContract(address loanLiquidator) external;

    /// @notice Updates the auction duration for liquidations.
    /// @param _newDuration New auction duration.
    function updateLiquidationAuctionDuration(uint48 _newDuration) external;

    /// @return auctionDuration Returns the auction's duration for liquidations.
    function getLiquidationAuctionDuration() external returns (uint48);
}
