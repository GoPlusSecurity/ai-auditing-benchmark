    function areVerifiersSufficient(address[] memory _verifiers)
        internal
        view
        override
        returns (bool)
    {
        if (_verifiers.length != 2) return false;

        if (_verifiers[0] == sgxGethVerifier) {
            return _verifiers[1] == sgxRethVerifier || _verifiers[1] == risc0RethVerifier
                || _verifiers[1] == sp1RethVerifier;
        }

        if (_verifiers[0] == sgxRethVerifier) {
            return _verifiers[1] == risc0RethVerifier || _verifiers[1] == sp1RethVerifier;
        }

        return false;
    }
