// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

/// @title Interface Loan Manager Registry
/// @author Florida St
/// @notice Interface for a Loan Manager Registry.
interface ILoanManagerRegistry {
    /// @notice Add a loan manager to the registry
    /// @param _loanManager Address of the loan manager
    function addLoanManager(address _loanManager) external;

    /// @notice Remove a loan manager from the registry
    /// @param _loanManager Address of the loan manager
    function removeLoanManager(address _loanManager) external;

    /// @notice Check if a loan manager is registered
    /// @param _loanManager Address of the loan manager
    /// @return True if the loan manager is registered
    function isLoanManager(address _loanManager) external view returns (bool);
}
