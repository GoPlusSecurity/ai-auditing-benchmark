    function validateParsedInput(V3Struct.ParsedV3QuoteStruct memory v3Quote)
        internal
        pure
        returns (
            bool success,
            V3Struct.Header memory header,
            V3Struct.EnclaveReport memory localEnclaveReport,
            bytes memory signedQuoteData, // concatenation of header and local enclave report bytes
            V3Struct.ECDSAQuoteV3AuthData memory authDataV3
        )
    {
        success = true;
        localEnclaveReport = v3Quote.localEnclaveReport;
        V3Struct.EnclaveReport memory pckSignedQeReport = v3Quote.v3AuthData.pckSignedQeReport;

        if (
            localEnclaveReport.reserved3.length != 96 || localEnclaveReport.reserved4.length != 60
                || localEnclaveReport.reportData.length != 64
        ) revert V3PARSER_INVALID_QUOTE_MEMBER_LENGTN();

        if (
            pckSignedQeReport.reserved3.length != 96 || pckSignedQeReport.reserved4.length != 60
                || pckSignedQeReport.reportData.length != 64
        ) {
            revert V3PARSER_INVALID_QEREPORT_LENGTN();
        }

        if (v3Quote.v3AuthData.certification.certType != 5) {
            revert V3PARSER_UNSUPPORT_CERTIFICATION_TYPE();
        }

        if (v3Quote.v3AuthData.certification.decodedCertDataArray.length != 3) {
            revert V3PARSER_INVALID_CERTIFICATION_CHAIN_SIZE();
        }

        if (
            v3Quote.v3AuthData.ecdsa256BitSignature.length != 64
                || v3Quote.v3AuthData.ecdsaAttestationKey.length != 64
                || v3Quote.v3AuthData.qeReportSignature.length != 64
        ) {
            revert V3PARSER_INVALID_ECDSA_SIGNATURE();
        }

        if (
            v3Quote.v3AuthData.qeAuthData.parsedDataSize
                != v3Quote.v3AuthData.qeAuthData.data.length
        ) {
            revert V3PARSER_INVALID_QEAUTHDATA_SIZE();
        }

        uint32 totalQuoteSize = 48 // header
            + 384 // local QE report
            + 64 // ecdsa256BitSignature
            + 64 // ecdsaAttestationKey
            + 384 // QE report
            + 64 // qeReportSignature
            + 2 // sizeof(v3Quote.v3AuthData.qeAuthData.parsedDataSize)
            + v3Quote.v3AuthData.qeAuthData.parsedDataSize + 2 // sizeof(v3Quote.v3AuthData.certification.certType)
            + 4 // sizeof(v3Quote.v3AuthData.certification.certDataSize)
            + v3Quote.v3AuthData.certification.certDataSize;
        if (totalQuoteSize <= MINIMUM_QUOTE_LENGTH) {
            revert V3PARSER_INVALID_QUOTE_LENGTN();
        }

        header = v3Quote.header;
        bytes memory headerBytes = abi.encodePacked(
            header.version,
            header.attestationKeyType,
            header.teeType,
            header.qeSvn,
            header.pceSvn,
            header.qeVendorId,
            header.userData
        );

        signedQuoteData = abi.encodePacked(headerBytes, V3Parser.packQEReport(localEnclaveReport));
        authDataV3 = v3Quote.v3AuthData;
    }
