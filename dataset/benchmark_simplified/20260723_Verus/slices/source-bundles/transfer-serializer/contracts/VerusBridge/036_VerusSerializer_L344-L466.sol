    function deserializeTransfers(bytes memory tempSerialized, uint8 numberOfTransfers) public pure
        returns (VerusObjects.PackedSend[] memory tempTransfers, VerusObjects.PackedCurrencyLaunch[] memory launchTxs, uint32 counter, uint176[] memory refundAddresses)
    { 
        // return value counter is a packed 32bit number first bytes is number of transfers, 3rd byte number of ETH sends 4th byte number of currencey launches
              
        tempTransfers = new VerusObjects.PackedSend[](numberOfTransfers); 
        refundAddresses = new uint176[](numberOfTransfers);
        launchTxs = new VerusObjects.PackedCurrencyLaunch[](3); //max to Currency launches
        address tempaddress;
        uint64 temporaryRegister1;
        uint8 destinationType;
        uint256 nextOffset = 1;
        uint176 refundAddress;
        uint64 flags;

        while (nextOffset <= tempSerialized.length) {
            
            assembly {
                destinationType := mload(add(tempSerialized, nextOffset)) // Read one byte at the given offset
                if iszero(eq(and(destinationType,0xff), 1)) {
                    revert(0, 0) // Revert the transaction if version is not equal to 1
                }
                nextOffset := add(nextOffset, VERUS_ID_LENGTH)
                tempaddress := mload(add(tempSerialized, nextOffset)) // skip version 0x01 (1 byte) and read currency being sent
            }

            (temporaryRegister1, nextOffset)  = readVarint(tempSerialized, nextOffset);  // read varint (amount) returns next idx position
            (flags, nextOffset) = readVarint(tempSerialized, nextOffset);

            tempTransfers[uint8(counter)].currencyAndAmount = uint256(temporaryRegister1) << VerusConstants.UINT160_BITS_SIZE; //shift amount and pack
            tempTransfers[uint8(counter)].currencyAndAmount |= uint256(uint160(tempaddress));

            nextOffset += VERUS_ID_LENGTH; //skip feecurrency id always vETH, variint already 1 byte in so 19

            (temporaryRegister1, nextOffset) = readVarint(tempSerialized, nextOffset); //fees read into 'temporaryRegister1' but not used
            
            // Store Fees temporarily in the tokenID field
            launchTxs[2].tokenID += temporaryRegister1;
            assembly {
                nextOffset := add(nextOffset, 1) //move to read the destination type
                destinationType := mload(add(tempSerialized, nextOffset))
                nextOffset := add(nextOffset, 1) //move to read destination vector length compactint
            }

            // get the length of the destination and move the offset to the start of the destination address

            (temporaryRegister1, nextOffset) = readCompactSizeLE(tempSerialized, nextOffset);    

            // if destination an ERC Send (ETH, ERC20, ERC721, ERC1155)
            if (destinationType & VerusConstants.DEST_ETH == VerusConstants.DEST_ETH) {

                assembly {
                    tempaddress := mload(sub(add(add(tempSerialized, nextOffset), VERUS_ID_LENGTH), 1)) //skip back one byte to read address
                }
                tempTransfers[uint8(counter)].destinationAndFlags = uint256(uint160(tempaddress));
            }
            else if (destinationType & VerusConstants.DEST_REGISTERCURRENCY == VerusConstants.DEST_REGISTERCURRENCY || 
                     destinationType & VerusConstants.DEST_ETHNFT == VerusConstants.DEST_ETHNFT) { 
                
                launchTxs[(counter >> 24 & 0xff)] = currencyParser(tempSerialized, nextOffset);

                if (launchTxs[(counter >> 24 & 0xff)].flags != 0) {
                    // if the currency is valid then set the iaddress to the currencyID and increment the counter.
                    launchTxs[(counter >> 24 & 0xff)].iaddress = address(uint160(tempTransfers[uint8(counter)].currencyAndAmount));
                    counter += 0x1000000; //This is the Launch currency counter packed into the 4th byte
                }
            }

            assembly {
                nextOffset := add(nextOffset, temporaryRegister1) //move to end of destination address + one byte ahead.
            }

            // If FLAG_DEST_GATEWAY is set then skip the gateway fields as well.
            if (destinationType & VerusConstants.FLAG_DEST_GATEWAY == VerusConstants.FLAG_DEST_GATEWAY)
            {
                assembly {
                    nextOffset := add(nextOffset, TRANSFER_GATEWAYSKIP) //move to vector length 
                }
            }

            if (destinationType & VerusConstants.FLAG_DEST_AUX == VerusConstants.FLAG_DEST_AUX) {

                (temporaryRegister1, nextOffset) = readCompactSizeLE(tempSerialized, nextOffset);    // get the length of the auxDest

                // NOTE: This uses the last aux address as the refund address. Check with Verus this is intended.

                for (uint i = temporaryRegister1; i > 0; i--) {
                    (temporaryRegister1, nextOffset) = readCompactSizeLE(tempSerialized, nextOffset);    // get the length of the auxDest sub array
                    assembly {
                        refundAddress := mload(sub(add(add(tempSerialized, nextOffset), temporaryRegister1), 1)) //skip type +1 byte to read address
                    }
                    refundAddresses[uint8(counter)] = refundAddress;

                    // Note: this moves to one byte past the data ready to read the next byte. 
                    nextOffset += temporaryRegister1;
                }
            }

            counter++;

            assembly {
                nextOffset := add(nextOffset, VERUS_ID_LENGTH) //move to read destCurrencyID
            }

            if (flags & VerusConstants.RESERVE_TO_RESERVE == VerusConstants.RESERVE_TO_RESERVE)
            {
                assembly {
                    nextOffset := add(nextOffset, VERUS_ID_LENGTH) //move to read secondReserveID
                }
            }

            if (flags & VerusConstants.CROSS_SYSTEM == VerusConstants.CROSS_SYSTEM )
            {
                assembly {
                    nextOffset := add(nextOffset, VERUS_ID_LENGTH) //move to read destSystemID
                }
            }

        }

        return (tempTransfers, launchTxs, counter, refundAddresses);

    }
