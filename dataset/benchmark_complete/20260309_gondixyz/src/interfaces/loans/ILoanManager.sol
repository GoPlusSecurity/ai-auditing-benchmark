// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.21;

/// @title Multi Source Loan Interface
/// @author Florida St
/// @notice A multi source loan is one with multiple tranches.
interface ILoanManager {
    struct ProposedCaller {
        address caller;
        bool isLoanContract;
    }

    /// @notice Validate an offer. Can only be called by an accepted caller.
    /// @param tokenId The token id.
    /// @param offer The offer to validate.
    /// @param protocolFee The protocol fee.
    function validateOffer(uint256 tokenId, bytes calldata offer, uint256 protocolFee) external;

    /// @notice Add allowed callers.
    /// @param caller The callers to add.
    function addCaller(ProposedCaller calldata caller) external;

    /// @notice Called on loan repayment.
    /// @param loanId The loan id.
    /// @param principalAmount The principal amount.
    /// @param apr The APR.
    /// @param accruedInterest The accrued interest.
    /// @param protocolFee The protocol fee.
    /// @param startTime The start time.
    function loanRepayment(
        uint256 loanId,
        uint256 principalAmount,
        uint256 apr,
        uint256 accruedInterest,
        uint256 protocolFee,
        uint256 startTime
    ) external;

    /// @notice Called on loan liquidation.
    /// @param loanAddress The address of the loan contract since this might be called by a liquidator.
    /// @param loanId The loan id.
    /// @param principalAmount The principal amount.
    /// @param apr The APR.
    /// @param accruedInterest The accrued interest.
    /// @param protocolFee The protocol fee.
    /// @param received The received amount (from liquidation proceeds)
    /// @param startTime The start time.
    function loanLiquidation(
        address loanAddress,
        uint256 loanId,
        uint256 principalAmount,
        uint256 apr,
        uint256 accruedInterest,
        uint256 protocolFee,
        uint256 received,
        uint256 startTime
    ) external;
}
