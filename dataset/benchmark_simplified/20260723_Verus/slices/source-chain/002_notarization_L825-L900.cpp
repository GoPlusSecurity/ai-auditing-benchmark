    SetRefunding(uni_get_bool(find_value(obj, "refunding")));
    SetLaunchConfirmed(uni_get_bool(find_value(obj, "launchconfirmed")));
    SetLaunchComplete(uni_get_bool(find_value(obj, "launchcomplete")));
    if (uni_get_bool(find_value(obj, "ismirror")))
    {
        flags |= FLAG_ACCEPTED_MIRROR;
    }
    SetSameChain(uni_get_bool(find_value(obj, "samechain")));

    currencyID = ValidateCurrencyName(uni_get_str(find_value(obj, "currencyid")));
    if (currencyID.IsNull())
    {
        nVersion = VERSION_INVALID;
        return;
    }

    UniValue transferID = find_value(obj, "proposer");
    if (transferID.isObject())
    {
        proposer = CTransferDestination(transferID);
    }

    SetContractUpgrade(proposer.GetAuxDest(0), uni_get_bool(find_value(obj, "contractupgrade")));

    notarizationHeight = (uint32_t)uni_get_int64(find_value(obj, "notarizationheight"));
    currencyState = CCoinbaseCurrencyState(find_value(obj, "currencystate"));
    prevNotarization = CUTXORef(uint256S(uni_get_str(find_value(obj, "prevnotarizationtxid"))), (uint32_t)uni_get_int(find_value(obj, "prevnotarizationout")));
    hashPrevCrossNotarization = uint256S(uni_get_str(find_value(obj, "hashprevcrossnotarization")));
    prevHeight = (uint32_t)uni_get_int64(find_value(obj, "prevheight"));

    auto curStateArr = find_value(obj, "currencystates");
    auto proofRootArr = find_value(obj, "proofroots");
    auto nodesUni = find_value(obj, "nodes");

    if (curStateArr.isArray())
    {
        for (int i = 0; i < curStateArr.size(); i++)
        {
            std::vector<std::string> keys = curStateArr[i].getKeys();
            std::vector<UniValue> values = curStateArr[i].getValues();
            if (keys.size() != 1 or values.size() != 1)
            {
                nVersion = VERSION_INVALID;
                return;
            }
            currencyStates.insert(std::make_pair(GetDestinationID(DecodeDestination(keys[0])), CCoinbaseCurrencyState(values[0])));
        }
    }

    if (proofRootArr.isArray())
    {
        for (int i = 0; i < proofRootArr.size(); i++)
        {
            CProofRoot oneRoot(proofRootArr[i]);
            if (!oneRoot.IsValid())
            {
                nVersion = VERSION_INVALID;
                return;
            }
            proofRoots.insert(std::make_pair(oneRoot.systemID, oneRoot));
        }
    }

    if (nodesUni.isArray())
    {
        vector<UniValue> nodeVec = nodesUni.getValues();
        for (auto node : nodeVec)
        {
            nodes.push_back(CNodeData(uni_get_str(find_value(node, "networkaddress")), uni_get_str(find_value(node, "nodeidentity"))));
        }
    }
}

bool operator==(const CProofRoot &op1, const CProofRoot &op2)
{
    return op1.version == op2.version &&
