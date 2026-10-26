    mapping(address receiver => mapping(uint32 srcEid => mapping(bytes32 sender => uint64 nonce)))
        public lazyInboundNonce;
    mapping(address receiver => mapping(uint32 srcEid => mapping(bytes32 sender => mapping(uint64 inboundNonce => bytes32 payloadHash))))
        public inboundPayloadHash;
