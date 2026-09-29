// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../IProofVerifier.sol";

/// @title ComposeVerifier
/// @notice This contract is an abstract verifier that composes multiple sub-verifiers to validate
/// proofs.
/// It ensures that a set of sub-proofs are verified by their respective verifiers before
/// considering the overall proof as valid.
/// @custom:security-contact security@taiko.xyz
abstract contract ComposeVerifier is IProofVerifier {
    enum VerifierType {
        NONE,
        SGX_GETH,
        TDX_GETH,
        OP,
        SGX_RETH,
        RISC0_RETH,
        SP1_RETH
    }

    struct SubProof {
        VerifierType verifierId;
        bytes proof;
    }

    /// @notice Immutable verifier addresses
    /// The sgx/tdx-GethVerifier is the core verifier required in every proof.
    /// All other proofs share its status root, despite different public inputs
    /// due to different verification types.
    /// proofs come from geth client
    address public immutable sgxGethVerifier;
    address public immutable tdxGethVerifier;
    /// op for test purpose
    address public immutable opVerifier;
    /// proofs come from reth client
    address public immutable sgxRethVerifier;
    address public immutable risc0RethVerifier;
    address public immutable sp1RethVerifier;

