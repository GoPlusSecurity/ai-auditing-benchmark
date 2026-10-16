// SPDX-License-Identifier: MIT
// Bridge between ethereum and verus

pragma solidity >=0.8.9;
pragma abicoder v2;
import "../Libraries/VerusObjects.sol";

import "../Libraries/VerusObjectsCommon.sol";
import "../VerusBridge/UpgradeManager.sol";
import "../Storage/StorageMaster.sol";

contract NotarizationSerializer is VerusStorage {

    address immutable VETH;
    address immutable BRIDGE;
    address immutable VERUS;
    address immutable DAI;
    address immutable MKR;
    address immutable tBTC = 0xf87F6d4412dAd7c4452e8293850Df5327f02C308; // tBTC iaddress iS8TfRPfVpKo5FVfSUzfHBQxo9KuzpnqLU as hex
    address immutable vUSDC = 0x1Bd15cDbf0B5B8c9CC361FFBaf6D76cc2CdfD667; // vUSDC iaddress i61cV2uicKSi1rSMQCBNQeSYC3UAi9GVzd as hex

    constructor(address vETH, address Bridge, address Verus, address Dai, address Mkr){

        VETH = vETH;
        BRIDGE = Bridge;
        VERUS = Verus;
        DAI = Dai;
        MKR = Mkr;
    }

    uint8 constant CURRENCY_LENGTH = 20;
    uint8 constant BYTES32_LENGTH = 32;
    uint8 constant TWO2BYTES32_LENGTH = 64;
    uint8 constant FLAG_FRACTIONAL = 1;
    uint8 constant FLAG_REFUNDING = 4;
    uint8 constant FLAG_LAUNCHCONFIRMED = 0x10;
    uint8 constant FLAG_LAUNCHCOMPLETEMARKER = 0x20;
    uint8 constant AUX_DEST_ETH_VEC_LENGTH = 22;
    uint8 constant AUX_DEST_VOTE_HASH = 21;
    uint8 constant VOTE_BYTE_POSITION = 22;
    uint8 constant UINT64_BYTES_SIZE = 8;
    uint8 constant PROOF_TYPE_ETH = 2;
    uint32 constant FLAG_START_NOTARIZATION = 4;
    uint32 constant FLAG_LAUNCH_CONFIRMED = 8;
    uint32 constant FLAG_LAUNCH_COMPLETE = 0x100;
    uint32 constant FLAG_CONTRACT_UPGRADE = 0x200;
    uint32 constant REQUIRED_NOTARIZATION_FLAGS = FLAG_START_NOTARIZATION + FLAG_LAUNCH_CONFIRMED + FLAG_LAUNCH_COMPLETE;
    uint32 constant ALLOWED_OPTIONAL_NOTARIZATION_FLAGS = FLAG_CONTRACT_UPGRADE;
    uint32 constant ALLOWED_NOTARIZATION_FLAGS = REQUIRED_NOTARIZATION_FLAGS + ALLOWED_OPTIONAL_NOTARIZATION_FLAGS;
    enum Currency {VETH, DAI, VERUS, MKR}

    //reset to empty 9-July-26
    function initialize() external {}
    
    function readVarint(bytes memory buf, uint32 idx) public pure returns (uint32 v, uint32 retidx) {

        uint8 b; // store current byte content

        for (uint32 i=0; i<10; i++) {
            b = uint8(buf[i+idx]);
            v = (v << 7) | b & 0x7F;
            if (b & 0x80 == 0x80)
                v++;
            else
            return (v, idx + i + 1);
        }
        revert(); // i=10, invalid varint stream
    }

