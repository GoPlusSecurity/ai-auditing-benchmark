contract EndpointV2 is ILayerZeroEndpointV2, MessagingChannel, MessageLibManager, MessagingComposer, MessagingContext {
    address public lzToken;

    mapping(address oapp => address delegate) public delegates;

    /// @param _eid the unique Endpoint Id for this deploy that all other Endpoints can use to send to it
    constructor(uint32 _eid, address _owner) MessagingChannel(_eid) {
        _transferOwnership(_owner);
    }
