    function sendCurrencyToETHAddress(address tokenERCAddress, address destinationAddress, uint256 sendAmount, uint32 selector, uint256 TokenId ) private returns (uint8){
    
        bytes memory data;
        uint256 amount;
        bool success;
        if (selector == uint32(ERC20_MINT_SELECTOR) || selector == uint32(ERC20_SEND_SELECTOR)) {
            (success, data) = tokenERCAddress.call{gas: 30000}(abi.encodeWithSelector(ERC20.decimals.selector)); 
            if(!success || data.length != 32) {
                return SEND_FAILED;
            }

            uint256 dec = abi.decode(data, (uint256));
            if (dec > 18) {                 // 10**18 is the largest decimals used.
                return SEND_FAILED;
            }
            amount = convertFromVerusNumber(sendAmount, uint8(dec));
        }

        if(tokenERCAddress == DAIERC20ADDRESS) {
            address crossChainExportAddress = contracts[uint(VerusConstants.ContractType.VerusCrossChainExport)];
            (success,) = crossChainExportAddress.delegatecall(abi.encodeWithSelector(VerusCrossChainExport.exit.selector, destinationAddress, amount));
            return success ? SEND_SUCCESS : SEND_FAILED;
        }
        else if(selector == uint32(ERC20_MINT_SELECTOR) || selector == uint32(ERC20_SEND_SELECTOR)) {

            data = abi.encodeWithSelector(bytes4(selector), destinationAddress, amount);

        }
        else if(selector == uint32(ERC721_SEND_SELECTOR)) {

            data = abi.encodeWithSelector(bytes4(selector), address(this), destinationAddress, TokenId);

        }
        else if(selector == uint32(ERC1155_SEND_SELECTOR)) {

            data = abi.encodeWithSelector(bytes4(selector), address(this), destinationAddress, TokenId, sendAmount, "");

        } 
        (success, data) = tokenERCAddress.call{gas: 100000}(data);

        if (!success) return SEND_FAILED;
        if (data.length != 0) {
            // Anything other than empty must be a 32-byte boolean true encoding.
            if (data.length != 32 || abi.decode(data, (uint256)) == 0) {
                return SEND_FAILED;
            }
        }
        return selector == uint32(ERC20_MINT_SELECTOR) ? SEND_SUCCESS_ERC20_MINTED : SEND_SUCCESS;
    }
