    function _verifyParsedQuote(V3Struct.ParsedV3QuoteStruct memory v3quote)
        internal
        view
        returns (bool, bytes memory)
    {
        bytes memory retData = abi.encodePacked(INVALID_EXIT_CODE);

        // // Step 1: Parse the quote input = 152k gas
        (
            bool successful,,,
            bytes memory signedQuoteData,
            V3Struct.ECDSAQuoteV3AuthData memory authDataV3
        ) = V3Parser.validateParsedInput(v3quote);
        if (!successful) {
            return (false, retData);
        }

        // Step 2: Verify application enclave report MRENCLAVE and MRSIGNER
        {
            if (checkLocalEnclaveReport) {
                // 4k gas
                bool mrEnclaveIsTrusted = trustedUserMrEnclave[v3quote.localEnclaveReport.mrEnclave];
                bool mrSignerIsTrusted = trustedUserMrSigner[v3quote.localEnclaveReport.mrSigner];

                if (!mrEnclaveIsTrusted || !mrSignerIsTrusted) {
                    return (false, retData);
                }
            }
        }

        // Step 3: Verify enclave identity = 43k gas
        EnclaveIdStruct.EnclaveIdStatus qeTcbStatus;
        {
            bool verifiedEnclaveIdSuccessfully;
            (verifiedEnclaveIdSuccessfully, qeTcbStatus) =
                _verifyQEReportWithIdentity(v3quote.v3AuthData.pckSignedQeReport);
            if (!verifiedEnclaveIdSuccessfully) {
                return (false, retData);
            }
            if (
                !verifiedEnclaveIdSuccessfully
                    || qeTcbStatus
                        == EnclaveIdStruct.EnclaveIdStatus.SGX_ENCLAVE_REPORT_ISVSVN_REVOKED
            ) {
                return (false, retData);
            }
        }

        // Step 4: Parse Quote CertChain
        IPEMCertChainLib.ECSha256Certificate[] memory parsedQuoteCerts;
        TCBInfoStruct.TCBInfo memory fetchedTcbInfo;
        {
            // 536k gas
            parsedQuoteCerts = new IPEMCertChainLib.ECSha256Certificate[](3);
            for (uint256 i; i < 3; ++i) {
                bool isPckCert = i == 0; // additional parsing for PCKCert
                bool certDecodedSuccessfully;
                // TODO(Yue): move decodeCert offchain
                (certDecodedSuccessfully, parsedQuoteCerts[i]) = pemCertLib.decodeCert(
                    authDataV3.certification.decodedCertDataArray[i], isPckCert
                );
                if (!certDecodedSuccessfully) {
                    return (false, retData);
                }
            }
        }

        // Step 5: basic PCK and TCB check = 381k gas
        {
            string memory parsedFmspc = parsedQuoteCerts[0].pck.sgxExtension.fmspc;
            fetchedTcbInfo = tcbInfo[parsedFmspc];
            bool tcbConfigured = LibString.eq(parsedFmspc, fetchedTcbInfo.fmspc);
            if (!tcbConfigured) {
                return (false, retData);
            }

            IPEMCertChainLib.ECSha256Certificate memory pckCert = parsedQuoteCerts[0];
            bool pceidMatched = LibString.eq(pckCert.pck.sgxExtension.pceid, fetchedTcbInfo.pceid);
            if (!pceidMatched) {
                return (false, retData);
            }
        }

        // Step 6: Verify TCB Level
        TCBInfoStruct.TCBStatus tcbStatus;
        {
            // 4k gas
            bool tcbVerified;
            (tcbVerified, tcbStatus) = _checkTcbLevels(parsedQuoteCerts[0].pck, fetchedTcbInfo);
            if (!tcbVerified) {
                return (false, retData);
            }
        }

        // Step 7: Verify cert chain for PCK
        {
            // 660k gas (rootCA pubkey is trusted)
            bool pckCertChainVerified = _verifyCertChain(parsedQuoteCerts);
            if (!pckCertChainVerified) {
                return (false, retData);
            }
        }

        // Step 8: Verify the local attestation sig and qe report sig = 670k gas
        {
            bool enclaveReportSigsVerified = _enclaveReportSigVerification(
                parsedQuoteCerts[0].pubKey,
                signedQuoteData,
                authDataV3,
                v3quote.v3AuthData.pckSignedQeReport
            );
            if (!enclaveReportSigsVerified) {
                return (false, retData);
            }
        }

        retData = abi.encodePacked(sha256(abi.encode(v3quote)), tcbStatus);

        return (_attestationTcbIsValid(tcbStatus), retData);
    }
