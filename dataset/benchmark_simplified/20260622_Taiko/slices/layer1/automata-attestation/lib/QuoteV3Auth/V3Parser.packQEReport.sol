    function packQEReport(V3Struct.EnclaveReport memory enclaveReport)
        internal
        pure
        returns (bytes memory packedQEReport)
    {
        uint16 isvProdIdPackBE = (enclaveReport.isvProdId >> 8) | (enclaveReport.isvProdId << 8);
        uint16 isvSvnPackBE = (enclaveReport.isvSvn >> 8) | (enclaveReport.isvSvn << 8);
        packedQEReport = abi.encodePacked(
            enclaveReport.cpuSvn,
            enclaveReport.miscSelect,
            enclaveReport.reserved1,
            enclaveReport.attributes,
            enclaveReport.mrEnclave,
            enclaveReport.reserved2,
            enclaveReport.mrSigner,
            enclaveReport.reserved3,
            isvProdIdPackBE,
            isvSvnPackBE,
            enclaveReport.reserved4,
            enclaveReport.reportData
        );
    }
