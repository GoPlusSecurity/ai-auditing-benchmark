// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../verifiers/compose/ComposeVerifier.sol";

/// @title MainnetVerifier
/// @notice SGX-GETH + (SGX-RETH or RISC0 or SP1), or SGX-RETH + (RISC0 or SP1) verifier
/// @custom:security-contact security@taiko.xyz
contract MainnetVerifier is ComposeVerifier {
    /// @notice Creates a new MainnetVerifier instance
    /// @param _sgxGethVerifier Address of the SGX-GETH verifier
    /// @param _sgxRethVerifier Address of the SGX-RETH verifier
    /// @param _risc0RethVerifier Address of the RISC0-RETH verifier
    /// @param _sp1RethVerifier Address of the SP1-RETH verifier
