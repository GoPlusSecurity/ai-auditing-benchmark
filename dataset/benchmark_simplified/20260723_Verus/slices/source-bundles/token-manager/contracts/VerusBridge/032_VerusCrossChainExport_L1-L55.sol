// SPDX-License-Identifier: MIT
// Bridge between ethereum and verus

pragma solidity >=0.8.9;
pragma abicoder v2;

import "../Libraries/VerusObjects.sol";
import "../Libraries/VerusConstants.sol";
import "../VerusBridge/VerusSerializer.sol";
import "../Storage/StorageMaster.sol";
import "./dsrinterface.sol";

contract VerusCrossChainExport is VerusStorage {
    
    VerusObjects.CCurrencyValueMap[] currencies;
    VerusObjects.CCurrencyValueMap[] fees;

    address immutable VETH;
    address immutable BRIDGE;
    address immutable VERUS;
    address immutable DAIERC20;

    address immutable pot;
    address immutable daiJoin;

    constructor(address vETH, address Bridge, address Verus, address daiERC20, address potAddress, address daiJoinAddress) {

        VETH = vETH;
        BRIDGE = Bridge;
        VERUS = Verus;
        DAIERC20 = daiERC20;
        pot = potAddress;
        daiJoin = daiJoinAddress;
    }

    //reset to empty 9-July-26
    function initialize() external {}

    // Called by Delegator.setVerusData() to resolve a function name to its implementation contract index.
    function checkVDFXId(string calldata vdxfid) external view returns (uint) {
        bytes memory stored = storageGlobal[keccak256(abi.encodePacked(vdxfid))];
        require(stored.length > 0, "VDXF not registered");
        return abi.decode(stored, (uint));
    }

    uint256 constant RAY = 10 ** 27;
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x);
    }
    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }
    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x);
    }
