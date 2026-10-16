// SPDX-License-Identifier: MIT
// Bridge between ethereum and verus

pragma solidity >=0.4.22;
pragma abicoder v2;
import "../Libraries/VerusObjects.sol";
import "./VerusBlake2b.sol";
import {VerusSerializer} from "../VerusBridge/VerusSerializer.sol";
import "../Libraries/VerusObjectsCommon.sol";
import "../VerusNotarizer/VerusNotarizer.sol";
import "./VerusMMR.sol";
import "../Storage/StorageMaster.sol";

contract VerusProof is VerusStorage  {
    
    address immutable VETH;
    address immutable BRIDGE;
    address immutable VERUS;
    uint constant FORKS_DATA_OFFSET_FOR_HEIGHT = 224;
    uint constant FORKS_PROPOSER_SLOT = 2;

    constructor(address vETH, address Bridge, address Verus){

        VETH = vETH;
        BRIDGE = Bridge;
        VERUS = Verus;
    }

    //reset to empty 9-July-26
    function initialize() external {}

    using VerusBlake2b for bytes;
    
    // these constants should be able to reference each other, as many are relative, but Solidity does not
    // allow referencing them and still considering the result a constant. For any changes to these constants,
    // which are designed to ensure smart transaction provability, care must be take to ensure that OUTPUT_SCRIPT_OFFSET
    // is present and substituted for all equivalent values (currently (32 + 8))
    uint8 constant CCE_EVAL_EXPORT = 0xc;
    uint8 constant BRANCH_MMRBLAKE_NODE = 2;      // CMerkleBranchBase::BRANCH_MMRBLAKE_NODE
    uint8 constant VERSION_TXHASH_CAP = 2;         // only proofs with version >= this are accepted
    uint8 constant TX_PREVOUTSEQ = 2;              // CTransactionHeader::TX_PREVOUTSEQ
    uint8 constant TX_SIGNATURE_TYPE = 3;          // CTransactionHeader::TX_SIGNATURE
    uint8 constant CCOPTPARAMS_VERSION = 3;
    uint8 constant TX_SHIELDEDSPEND = 5;           // CTransactionHeader::TX_SHIELDEDSPEND
    uint8 constant TX_SHIELDEDOUTPUT = 6;          // CTransactionHeader::TX_SHIELDEDOUTPUT
    uint32 constant CCE_HASH_TRANSFERS_DELTA = 32;
    uint32 constant CCE_DEST_SYSTEM_DELTA = 20;
    uint32 constant CCE_DEST_CURRENCY_DELTA = 20;
    uint32 constant CCE_SOURCE_SYSTEM_DELTA = 20;  // advance past flags(2) to sourceSystemID... no: flags read inline, then +20 for sourceID
    uint8 constant CCE_NVERSION_1 = 1;
    uint32 constant OUTPUT_SCRIPT_OFFSET = (8 + 1);                 // start of prevector serialization for output script
    uint32 constant SCRIPT_OP_CHECKCRYPTOCONDITION = 0xcc;
    uint32 constant SCRIPT_OP_PUSHDATA1 = 0x4c;
    uint32 constant SCRIPT_OP_PUSHDATA2 = 0x4d;
    uint32 constant TYPE_TX_OUTPUT = 4;
    uint32 constant SIZEOF_UINT64 = 8;
    uint8 constant FLAG_FRACTIONAL = 1;
    uint8 constant FLAG_REFUNDING = 4;
    uint8 constant FLAG_LAUNCHCONFIRMED = 0x10;
    uint8 constant FLAG_LAUNCHCOMPLETEMARKER = 0x20;
    uint8 constant AUX_DEST_ETH_VEC_LENGTH = 22;
    uint8 constant TX_HEADER = 1;
    uint8 constant NUM_TX_PROOFS = 3;
    uint32 constant MAX_SCRIPT_SIZE = 10000;
    // Minimum byte length of a CCE blob (from dOff) required by _readCCEFields:
    // nVersion(2)+flags(2)+sourceSystemID(20)+hashRT(32)+destSys(20)+destCur(20)
    // +exporterType(1)+exporterLen(1)+firstInput(4)+numInputs(4)+2×VARINT(2) = 108
    uint32 constant CCE_FIELDS_LENGTH = 108;

