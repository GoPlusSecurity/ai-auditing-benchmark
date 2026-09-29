    function hashMessage(Message memory _message) public pure returns (bytes32) {
        /// forge-lint: disable-next-line(asm-keccak256)
        return keccak256(abi.encode("TAIKO_MESSAGE", _message));
    }
