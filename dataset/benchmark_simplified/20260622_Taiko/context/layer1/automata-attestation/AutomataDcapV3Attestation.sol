// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IAttestation } from "./interfaces/IAttestation.sol";
import { ISigVerifyLib } from "./interfaces/ISigVerifyLib.sol";
import { EnclaveIdStruct } from "./lib/EnclaveIdStruct.sol";
import { PEMCertChainLib } from "./lib/PEMCertChainLib.sol";
import { V3Parser } from "./lib/QuoteV3Auth/V3Parser.sol";
import { V3Struct } from "./lib/QuoteV3Auth/V3Struct.sol";
import { TCBInfoStruct } from "./lib/TCBInfoStruct.sol";
import { IPEMCertChainLib } from "./lib/interfaces/IPEMCertChainLib.sol";
import { BytesUtils } from "./utils/BytesUtils.sol";
import { EfficientHashLib } from "solady/src/utils/EfficientHashLib.sol";
import { LibString } from "solady/src/utils/LibString.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";

import "./AutomataDcapV3Attestation_Layout.sol"; // DO NOT DELETE

/// @title AutomataDcapV3Attestation
/// @custom:security-contact security@taiko.xyz
contract AutomataDcapV3Attestation is IAttestation, EssentialContract {
    using BytesUtils for bytes;

    // https://github.com/intel/SGXDataCenterAttestationPrimitives/blob/e7604e02331b3377f3766ed3653250e03af72d45/QuoteVerification/QVL/Src/AttestationLibrary/src/CertVerification/X509Constants.h#L64
    uint256 internal constant CPUSVN_LENGTH = 16;

    // keccak256(hex"0ba9c4c0c0c86193a3fe23d6b02cda10a8bbd4e88e48b4458561a36e705525f567918e2edc88e40d860bd0cc4ee26aacc988e505a953558c453f6b0904ae7394")
    // the uncompressed (0x04) prefix is not included in the pubkey pre-image
    bytes32 internal constant ROOTCA_PUBKEY_HASH =
        0x89f72d7c488e5b53a77c23ebcb36970ef7eb5bcf6658e9b8292cfbe4703a8473;

    uint8 internal constant INVALID_EXIT_CODE = 255;

    ISigVerifyLib public sigVerifyLib; // slot 1
    IPEMCertChainLib public pemCertLib; // slot 2

    bool public checkLocalEnclaveReport; // slot 3
    mapping(bytes32 enclave => bool trusted) public trustedUserMrEnclave; // slot 4
    mapping(bytes32 signer => bool trusted) public trustedUserMrSigner; // slot 5

    // Quote Collateral Configuration

    // Index definition:
    // 0 = Quote PCKCrl
    // 1 = RootCrl
    mapping(uint256 idx => mapping(bytes serialNum => bool revoked)) public serialNumIsRevoked; // slot
    // 6
    // fmspc => tcbInfo
    mapping(string fmspc => TCBInfoStruct.TCBInfo tcbInfo) public tcbInfo; // slot 7
    EnclaveIdStruct.EnclaveId public qeIdentity; // takes 4 slots, slot 8,9,10,11

    uint256[39] __gap;

    event MrSignerUpdated(bytes32 indexed mrSigner, bool trusted);
    event MrEnclaveUpdated(bytes32 indexed mrEnclave, bool trusted);
    event TcbInfoJsonConfigured(string indexed fmspc, TCBInfoStruct.TCBInfo tcbInfoInput);
    event QeIdentityConfigured(EnclaveIdStruct.EnclaveId qeIdentityInput);
    event LocalReportCheckToggled(bool checkLocalEnclaveReport);
    event RevokedCertSerialNumAdded(uint256 indexed index, bytes serialNum);
    event RevokedCertSerialNumRemoved(uint256 indexed index, bytes serialNum);

    // @notice Initializes the contract.
    /// @param sigVerifyLibAddr Address of the signature verification library.
    /// @param pemCertLibAddr Address of certificate library.
