// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { RevertContext } from "../../../contracts/Revert.sol";

/// @title IZetaConnectorEvents
/// @notice Interface for the events emitted by the ZetaConnector contracts.
interface IZetaConnectorEvents {
    /// @notice Emitted when tokens are withdrawn.
    /// @param to The address to which the tokens are withdrawn.
    /// @param amount The amount of tokens withdrawn.
    event Withdrawn(address indexed to, uint256 amount);

    /// @notice Emitted when tokens are withdrawn and a contract is called.
    /// @param to The address to which the tokens are withdrawn.
    /// @param amount The amount of tokens withdrawn.
    /// @param data The calldata passed to the contract call.
    event WithdrawnAndCalled(address indexed to, uint256 amount, bytes data);

    /// @notice Emitted when tokens are withdrawn and a contract is called with a revert callback.
    /// @param to The address to which the tokens are withdrawn.
    /// @param amount The amount of tokens withdrawn.
    /// @param data The calldata passed to the contract call.
    /// @param revertContext Revert context to pass to onRevert.
    event WithdrawnAndReverted(address indexed to, uint256 amount, bytes data, RevertContext revertContext);

    /// @notice Emitted when tss address is updated
    /// @param oldTSSAddress old tss address
    /// @param newTSSAddress new tss address
    event UpdatedZetaConnectorTSSAddress(address oldTSSAddress, address newTSSAddress);
}
