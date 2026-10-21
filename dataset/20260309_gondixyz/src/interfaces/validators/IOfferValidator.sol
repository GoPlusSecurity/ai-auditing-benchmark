// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "../loans/IMultiSourceLoan.sol";

/// @title Interface for  Loan Offer Validators.
/// @author Florida St
/// @notice Verify the given `_offer` is valid for `_tokenId` and `_validatorData`.
interface IOfferValidator {
    error InvalidAddressError(address one, address two);
    error InvalidCollateralIdError();

    /// @notice Validate a loan offer.
    /// @param _offer The loan offer to validate.
    /// @param _nftCollateralAddress The NFT collateral address to validate.
    /// @param _tokenId The token ID to validate.
    /// @param _validatorData The validator data to validate.
    function validateOffer(
        IMultiSourceLoan.LoanOffer calldata _offer,
        address _nftCollateralAddress,
        uint256 _tokenId,
        bytes calldata _validatorData
    ) external view;
}
