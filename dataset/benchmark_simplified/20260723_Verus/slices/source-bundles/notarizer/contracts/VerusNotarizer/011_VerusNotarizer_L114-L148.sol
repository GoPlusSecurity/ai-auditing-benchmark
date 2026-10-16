    function checkNotarization(bytes calldata serializedNotarization, bytes32 txid, uint64 voutAndHeight ) private {
    
        bytes32 blakeNotarizationHash;

        blakeNotarizationHash = serializedNotarization.createHash();

        address notarizationSerializerAddress = contracts[uint(VerusConstants.ContractType.NotarizationSerializer)];

        (bool success, bytes memory returnBytes) = notarizationSerializerAddress.delegatecall(abi.encodeWithSignature("deserializeNotarization(bytes)", serializedNotarization));
        require(success);

        (bytes32 launchedAndProposer, bytes32 prevnotarizationtxid, bytes32 hashprevnotarization, bytes32 stateRoot, 
                uint32 verusProofheight) = abi.decode(returnBytes, (bytes32, bytes32, bytes32, bytes32, uint32));

        voutAndHeight |= uint64(verusProofheight) << 32; // pack two 32bit numbers into one uint64
        launchedAndProposer |= bytes32(uint256(voutAndHeight) << VerusConstants.NOTARIZATION_VOUT_NUM_INDEX); // Also pack in the voutnum at the end of the uint256

        setNotarizationProofRoot(blakeNotarizationHash, hashprevnotarization, txid, prevnotarizationtxid, launchedAndProposer, stateRoot);

        // If the bridge is active and VRSC remaining has not been sent
        if (remainingLaunchFeeReserves != 0 && bridgeConverterActive) { 

            if (remainingLaunchFeeReserves > (VerusConstants.verusTransactionFee * 2)) {
                bool success2; bytes memory retData;
                (success2, retData) = contracts[uint(VerusConstants.ContractType.SubmitImports)].delegatecall(abi.encodeWithSelector(SubmitImports.sendBurnBackToVerus.selector, 0, VERUS, 0));
                require(success2);
                (VerusObjects.CReserveTransfer memory LPtransfer,) = abi.decode(retData, (VerusObjects.CReserveTransfer, bool)); 

                (success2, retData) = contracts[uint(VerusConstants.ContractType.CreateExport)].delegatecall(abi.encodeWithSelector(CreateExports.externalCreateExportCall.selector, abi.encode(LPtransfer, true)));
                require(success2);
                remainingLaunchFeeReserves = 0;
            }
        }
        emit NewNotarization(blakeNotarizationHash);
    }
