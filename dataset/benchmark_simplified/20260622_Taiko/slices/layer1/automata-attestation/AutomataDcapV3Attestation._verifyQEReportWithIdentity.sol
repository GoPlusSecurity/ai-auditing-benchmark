    function _verifyQEReportWithIdentity(V3Struct.EnclaveReport memory quoteEnclaveReport)
        private
        view
        returns (bool, EnclaveIdStruct.EnclaveIdStatus status)
    {
        EnclaveIdStruct.EnclaveId memory enclaveId = qeIdentity;
        bool miscselectMatched =
            quoteEnclaveReport.miscSelect & enclaveId.miscselectMask == enclaveId.miscselect;

        bool attributesMatched =
            quoteEnclaveReport.attributes & enclaveId.attributesMask == enclaveId.attributes;
        bool mrsignerMatched = quoteEnclaveReport.mrSigner == enclaveId.mrsigner;

        bool isvprodidMatched = quoteEnclaveReport.isvProdId == enclaveId.isvprodid;

        bool tcbFound;
        uint256 size = enclaveId.tcbLevels.length;
        for (uint256 i; i < size; ++i) {
            EnclaveIdStruct.TcbLevel memory tcb = enclaveId.tcbLevels[i];
            if (tcb.tcb.isvsvn <= quoteEnclaveReport.isvSvn) {
                tcbFound = true;
                status = tcb.tcbStatus;
                break;
            }
        }
        return (
            miscselectMatched && attributesMatched && mrsignerMatched && isvprodidMatched
                && tcbFound,
            status
        );
    }
