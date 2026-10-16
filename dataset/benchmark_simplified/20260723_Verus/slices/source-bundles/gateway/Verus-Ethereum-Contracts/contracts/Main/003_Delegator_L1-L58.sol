// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;
pragma abicoder v2;

import "../Storage/StorageMaster.sol";
import "../VerusBridge/Token.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract Delegator is VerusStorage, ERC1155Holder, ERC721Holder {

    address startOwner;

    constructor(address[] memory _notaries, address[] memory _notariesEthAddress, address[] memory _notariesColdStoreEthAddress, address[] memory _newContractAddress) {
        remainingLaunchFeeReserves = VerusConstants.verusBridgeLaunchFeeShare;

        for(uint i =0; i < _notaries.length; i++) {
            notaryAddressMapping[_notaries[i]] = VerusObjects.notarizer(_notariesEthAddress[i], _notariesColdStoreEthAddress[i], VerusConstants.NOTARY_VALID);
            notaries.push(_notaries[i]);
        }
        VerusNft t = new VerusNft(); 

        //NOTE: VerusNFT contract is mapped by its unique contract address, as there is no i-address for it.
        verusToERC20mapping[address(t)] = 
            VerusObjects.mappedToken(address(t), uint8(VerusConstants.MAPPING_VERUS_OWNED + VerusConstants.MAPPING_ERC721_NFT_DEFINITION),
                0, "VerusNFT", uint256(0));  

        tokenList.push(address(t));

        startOwner = msg.sender;
        for (uint i = 0; i < uint(VerusConstants.NUMBER_OF_CONTRACTS); i++) {
            contracts.push(_newContractAddress[i]);
        }
    }
    
    receive() external payable {
        
    }

    function sendTransfer(VerusObjects.CReserveTransfer calldata _transfer) external payable { 

        bool success;
        bytes memory data = abi.encode(_transfer); 

        address verusBridgeAddress = contracts[uint(VerusConstants.ContractType.CreateExport)];
        (success, ) = verusBridgeAddress.delegatecall(abi.encodeWithSignature("sendTransfer(bytes)", data));
        require(success);
    }
    
    function sendTransferDirect(bytes calldata data) external payable { 

        bool success;

        address verusBridgeAddress = contracts[uint(VerusConstants.ContractType.CreateExport)];
        (success, ) = verusBridgeAddress.delegatecall(abi.encodeWithSignature("sendTransferDirect(bytes)", data));
        require(success);
    }

