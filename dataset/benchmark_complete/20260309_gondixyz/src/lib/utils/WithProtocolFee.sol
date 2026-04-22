// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.21;

import "./TwoStepOwned.sol";

import "../InputChecker.sol";

abstract contract WithProtocolFee is TwoStepOwned {
    using InputChecker for address;

    /// @notice Recipient address and fraction of gains charged by the protocol.
    struct ProtocolFee {
        address recipient;
        uint256 fraction;
    }

    uint256 public constant FEE_UPDATE_NOTICE = 7 days;

    /// @notice Protocol fee charged on gains.
    ProtocolFee internal _protocolFee;
    /// @notice Set as the target new protocol fee.
    ProtocolFee internal _pendingProtocolFee;
    /// @notice Set when the protocol fee updating mechanisms starts.
    uint256 internal _pendingProtocolFeeSetTime;

    event ProtocolFeeUpdated(ProtocolFee fee);
    event ProtocolFeePendingUpdate(ProtocolFee fee);

    error TooEarlyError(uint256 _pendingProtocolFeeSetTime);

    /// @notice Constructor
    /// @param _owner The owner of the contract
    /// @param _minWaitTime The time to wait before a new owner can be set
    /// @param __protocolFee The protocol fee
    constructor(address _owner, uint256 _minWaitTime, ProtocolFee memory __protocolFee)
        TwoStepOwned(_owner, _minWaitTime)
    {
        _protocolFee = __protocolFee;
        _pendingProtocolFeeSetTime = type(uint256).max;
    }

    /// @return protocolFee The Protocol fee.
    function getProtocolFee() external view returns (ProtocolFee memory) {
        return _protocolFee;
    }

    /// @return pendingProtocolFee The pending protocol fee.
    function getPendingProtocolFee() external view returns (ProtocolFee memory) {
        return _pendingProtocolFee;
    }

    /// @return protocolFeeSetTime Time when the protocol fee was set to be changed.
    function getPendingProtocolFeeSetTime() external view returns (uint256) {
        return _pendingProtocolFeeSetTime;
    }

    /// @notice Kicks off the process to update the protocol fee.
    /// @param _newProtocolFee New protocol fee.
    function updateProtocolFee(ProtocolFee calldata _newProtocolFee) external onlyOwner {
        _newProtocolFee.recipient.checkNotZero();

        _pendingProtocolFee = _newProtocolFee;
        _pendingProtocolFeeSetTime = block.timestamp;

        emit ProtocolFeePendingUpdate(_pendingProtocolFee);
    }

    /// @notice Set the protocol fee if enough notice has been given.
    function setProtocolFee() external virtual {
        if (block.timestamp < _pendingProtocolFeeSetTime + FEE_UPDATE_NOTICE) {
            revert TooSoonError();
        }
        ProtocolFee memory protocolFee = _pendingProtocolFee;
        _protocolFee = protocolFee;

        emit ProtocolFeeUpdated(protocolFee);
    }
}
