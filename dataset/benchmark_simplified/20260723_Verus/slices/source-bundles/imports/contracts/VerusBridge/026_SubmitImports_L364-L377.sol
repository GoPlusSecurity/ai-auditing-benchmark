    function isLastCCEInOrder(uint32 height) private view {
      
        if ((lastImportInfo[VerusConstants.SUBMIT_IMPORTS_LAST_TXID].height + 1) == height)
        {
            return;
        } 
        else if (lastImportInfo[VerusConstants.SUBMIT_IMPORTS_LAST_TXID].hashOfTransfers == bytes32(0))
        {
            return;
        } 
        else{
            revert();
        }
    }
