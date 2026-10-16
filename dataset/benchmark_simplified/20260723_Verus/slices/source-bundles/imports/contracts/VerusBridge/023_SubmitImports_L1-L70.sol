// SPDX-License-Identifier: MIT
// Bridge between ethereum and verus

pragma solidity >=0.8.9;
pragma abicoder v2;

import "../Libraries/VerusObjects.sol";
import "../Libraries/VerusConstants.sol";
import "./Token.sol";
import "../Storage/StorageMaster.sol";
import "./CreateExports.sol";
import "./TokenManager.sol";

interface IVerusToken {
    function supply() external view returns (uint256);
}


contract SubmitImports is VerusStorage {

    address immutable VETH;
    address immutable BRIDGE;
    address immutable VERUS;
    address immutable DAI;
    address immutable MKR;
    uint256 immutable DEPLOYED_AT;
    uint256 constant THREE_YEARS = 3 * 365 days;

    constructor(address vETH, address Bridge, address Verus, address Dai, address Mkr){

        VETH = vETH;
        BRIDGE = Bridge;
        VERUS = Verus;
        DAI = Dai;
        MKR = Mkr;
        DEPLOYED_AT = block.timestamp;
    }

    //reset to empty 9-July-26
    function initialize() external {}

    uint32 constant ELVCHOBJ_TXID_OFFSET = 32;
    uint32 constant ELVCHOBJ_NVINS_OFFSET = 45;
    // Minimum byte length of a valid CTransactionHeader elVchObj:
    // 32 (txHash) + 1 (struct ver) + 4 (nVersion) + 4 (nVersionGroupId) + 4*4 (counts) = 57
    uint32 constant ELVCHOBJ_MIN_LENGTH = 57;
    // CTransactionHeader struct version — only version 1 is supported; other values mean
    // the field layout is unknown and the offsets below would be wrong.
    uint8 constant HEADER_STRUCT_VERSION = 1;
    // Offset used to read the struct-version byte: mload(elVchObj+33) puts data[32] in the
    // rightmost (uint8) position of the 32-byte word.
    uint32 constant ELVCHOBJ_STRUCT_VERSION_OFFSET = 33;
    uint32 constant ELVCHOBJ_NVOUTS_OFFSET = 49;
    uint32 constant ELVCHOBJ_NSHIELDEDSPENDS_OFFSET = 53;
    uint32 constant ELVCHOBJ_NSHIELDEDOUTPUTS_OFFSET = 57;
    uint32 constant FORKS_NOTARY_PROPOSER_POSITION = 96;
    uint32 constant TYPE_REFUND = 1;
    uint constant TYPE_BYTE_LOCATION_IN_UINT176 = 168;
    uint8 constant TYPE_REFUND_BYTES32_LOCATION = 244;
    bytes32 constant SUBMIT_IMPORTS_REENTRANCY_GUARD = "submitimports.reentrancy.lock";
    enum Currency {VETH, DAI, VERUS, MKR}

    // Parsed fields from the CTransactionHeader serialized in components[0].elVchObj.
    // nLockTime, nExpiryHeight and nValueBalance are not needed and are excluded.
    struct TxHeaderData {
        bytes32 txHash;
        uint32 nVins;
        uint32 nVouts;
        uint32 nShieldedSpends;
        uint32 nShieldedOutputs;
