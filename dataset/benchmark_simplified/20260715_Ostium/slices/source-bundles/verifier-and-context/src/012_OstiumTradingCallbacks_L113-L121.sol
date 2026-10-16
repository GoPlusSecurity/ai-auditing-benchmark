    function getContracts()
        private
        view
        returns (IOstiumTradingStorage storageT, IOstiumPairInfos pairInfos, IOstiumPairsStorage pairsStorage)
    {
        storageT = IOstiumTradingStorage(registry.getContractAddress('tradingStorage'));
        pairInfos = IOstiumPairInfos(registry.getContractAddress('pairInfos'));
        pairsStorage = IOstiumPairsStorage(registry.getContractAddress('pairsStorage'));
    }
