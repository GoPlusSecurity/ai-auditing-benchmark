abstract contract OFTAdapter is OFTCore {
    using SafeERC20 for IERC20;

    IERC20 internal immutable innerToken;

    /// @dev Constructor for the OFTAdapter contract.
    /// @param _token The address of the ERC-20 token to be adapted.
    /// @param _lzEndpoint The LayerZero endpoint address.
    /// @param _delegate The delegate capable of making OApp configurations inside of the endpoint.
    constructor(
        address _token,
        address _lzEndpoint,
        address _delegate
    ) OFTCore(IERC20Metadata(_token).decimals(), _lzEndpoint, _delegate) {
        innerToken = IERC20(_token);
    }

    /// @dev Retrieves the address of the underlying ERC20 implementation.
    /// @return The address of the adapted ERC-20 token.
    /// @dev In the case of OFTAdapter, address(this) and erc20 are NOT the same contract.
    function token() public view returns (address) {
        return address(innerToken);
    }
