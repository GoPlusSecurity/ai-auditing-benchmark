// SPDX-License-Identifier: MIT
// Bridge between ethereum and verus

pragma solidity >=0.8.9;
pragma abicoder v2;

import "../Libraries/VerusConstants.sol";
import "../Libraries/VerusObjectsNotarization.sol";
import "./NotarizationSerializer.sol";
import "../MMR/VerusBlake2b.sol";
import "../VerusBridge/CreateExports.sol";
import "../VerusBridge/UpgradeManager.sol";
import "../Storage/StorageMaster.sol";
import "../VerusBridge/SubmitImports.sol";

contract VerusNotarizer is VerusStorage {

    address immutable VETH;
    address immutable BRIDGE;
    address immutable VERUS;

    constructor(address vETH, address Bridge, address Verus){

        VETH = vETH;
        BRIDGE = Bridge;
        VERUS = Verus;
    }

    //reset to empty 9-July-26
    function initialize() external {}

    uint8 constant FORKS_DATA_OFFSET_FOR_HEIGHT = 224;

    uint32 constant FORKS_DATA_CONFIRMED_PROPOSER = 96;
    uint32 constant PROOF_HEIGHT_LOCATION = 68 - 32;  //NOTE: removed blockhash from proofroot, so this is now 68 bytes minus 32 bytes for the blockhash
    uint32 constant LENGTH_OF_FORK_DATA = 96;

    // notarization vdxf key
    bytes22 constant vdxfcodePlusVersion = bytes22(0x01367Eaadd291E1976ABc446A143f83c2D4D2C5a8401);
    event NewNotarization (bytes32);
    using VerusBlake2b for bytes;
    
    function currentNotariesLength() public view returns(uint8){

        return uint8(notaries.length);

    }
 
