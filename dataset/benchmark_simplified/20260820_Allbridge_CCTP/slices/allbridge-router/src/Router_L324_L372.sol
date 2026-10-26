    function _calculateMessageHash(
        uint256 _nonce,
        bytes32 recipient,
        bytes32 destinationToken,
        uint256 amount,
        uint32 sourceChain,
        uint32 destinationChain
    ) internal pure returns (bytes32 messageHash) {
        // Tests show that this approach uses less gas.
        // forge-lint: disable-start(asm-keccak256)
        return keccak256(abi.encodePacked(_nonce, recipient, destinationToken, amount, sourceChain, destinationChain));
    }

    /**
     * @dev Normalizes a token amount to the standard 9 decimals (SYSTEM_DECIMALS).
     * This ensures consistency for calculations across different tokens with varying decimals.
     * @param amount The original token amount to be normalized.
     * @param decimals The original decimal count of the token.
     * @return The normalized token amount.
     */
    function _normalize(uint256 amount, uint8 decimals) internal pure returns (uint256) {
        if (decimals >= SYSTEM_DECIMALS) {
            return amount / (10 ** (decimals - SYSTEM_DECIMALS));
        } else {
            return amount * (10 ** (SYSTEM_DECIMALS - decimals));
        }
    }

    /**
     * @dev Converts a normalized token amount from SYSTEM_DECIMALS (9) back to its original decimal representation.
     * This is used when transferring tokens to users in their original decimal format.
     * @param amount The normalized token amount.
     * @param decimals The target decimal count of the token.
     * @return The denormalized token amount in the original decimals.
     */
    function _denormalize(uint256 amount, uint8 decimals) internal pure returns (uint256) {
        if (decimals >= SYSTEM_DECIMALS) {
            return amount * (10 ** (decimals - SYSTEM_DECIMALS));
        } else {
            return amount / (10 ** (SYSTEM_DECIMALS - decimals));
        }
    }

    function _getDecimals(address token) internal view returns (uint8) {
        if (token == ETH_MARKER) {
            return 18;
        }
        return ERC20(token).decimals();
    }
