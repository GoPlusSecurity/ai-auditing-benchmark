// SPDX-License-Identifier: MIT
// Bridge between ethereum and verus

pragma solidity >=0.8.9;
pragma abicoder v2;

import "./Token.sol";
import "../Libraries/VerusConstants.sol";
import "../Libraries/VerusObjects.sol";
import {VerusSerializer} from "../VerusBridge/VerusSerializer.sol";
import "../VerusBridge/CreateExports.sol";
import "../VerusBridge/UpgradeManager.sol";
import "../VerusBridge/SubmitImports.sol";
import "../Libraries/VerusObjectsCommon.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "../Storage/StorageMaster.sol";
import "./VerusCrossChainExport.sol";


contract TokenManager is VerusStorage {

    address immutable VETH;
    address immutable VERUS;
    address immutable DAIERC20ADDRESS;

    uint8 constant SEND_FAILED = 1;
    uint8 constant SEND_SUCCESS = 2;
    uint8 constant SEND_SUCCESS_ERC1155 = 3;
    uint8 constant SEND_SUCCESS_ERC721 = 4;
    uint8 constant SEND_SUCCESS_ERC20_MINTED = 5;
    uint8 constant SEND_SUCCESS_ETH = 6;

    bytes4 constant ERC20_SEND_SELECTOR = ERC20.transfer.selector ;
    bytes4 constant ERC20_MINT_SELECTOR = Token.mint.selector ;
    bytes4 constant ERC721_SEND_SELECTOR = IERC721.transferFrom.selector;
    bytes4 constant ERC1155_SEND_SELECTOR = IERC1155.safeTransferFrom.selector;

    constructor(address vETH, address, address Verus, address DaiERC20Address){

        VETH = vETH;
        VERUS = Verus;
        DAIERC20ADDRESS = DaiERC20Address;
    }

    //reset to empty 9-July-26
    function initialize() external {} 

    function launchToken(VerusObjects.PackedCurrencyLaunch[] memory _tx) private {
        
        for (uint j = 0; j < _tx.length; j++)
        {
            // If the iaddress is already mapped or the iaddress is null skip token register
            if (verusToERC20mapping[_tx[j].iaddress].flags > 0 || _tx[j].iaddress == address(0))
                continue;

            VerusSerializer(contracts[uint(VerusConstants.ContractType.VerusSerializer)]).checkIAddress(_tx[j]); 

            string memory outputName;

            // Only adjust the name of the token if it is a Ethereum owned token and it not a ERC1155 NFT
            if (_tx[j].flags & 
                (VerusConstants.MAPPING_ETHEREUM_OWNED | VerusConstants.MAPPING_ERC1155_ERC_DEFINITION | VerusConstants.MAPPING_ERC1155_NFT_DEFINITION) 
                    == VerusConstants.MAPPING_ETHEREUM_OWNED)
            {
               (bool success, bytes memory result) = _tx[j].ERCContract.call{gas:30000}(abi.encodeWithSignature("name()"));
                if (success) {
                    outputName = abi.decode(result, (string));
                } else {
                    outputName = "...";
                }

                outputName = string(abi.encodePacked("[", outputName, "] as "));
            }

            outputName = string(abi.encodePacked(outputName, _tx[j].name));

            if (_tx[j].parent != VERUS)
            {
                outputName = string(abi.encodePacked(outputName, ".", verusToERC20mapping[_tx[j].parent].name));
            }
            recordToken(_tx[j].iaddress, _tx[j].ERCContract, outputName, _tx[j].name, uint8(_tx[j].flags), _tx[j].tokenID);
        }
    }

    function recordToken(
        address _iaddress,
        address ethContractAddress,
        string memory name,
        string memory ticker,
        uint8 flags,
        uint256 tokenID
    ) public { 

        address ERCContract;

        if (flags & VerusConstants.MAPPING_VERUS_OWNED == VerusConstants.MAPPING_VERUS_OWNED) 
        {
            if (flags & VerusConstants.MAPPING_ERC20_DEFINITION == VerusConstants.MAPPING_ERC20_DEFINITION) 
            {
                Token t = new Token(name, ticker); 
                ERCContract = address(t); 
            }
            else if (flags & VerusConstants.MAPPING_ERC721_NFT_DEFINITION == VerusConstants.MAPPING_ERC721_NFT_DEFINITION)
            {
                ERCContract = verusToERC20mapping[tokenList[VerusConstants.NFT_POSITION]].erc20ContractAddress;
                tokenID = uint256(uint160(_iaddress)); //tokenID is the i address
            }
        }
        else 
        {
            ERCContract = ethContractAddress;
        }

        tokenList.push(_iaddress);
        // TokenIndex is used for accounting of ERC20, ERC721, ERC1155 so allways start at 0.
        verusToERC20mapping[_iaddress] = VerusObjects.mappedToken(ERCContract, flags, 0, name, tokenID);
 
    }

