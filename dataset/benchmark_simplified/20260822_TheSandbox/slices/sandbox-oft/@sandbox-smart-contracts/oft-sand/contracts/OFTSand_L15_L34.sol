contract OFTSand is SandBaseToken, ERC2771Handler, OFTCore {
    bool internal _enabled;

    /// @notice Emitted when the enabled state changes
    /// @param enabled The new enabled state
    event Enabled(bool enabled);

    /// @notice Custom error thrown when the send function is called while disabled
    error SendFunctionDisabled();

    constructor(
        address trustedForwarder,
        address sandAdmin,
        address executionAdmin,
        address layerZeroEndpoint,
        address owner
    ) SandBaseToken(sandAdmin, executionAdmin, address(0), 0) OFTCore(18, layerZeroEndpoint, owner) Ownable(owner) {
        __ERC2771Handler_initialize(trustedForwarder);
        _enable(true);
    }
