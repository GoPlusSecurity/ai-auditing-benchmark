    function _transferTokens(
        CanonicalERC20 memory _ctoken,
        address _to,
        uint256 _amount
    )
        private
        returns (address token_)
    {
        if (_ctoken.chainId == block.chainid) {
            token_ = _ctoken.addr;
            IERC20(token_).safeTransfer(_to, _amount);
        } else {
            token_ = _getOrDeployBridgedToken(_ctoken);
            //For native bridged tokens (like USDC), the mint() signature is the same, so no need to
            // check.
            IBridgedERC20(token_).mint(_to, _amount);
        }
    }
