struct Verification {
    bool submitted;
    uint64 confirmations;
}

/// @dev includes the utility functions for checking ULN states and logics
abstract contract ReceiveUlnBase is UlnBase {
    using PacketV1Codec for bytes;

    mapping(bytes32 headerHash => mapping(bytes32 payloadHash => mapping(address dvn => Verification)))
        public hashLookup;
