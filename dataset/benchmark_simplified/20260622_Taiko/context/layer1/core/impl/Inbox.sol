// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IBondManager } from "../iface/IBondManager.sol";
import { ICodec } from "../iface/ICodec.sol";
import { IForcedInclusionStore } from "../iface/IForcedInclusionStore.sol";
import { IInbox } from "../iface/IInbox.sol";
import { IProposerChecker } from "../iface/IProposerChecker.sol";
import { IProverWhitelist } from "../iface/IProverWhitelist.sol";
import { LibBlobs } from "../libs/LibBlobs.sol";
import { LibBonds } from "../libs/LibBonds.sol";
import { LibCodec } from "../libs/LibCodec.sol";
import { LibForcedInclusion } from "../libs/LibForcedInclusion.sol";
import { LibHashOptimized } from "../libs/LibHashOptimized.sol";
import { LibInboxSetup } from "../libs/LibInboxSetup.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";
import { LibMath } from "src/shared/libs/LibMath.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { ISignalService } from "src/shared/signal/ISignalService.sol";

/// @title Inbox
/// @notice Core contract for managing L2 proposals, proof verification, and forced inclusion in
/// Taiko's based rollup architecture.
/// @dev The Pacaya inbox contract is not being upgraded to the Shasta implementation;
///      instead, Shasta uses a separate inbox address.
/// @dev This contract implements the fundamental inbox logic including:
///      - Proposal submission with forced inclusion support
///      - Sequential proof verification
///      - Ring buffer storage for efficient state management
///      - Bond accounting and liveness bond processing
///      - Finalization of proven proposals with checkpoint syncing
/// @custom:security-contact security@taiko.xyz
contract Inbox is IInbox, ICodec, IForcedInclusionStore, IBondManager, EssentialContract {
    using LibAddress for address;
    using LibBonds for LibBonds.Storage;
    using LibForcedInclusion for LibForcedInclusion.Storage;
    using LibMath for uint48;
    using LibMath for uint256;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Result from consuming forced inclusions
    struct ConsumptionResult {
        DerivationSource[] sources;
        bool allowsPermissionless;
    }

    // Constants
    // ---------------------------------------------------------------

    /// @notice Maximum number of forced inclusions processed per proposal.
    /// @dev Must be < 12 to avoid derived block timestamps drifting into the future when proposals
    /// happen every L1 slot (Derivation enforces 1s block times).
    uint256 internal constant MAX_FORCED_INCLUSIONS_PER_PROPOSAL = 10;

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @notice The proof verifier contract.
    IProofVerifier internal immutable _proofVerifier;

    /// @notice The proposer checker contract.
    IProposerChecker internal immutable _proposerChecker;

    /// @notice The prover whitelist contract (address(0) means no whitelist)
    IProverWhitelist internal immutable _proverWhitelist;

    /// @notice Signal service responsible for checkpoints.
    ISignalService internal immutable _signalService;

    /// @notice ERC20 token used as bond.
    IERC20 internal immutable _bondToken;

    /// @notice Minimum bond the proposer is required to have in gwei.
    uint64 internal immutable _minBond;

    /// @notice Liveness bond amount in gwei.
    uint64 internal immutable _livenessBond;

    /// @notice Time delay required before withdrawal after request.
    uint48 internal immutable _withdrawalDelay;

    /// @notice The proving window in seconds.
    uint48 internal immutable _provingWindow;

    /// @notice The delay after which proving becomes permissionless when whitelist is enabled.
    uint48 internal immutable _permissionlessProvingDelay;

    /// @notice Maximum delay allowed between sequential proofs to remain on time.
    uint48 internal immutable _maxProofSubmissionDelay;

    /// @notice The ring buffer size for storing proposal hashes.
    uint48 internal immutable _ringBufferSize;

    /// @notice The percentage of basefee paid to coinbase.
    uint8 internal immutable _basefeeSharingPctg;

    /// @notice The delay for forced inclusions measured in seconds.
    uint16 internal immutable _forcedInclusionDelay;

    /// @notice The base fee for forced inclusions in Gwei.
    uint64 internal immutable _forcedInclusionFeeInGwei;

    /// @notice Queue size at which the fee doubles. See Config for formula details.
    uint64 internal immutable _forcedInclusionFeeDoubleThreshold;

    /// @notice The multiplier to determine when a forced inclusion is too old so that proposing
    /// becomes permissionless
    uint8 internal immutable _permissionlessInclusionMultiplier;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice The timestamp when the first activation occurred.
    uint48 public activationTimestamp;

    /// @notice Persisted core state.
    CoreState internal _coreState;

    /// @dev Ring buffer for storing proposal hashes indexed by buffer slot
    /// - bufferSlot: The ring buffer slot calculated as proposalId % ringBufferSize
    /// - proposalHash: The keccak256 hash of the Proposal struct
    mapping(uint256 bufferSlot => bytes32 proposalHash) internal _proposalHashes;

    /// @dev Storage for forced inclusion requests
    /// @dev 2 slots used
    LibForcedInclusion.Storage private _forcedInclusionStorage;

    /// @dev Storage for bond balances.
    LibBonds.Storage private _bondStorage;

    uint256[43] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes the Inbox contract
    /// @param _config Configuration struct containing all constructor parameters
