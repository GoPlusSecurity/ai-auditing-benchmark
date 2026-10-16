    function setLatestData(bytes calldata serializedNotarization, bytes32 txid, uint32 n, bytes calldata data) external {

        address logic = contracts[uint(VerusConstants.ContractType.VerusNotarizer)];

        (bool success, ) = logic.delegatecall(abi.encodeWithSignature("setLatestData(bytes,bytes32,uint32,bytes)", serializedNotarization, txid, n, data));
        require(success);

    }
