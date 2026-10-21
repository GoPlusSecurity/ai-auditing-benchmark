// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.21;

import "../utils/TwoStepOwned.sol";
import "../InputChecker.sol";
import "../utils/WithProtocolFee.sol";
import "../../interfaces/callbacks/ILoanCallback.sol";

/// @title CallbackHandler
/// @author Florida St
/// @notice Handle callbacks from the MultiSourceLoan contract.
abstract contract CallbackHandler is WithProtocolFee {
    using InputChecker for address;

    /// @notice For security reasons we only allow a whitelisted set of callback contracts.
    mapping(address callbackContract => bool isWhitelisted) internal _isWhitelistedCallbackContract;

    address private immutable _multiSourceLoan;

    event WhitelistedCallbackContractAdded(address contractAdded);
    event WhitelistedCallbackContractRemoved(address contractRemoved);

    constructor(address __owner, uint256 _minWaitTime, ProtocolFee memory __protocolFee)
        WithProtocolFee(__owner, _minWaitTime, __protocolFee)
    {}

    /// @notice Add a whitelisted callback contract.
    /// @param _contract Address of the contract.
    function addWhitelistedCallbackContract(address _contract) external onlyOwner {
        _contract.checkNotZero();
        _isWhitelistedCallbackContract[_contract] = true;

        emit WhitelistedCallbackContractAdded(_contract);
    }

    /// @notice Remove a whitelisted callback contract.
    /// @param _contract Address of the contract.
    function removeWhitelistedCallbackContract(address _contract) external onlyOwner {
        _isWhitelistedCallbackContract[_contract] = false;

        emit WhitelistedCallbackContractRemoved(_contract);
    }

    /// @return Whether a callback contract is whitelisted
    function isWhitelistedCallbackContract(address _contract) external view returns (bool) {
        return _isWhitelistedCallbackContract[_contract];
    }

    /// @notice Handle the afterPrincipalTransfer callback.
    /// @param _loan Loan.
    /// @param _callbackAddress Callback address.
    /// @param _callbackData Callback data.
    /// @param _fee Fee.
    function handleAfterPrincipalTransferCallback(
        IMultiSourceLoan.Loan memory _loan,
        address _callbackAddress,
        bytes memory _callbackData,
        uint256 _fee
    ) internal {
        if (
            !_isWhitelistedCallbackContract[_callbackAddress]
                || ILoanCallback(_callbackAddress).afterPrincipalTransfer(_loan, _fee, _callbackData)
                    != ILoanCallback.afterPrincipalTransfer.selector
        ) {
            revert ILoanCallback.InvalidCallbackError();
        }
    }

    /// @notice Handle the afterNFTTransfer callback.
    /// @param _loan Loan.
    /// @param _callbackAddress Callback address.
    /// @param _callbackData Callback data.
    function handleAfterNFTTransferCallback(
        IMultiSourceLoan.Loan memory _loan,
        address _callbackAddress,
        bytes calldata _callbackData
    ) internal {
        if (
            !_isWhitelistedCallbackContract[_callbackAddress]
                || ILoanCallback(_callbackAddress).afterNFTTransfer(_loan, _callbackData)
                    != ILoanCallback.afterNFTTransfer.selector
        ) {
            revert ILoanCallback.InvalidCallbackError();
        }
    }
}
