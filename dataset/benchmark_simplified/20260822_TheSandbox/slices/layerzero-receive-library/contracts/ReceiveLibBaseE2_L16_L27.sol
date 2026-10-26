abstract contract ReceiveLibBaseE2 is MessageLibBase, ERC165, IMessageLib {
    using PacketV1Codec for bytes;

    constructor(address _endpoint) MessageLibBase(_endpoint, ILayerZeroEndpointV2(_endpoint).eid()) {}

    function supportsInterface(bytes4 _interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return _interfaceId == type(IMessageLib).interfaceId || super.supportsInterface(_interfaceId);
    }

    function messageLibType() external pure virtual override returns (MessageLibType) {
        return MessageLibType.Receive;
    }
