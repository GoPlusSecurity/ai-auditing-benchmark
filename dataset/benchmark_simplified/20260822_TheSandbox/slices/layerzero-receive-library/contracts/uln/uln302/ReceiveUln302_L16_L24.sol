contract ReceiveUln302 is IReceiveUlnE2, ReceiveUlnBase, ReceiveLibBaseE2 {
    using PacketV1Codec for bytes;

    /// @dev CONFIG_TYPE_ULN=2 here to align with SendUln302/ReceiveUln302/ReceiveUln301
    uint32 internal constant CONFIG_TYPE_ULN = 2;

    error LZ_ULN_InvalidConfigType(uint32 configType);

    constructor(address _endpoint) ReceiveLibBaseE2(_endpoint) {}
