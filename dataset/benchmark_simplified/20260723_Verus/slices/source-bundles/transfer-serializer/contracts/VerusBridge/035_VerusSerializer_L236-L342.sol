    function currencyParser(bytes memory input, uint256 offset) public pure
                    returns (VerusObjects.PackedCurrencyLaunch memory returnCurrency)
    {
        uint32 nextOffset;
        uint32 tempUint32;
        address parent;
        address nativeCurrencyID;
        uint256 nftID;
        uint8 NativeCurrencyType;
        uint8 NativeCurrencyTypeNoFlags;
        uint32 options;

        nextOffset = CCC_PREFIX_TO_OPTIONS + uint32(offset);

        assembly {
            options := mload(add(input, nextOffset))
            nextOffset := add(nextOffset, VERUS_ID_LENGTH)
            parent := mload(add(input, nextOffset))
            nextOffset := add(nextOffset, 1)  // one byte move forwards to read string length
            tempUint32 := and(mload(add(input, nextOffset)), 0x000000ff) // string length MAX 64 so will always be a byte
        }

        options = serializeUint32(options);  //reverse endian
        returnCurrency.parent = parent;
        bytes memory tempname = new bytes(tempUint32);

        for (uint32 i = 0; i < tempUint32; i++) { 
            tempname[i] = input[i + nextOffset];
        }
        
        returnCurrency.name = string(tempname);
        nextOffset += tempUint32;
        assembly {
            nextOffset := add(nextOffset, VERUS_ID_LENGTH) // move to read launchsystemID
            nextOffset := add(nextOffset, VERUS_ID_LENGTH) // move to read systemID
            nextOffset := add(nextOffset, CCC_NATIVE_OFFSET) // move to read the native currency type
            NativeCurrencyType := mload(add(input, nextOffset)) 
        }

        NativeCurrencyTypeNoFlags = NativeCurrencyType & ~FLAG_MASK; //remove flags
       
        if (NativeCurrencyTypeNoFlags == VerusConstants.DEST_ETHNFT) {
            assembly {
                nextOffset := add(add(nextOffset, VERUS_ID_LENGTH), 1) //skip vector length 
                nativeCurrencyID := mload(add(input, nextOffset))
                nextOffset := add(nextOffset, CCC_TOKENID_OFFSET)
                nftID := mload(add(input, nextOffset))
            }   

            if (NativeCurrencyType == VerusConstants.DEST_ETHNFT) { //if there is no auxdest then it is an ERC721
                returnCurrency.flags |= uint8(VerusConstants.MAPPING_ERC721_NFT_DEFINITION); 
            } else {
                returnCurrency.flags |= uint8(VerusConstants.MAPPING_ERC1155_NFT_DEFINITION);
            }
            returnCurrency.flags |= uint8(VerusConstants.MAPPING_ETHEREUM_OWNED);
            returnCurrency.tokenID = nftID;
        }
        else if (NativeCurrencyTypeNoFlags == VerusConstants.DEST_ETH) {
            
            assembly {
                nextOffset := add(add(nextOffset, VERUS_ID_LENGTH), 1) //skip vector length 
                nativeCurrencyID := mload(add(input, nextOffset))
            }

            if (NativeCurrencyType == VerusConstants.DEST_ETH) {  //if there is no auxdest then it is an ERC20
                returnCurrency.flags |= uint8(VerusConstants.MAPPING_ERC20_DEFINITION);
            } else {
                returnCurrency.flags |= uint8(VerusConstants.MAPPING_ERC1155_ERC_DEFINITION);
            }
            returnCurrency.flags |= uint8(VerusConstants.MAPPING_ETHEREUM_OWNED);
        }
        else if (options & VerusConstants.OPTION_NFT_TOKEN == VerusConstants.OPTION_NFT_TOKEN) { //minted NFT from verus
        
            returnCurrency.flags |= uint8(VerusConstants.MAPPING_ERC721_NFT_DEFINITION);
            returnCurrency.flags |= uint8(VerusConstants.MAPPING_VERUS_OWNED);
            nativeCurrencyID = address(0); //The Verus NFT contract is not known by this contract so it will be set when the NFT is minted.
        }
        else { // Verus owned ERC20, ERC20 contract not known yet.
        
            returnCurrency.flags |= uint8(VerusConstants.MAPPING_ERC20_DEFINITION);
            returnCurrency.flags |= uint8(VerusConstants.MAPPING_VERUS_OWNED);
        }

        returnCurrency.ERCContract = nativeCurrencyID;
        
        if (NativeCurrencyType & VerusConstants.FLAG_DEST_AUX == VerusConstants.FLAG_DEST_AUX) {

            assembly {
                nextOffset := add(nextOffset, 1) //move to vector length 
            }

            uint256 TokenId;

            TokenId = readAuxDestPK(input, nextOffset);

            if (NativeCurrencyTypeNoFlags == VerusConstants.DEST_ETH) {
                returnCurrency.tokenID = TokenId;
            }
            else if (NativeCurrencyTypeNoFlags == VerusConstants.DEST_ETHNFT &&
                TokenId != nftID) {
                // if the NFT ID does not match the auxdest NFT ID then the currency is invalid
                returnCurrency.flags = uint8(VerusConstants.MAPPING_INVALID);
                return returnCurrency;
            }
        } 
        return returnCurrency;
    }
