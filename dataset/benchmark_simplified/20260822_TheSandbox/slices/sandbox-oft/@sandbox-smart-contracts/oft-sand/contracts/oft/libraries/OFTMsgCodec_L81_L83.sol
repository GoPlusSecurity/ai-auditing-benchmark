    function bytes32ToAddress(bytes32 _b) internal pure returns (address) {
        return address(uint160(uint256(_b)));
    }
