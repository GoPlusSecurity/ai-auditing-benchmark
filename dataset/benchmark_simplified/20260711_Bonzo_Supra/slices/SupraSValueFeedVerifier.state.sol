/// @title Supra Oracle Value Feed Verifier Contract
/// @notice This contract verifies Oracle SMR Transactions using BLS Signatures and stores the price data
/// @dev The storage is done in a separate contract called `SupraSValueFeedStorage`
contract SupraSValueFeedVerifier is Ownable2StepUpgradeable,UUPSUpgradeable {
    /// @notice It is identification that is common for both client and contract
    /// @dev It is BLS signature verification dependency mostly keccak256 hash of some input
    bytes32 domain;

    /// @notice The current contract authority
    /// @dev It is the BN254 public key of the committee
    uint256[4] publicKey;

    ISupraSValueFeed public supraSValueFeedStorage;


    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    EnumerableSet.AddressSet private whitelistedFreeNodes;
    /// @notice Currently Deprecated
    /// @dev We need to keep this just to avoid storage collision
    EnumerableSet.UintSet private hccPairs;

    /// @dev Set of verified votes to minimize computation
    mapping(bytes32 smrVoteHash => bool duplicateSmrVote) verifiedVotes;
    /// @dev Set of processed transactions to prevent replay attacks
    mapping(bytes32 smrTxnHash => bool duplicateSmrTxn) processedTxns;

    uint256 internal blsPrecompileGasCost;

    mapping(uint256 committee_id => uint256[4] public_key) private committee_public_key;
    // Max Future time is 3sec from the current block time.
    uint256 public constant TIME_DELTA_ALLOWANCE = 3000;
