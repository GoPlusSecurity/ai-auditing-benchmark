    function processTransactions(bytes calldata serializedTransfers, uint256 numberOfTransfers) 
                external returns (bytes memory refundsData, uint256 fees, uint176[] memory refundAddresses)
    {

        VerusObjects.PackedSend[] memory transfers;
        VerusObjects.PackedCurrencyLaunch[] memory launchTxs;

        uint32 counter;
        (transfers, launchTxs, counter, refundAddresses) = VerusSerializer(contracts[uint(VerusConstants.ContractType.VerusSerializer)])
            .deserializeTransfers(serializedTransfers, uint8(numberOfTransfers));
        
        // Only two currency launches are allowed per CCE, so use a third one to store fees, as function is to large.
        fees = uint64(launchTxs[2].tokenID);
        refundsData = importTransactions(transfers, refundAddresses);
        // 32-bit packed counter: low byte tracks transfer count (counter++), high byte tracks currency launches (counter += 0x1000000).
        if (uint8(counter >> 24) > 0) {
            launchToken(launchTxs);
        }

        //return and refund any failed transactions
        return (refundsData, fees, refundAddresses);
    }
