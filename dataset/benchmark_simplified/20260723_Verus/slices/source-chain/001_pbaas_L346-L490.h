        FLAGS_MASK = 0x3ff
    };

    uint32_t nVersion;
    uint32_t flags;                         // notarization options
    CTransferDestination proposer;          // paid when this gets used on import (miner/staker, shares this with 1 notary for each validation)

    uint160 currencyID;                     // the primary currency this notarization represents for the system, may be gateway or external chain
    uint32_t notarizationHeight;            // <= height on the current system as of this notarization (can't be confirmed earlier)
    CCoinbaseCurrencyState currencyState;   // state of the currency being notarized as of this notarization

    CUTXORef prevNotarization;              // reference of the prior notarization on this system with which we agree
    uint256 hashPrevCrossNotarization;      // (this is not the same notarization as the prev notarization or prev height)
                                            //  it is the hash of the prior notarization on the other chain with which we agree, even one not yet confirmed
    uint32_t prevHeight;                    // height of previous notarization we agree with

    std::map<uint160, CCoinbaseCurrencyState> currencyStates; // currency state of other currencies to be co-notarized for gateways
    std::map<uint160, CProofRoot> proofRoots; // if cross-chain notarization, includes valid proof root of systemID at notarizationHeight + others verified

    std::vector<CNodeData> nodes;           // if cross chain notarization, network nodes

    CPBaaSNotarization() : nVersion(PBAAS_VERSION_INVALID), flags(0), notarizationHeight(0), prevHeight(0) {}

    CPBaaSNotarization(const uint160 &currencyid,
                       const CCoinbaseCurrencyState CurrencyState,
                       uint32_t height,
                       const CUTXORef &prevnotarization,
                       uint32_t prevheight,
                       const std::vector<CNodeData> &Nodes=std::vector<CNodeData>(),
                       const std::map<uint160, CCoinbaseCurrencyState> &CurrencyStates=std::map<uint160, CCoinbaseCurrencyState>(),
                       const CTransferDestination &Proposer=CTransferDestination(),
                       const std::map<uint160, CProofRoot> &ProofRoots=std::map<uint160, CProofRoot>(),
                       uint32_t version=VERSION_CURRENT,
                       uint32_t Flags=FLAGS_NONE) :
                       nVersion(version),
                       flags(Flags),
                       proposer(Proposer),
                       currencyID(currencyid),
                       notarizationHeight(height),
                       currencyState(CurrencyState),
                       prevNotarization(prevnotarization),
                       prevHeight(prevheight),
                       currencyStates(CurrencyStates),
                       proofRoots(ProofRoots),
                       nodes(Nodes)
    {
    }

    CPBaaSNotarization(const std::vector<unsigned char> &asVector)
    {
        ::FromVector(asVector, *this);
    }

    CPBaaSNotarization(const CTransaction &tx, int32_t *pOutIdx=nullptr);

    CPBaaSNotarization(const CScript &scriptPubKey);

    CPBaaSNotarization(const UniValue &obj);

    ADD_SERIALIZE_METHODS;

    template <typename Stream, typename Operation>
    inline void SerializationOp(Stream& s, Operation ser_action) {
        READWRITE(VARINT(nVersion));
        READWRITE(VARINT(flags));
        READWRITE(proposer);
        READWRITE(currencyID);
        READWRITE(currencyState);
        READWRITE(notarizationHeight);
        READWRITE(prevNotarization);
        READWRITE(hashPrevCrossNotarization);
        READWRITE(prevHeight);

        if (nVersion == VERSION_PBAAS_MAINNET)
        {
            std::vector<CCoinbaseCurrencyState> vecCurrencyStates;
            if (ser_action.ForRead())
            {
                READWRITE(vecCurrencyStates);
                for (auto &oneState : vecCurrencyStates)
                {
                    currencyStates.insert(std::make_pair(oneState.GetID(), oneState));
                }
            }
            else
            {
                for (auto &oneState : currencyStates)
                {
                    vecCurrencyStates.push_back(oneState.second);
                }
                READWRITE(vecCurrencyStates);
            }
            std::vector<CProofRoot> vecProofRoots;
            if (ser_action.ForRead())
            {
                READWRITE(vecProofRoots);
                for (auto &oneRoot : vecProofRoots)
                {
                    proofRoots.insert(std::make_pair(oneRoot.systemID, oneRoot));
                }
            }
            else
            {
                for (auto &oneRoot : proofRoots)
                {
                    vecProofRoots.push_back(oneRoot.second);
                }
                READWRITE(vecProofRoots);
            }
        }
        else
        {
            std::vector<std::pair<uint160, CCoinbaseCurrencyState>> vecCurrencyStates;
            if (ser_action.ForRead())
            {
                READWRITE(vecCurrencyStates);
                for (auto &oneState : vecCurrencyStates)
                {
                    currencyStates.insert(oneState);
                }
            }
            else
            {
                for (auto &oneState : currencyStates)
                {
                    vecCurrencyStates.push_back(oneState);
                }
                READWRITE(vecCurrencyStates);
            }
            std::vector<std::pair<uint160, CProofRoot>> vecProofRoots;
            if (ser_action.ForRead())
            {
                READWRITE(vecProofRoots);
                for (auto &oneRoot : vecProofRoots)
                {
                    proofRoots.insert(oneRoot);
                }
            }
            else
            {
                for (auto &oneRoot : proofRoots)
                {
                    vecProofRoots.push_back(oneRoot);
                }
                READWRITE(vecProofRoots);
