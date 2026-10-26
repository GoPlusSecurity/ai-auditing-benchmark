contract OFTAdapterForSand is OFTAdapter, WithAdmin, ERC2771Handler {
    bool internal _enabled;

    /// @notice Emitted when the enabled state changes
    /// @param enabled The new enabled state
    event Enabled(bool enabled);

    /// @notice Custom error thrown when the send function is called while disabled
    error SendFunctionDisabled();

    /// @param sandToken SAND token address on the same network as the OFT Adapter
    /// @param layerZeroEndpoint local endpoint address
    /// @param owner owner used as a delegate in LayerZero Endpoint
    /// @param trustedForwarder trusted forwarder address
    constructor(
        address sandToken,
        address layerZeroEndpoint,
        address owner,
        address trustedForwarder,
        address admin
    ) OFTAdapter(sandToken, layerZeroEndpoint, owner) Ownable(owner) {
        __ERC2771Handler_initialize(trustedForwarder);
        _changeAdmin(admin);
        _enable(true);
    }
