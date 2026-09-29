// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../common/EssentialResolverContract.sol";
import "../libs/LibAddress.sol";
import "../libs/LibMath.sol";
import "../libs/LibNames.sol";
import "../libs/LibNetwork.sol";
import "../signal/ISignalService.sol";
import "./IBridge.sol";
import "./IEthMinter.sol";

import "./Bridge_Layout.sol"; // DO NOT DELETE

/// @title Bridge
/// @notice See the documentation for {IBridge}.
/// @dev Labeled in address resolver as "bridge". Additionally, the code hash for the same address
/// on L1 and L2 may be different.
/// @custom:security-contact security@taiko.xyz
contract Bridge is EssentialResolverContract, IBridge, IEthMinter {
    using LibMath for uint256;
    using LibAddress for address;

    struct ProcessingStats {
        uint32 gasUsedInFeeCalc;
        uint32 proofSize;
        uint32 numCacheOps;
        bool processedByRelayer;
    }

    /// @dev A debug event for fine-tuning gas related constants in the future.
    event MessageProcessed(bytes32 indexed msgHash, Message message, ProcessingStats stats);

    /// @notice Emitted when an ETH minter is enabled or disabled.
    /// @param ethMinter The address of the ETH minter.
    /// @param enabled The enabled status.
    event EthMinterSet(address indexed ethMinter, bool enabled);

    /// @dev The amount of gas that will be deducted from message.gasLimit before calculating the
    /// invocation gas limit. This value should be fine-tuned with production data.
    uint32 public constant GAS_RESERVE = 800_000;

    /// @dev The gas overhead for both receiving and invoking a message, as well as the proof
    /// calldata cost.
    /// This value should be fine-tuned with production data.
    uint32 public constant GAS_OVERHEAD = 120_000;

    ///@dev The max proof size for a message to be processable by a relayer.
    uint256 public constant RELAYER_MAX_PROOF_BYTES = 200_000;

    /// @dev The amount of gas not to charge fee per cache operation.
    uint256 private constant _GAS_REFUND_PER_CACHE_OPERATION = 20_000;

    /// @dev Gas limit for sending Ether.
    // - EOA gas used is < 21000
    // - For Loopring smart wallet, gas used is about 23000
    // - For Argent smart wallet on Ethereum, gas used is about 24000
    // - For Gnosis Safe wallet, gas used is about 28000
    uint256 private constant _SEND_ETHER_GAS_LIMIT = 35_000;

    /// @dev Place holder value when not using transient storage
    uint256 private constant _PLACEHOLDER = type(uint256).max;

    ISignalService public immutable signalService;

    /// @notice The next message ID.
    /// @dev Slot 1.
    uint64 private __reserved1;
    uint64 public nextMessageId;

    /// @notice Mapping to store the status of a message from its hash.
    /// @dev Slot 2.
    mapping(bytes32 msgHash => Status status) public messageStatus;

    /// @dev Slots 3 and 4
    Context private __ctx;

    /// @dev Slot 5.
    uint256 private __reserved2;

    /// @dev Slot 6.
    uint256 private __reserved3;

    /// @dev Slot 7.
    mapping(address ethMinter => bool enabled) public isEthMinter;
    uint256[43] private __gap;

    // ---------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------

    modifier sameChain(uint64 _chainId) {
        _checkSameChain(_chainId);
        _;
    }

    modifier diffChain(uint64 _chainId) {
        _checkDiffChain(_chainId);
        _;
    }

