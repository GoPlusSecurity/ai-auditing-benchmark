// SPDX-License-Identifier: MIT
// Bridge between ethereum and verus

pragma solidity >=0.8.9;
pragma abicoder v2;   
import "../Libraries/VerusObjects.sol";
import "../Libraries/VerusObjectsNotarization.sol";
import "../Libraries/VerusConstants.sol";

contract VerusSerializer {

    uint constant ETH_ADDRESS_SIZE_BYTES = 20;
    uint32 constant CCC_PREFIX_TO_OPTIONS = 3 + 4; // already starts on the byte so 3 first
    uint32 constant VERUS_ID_LENGTH = 20;
    uint32 constant CCC_NATIVE_OFFSET = 4 + 4 + 1;
    uint32 constant CCC_TOKENID_OFFSET = 32;
    uint32 constant ETH_SEND_GATEWAY_AND_AUX_DEST = 20 + 20 + 8 + 4 + 20;
    uint32 constant TRANSFER_GATEWAYSKIP = 48; // skip gatewayID (20), gatewayCode (20), fees (8)
    uint8 constant FLAG_MASK = 192; // 11000000

    //reset to empty 9-July-26
    function initialize() external {}

