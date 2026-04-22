// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "../../interfaces/ILoanLiquidator.sol";

/// @title Interface for Loans.
/// @author Florida St
/// @notice Basic Loan
interface IBaseLoan {
    /// @notice Minimum improvement (in BPS) required for a strict improvement.
    /// @param principalAmount Minimum delta of principal amount.
    /// @param interest Minimum delta of interest.
    /// @param duration Minimum delta of duration.
    struct ImprovementMinimum {
        uint256 principalAmount;
        uint256 interest;
        uint256 duration;
    }

    /// @notice Arbitrary contract to validate offers implementing `IBaseOfferValidator`.
    /// @param validator Address of the validator contract.
    /// @param arguments Arguments to pass to the validator.
    struct OfferValidator {
        address validator;
        bytes arguments;
    }

    /// @notice Total number of loans issued by this contract.
    function getTotalLoansIssued() external view returns (uint256);

    /// @notice Cancel offer for `msg.sender`. Each lender has unique offerIds.
    /// @param _offerId Offer ID.
    function cancelOffer(uint256 _offerId) external;

    /// @notice Cancel renegotiation offer. Similar to offers.
    /// @param _renegotiationId Renegotiation offer ID.
    function cancelRenegotiationOffer(uint256 _renegotiationId) external;
}
