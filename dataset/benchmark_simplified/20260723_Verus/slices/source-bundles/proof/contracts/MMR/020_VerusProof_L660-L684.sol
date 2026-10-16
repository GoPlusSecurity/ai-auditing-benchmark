    function proveComponents(VerusObjects.CReserveTransferImport memory _import) public view returns(bytes32 txRoot){
     
        bytes32 hashInProgress;
        bytes32 testHash;
  
        hashInProgress = _import.partialtransactionproof.components[0].elVchObj.createHash();
        if (_import.partialtransactionproof.components[0].elType == TX_HEADER )
        {
            txRoot = checkProof(hashInProgress, _import.partialtransactionproof.components[0].elProof);           
        }
        
        for (uint i = 1; i < _import.partialtransactionproof.components.length; i++) {

            hashInProgress = _import.partialtransactionproof.components[i].elVchObj.createHash();
            testHash = checkProof(hashInProgress, _import.partialtransactionproof.components[i].elProof);
        
            if (txRoot != testHash) 
            {
                txRoot = bytes32(0);
                break;
            }
        }

        return txRoot;
    }
