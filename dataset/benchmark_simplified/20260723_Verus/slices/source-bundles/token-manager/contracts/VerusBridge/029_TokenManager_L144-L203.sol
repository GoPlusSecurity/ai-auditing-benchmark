    function importTransactions(VerusObjects.PackedSend[] memory trans, uint176[] memory refundAddresses) private returns (bytes memory refundsData){
      
        VerusObjects.mappedToken memory tempToken;
        
        for(uint256 i = 0; i < trans.length; i++)
        {
            uint64 sendAmount;
            address destinationAddress;
            address currencyiAddress;
            uint32 result;

            sendAmount = uint64(trans[i].currencyAndAmount >> VerusConstants.UINT160_BITS_SIZE);
            destinationAddress  = address(uint160(trans[i].destinationAndFlags));
            tempToken = verusToERC20mapping[address(uint160(trans[i].currencyAndAmount))];
            currencyiAddress = address(uint160(trans[i].currencyAndAmount));
            
            if (currencyiAddress == VETH) 
            {
                // NOTE: Send limits gas so cannot pay to contract addresses with fallback functions.
                (bool success, ) = destinationAddress.call{value: (sendAmount * VerusConstants.SATS_TO_WEI_STD), gas: 100000}("");
                result = success ? SEND_SUCCESS_ETH : SEND_FAILED;            
            }   
            else if (tempToken.flags & VerusConstants.MAPPING_ERC721_NFT_DEFINITION == VerusConstants.MAPPING_ERC721_NFT_DEFINITION &&
                     tempToken.flags & VerusConstants.MAPPING_VERUS_OWNED == VerusConstants.MAPPING_VERUS_OWNED)
            {
                VerusNft t = VerusNft(tempToken.erc20ContractAddress);
                t.mint(currencyiAddress, tempToken.name, destinationAddress);
                // Do nothing after minted.
                result = 0;
            }
            else if (tempToken.flags & VerusConstants.MAPPING_ERC20_DEFINITION == VerusConstants.MAPPING_ERC20_DEFINITION)
            {
                // if the ERC20 type is verus owned then mint the currency to the destination address, else transfer the currency to the destination address.
                result = uint32((tempToken.flags & VerusConstants.MAPPING_VERUS_OWNED == VerusConstants.MAPPING_VERUS_OWNED) 
                                                   ? uint32(ERC20_MINT_SELECTOR) : uint32(ERC20_SEND_SELECTOR));
            } 
            else if (tempToken.flags & VerusConstants.MAPPING_ERC721_NFT_DEFINITION == VerusConstants.MAPPING_ERC721_NFT_DEFINITION) 
            {             
                result = uint32(ERC721_SEND_SELECTOR);

            } else if (tempToken.flags & VerusConstants.MAPPING_ERC1155_NFT_DEFINITION == VerusConstants.MAPPING_ERC1155_NFT_DEFINITION ||
                        tempToken.flags & VerusConstants.MAPPING_ERC1155_ERC_DEFINITION == VerusConstants.MAPPING_ERC1155_ERC_DEFINITION) 
            {
                result = uint32(ERC1155_SEND_SELECTOR);
            }            

            // if result is a sector then use it to make the call in the sendCurrencyToETHAddress function, else call is already made.
            if(result > SEND_SUCCESS_ETH) {
                result = sendCurrencyToETHAddress(tempToken.erc20ContractAddress, destinationAddress, sendAmount, result, tempToken.tokenID); 
            }

            if (result == SEND_FAILED && sendAmount > 0) {
                refundsData = abi.encodePacked(refundsData, refundAddresses[i], sendAmount, currencyiAddress);
            } 
            else if (result == SEND_SUCCESS || result == SEND_SUCCESS_ETH) {
                // TokenIndex used for ERC20, ERC721, ERC1155 & ETH accounting so decrement holdings if successful
                verusToERC20mapping[currencyiAddress].tokenIndex -= sendAmount;
            }
        } 
    }
