// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../lib/PEMCertChainLib.sol";
import "../../utils/BytesUtils.sol";
import "./V3Struct.sol";
import "solady/src/utils/Base64.sol";

/// @title V3Parser
/// @custom:security-contact security@taiko.xyz
library V3Parser {
    using BytesUtils for bytes;

    uint256 internal constant MINIMUM_QUOTE_LENGTH = 1020;
    bytes2 internal constant SUPPORTED_QUOTE_VERSION = 0x0300;
    bytes2 internal constant SUPPORTED_ATTESTATION_KEY_TYPE = 0x0200;
    // SGX only
    bytes4 internal constant SUPPORTED_TEE_TYPE = 0;
    bytes16 internal constant VALID_QE_VENDOR_ID = 0x939a7233f79c4ca9940a0db3957f0607;

    error V3PARSER_INVALID_QUOTE_LENGTN();
    error V3PARSER_INVALID_QUOTE_MEMBER_LENGTN();
    error V3PARSER_INVALID_QEREPORT_LENGTN();
    error V3PARSER_UNSUPPORT_CERTIFICATION_TYPE();
    error V3PARSER_INVALID_CERTIFICATION_CHAIN_SIZE();
    error V3PARSER_INVALID_CERTIFICATION_CHAIN_DATA();
    error V3PARSER_INVALID_ECDSA_SIGNATURE();
    error V3PARSER_INVALID_QEAUTHDATA_SIZE();

