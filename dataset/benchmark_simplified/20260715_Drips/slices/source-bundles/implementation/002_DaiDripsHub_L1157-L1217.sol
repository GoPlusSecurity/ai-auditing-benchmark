    struct ReceiverState {
        // The amount collectable independently from cycles
        uint128 collectable;
        // The next cycle to be collected
        uint64 nextCollectedCycle;
        // --- SLOT BOUNDARY
        // The changes of collected amounts on specific cycle.
        // The keys are cycles, each cycle `C` becomes collectable on timestamp `C * cycleSecs`.
        // Values for cycles before `nextCollectedCycle` are guaranteed to be zeroed.
        // This means that the value of `amtDeltas[nextCollectedCycle].thisCycle` is always
        // relative to 0 or in other words it's an absolute value independent from other cycles.
        mapping(uint64 => AmtDelta) amtDeltas;
    }

    struct AmtDelta {
        // Amount delta applied on this cycle
        int128 thisCycle;
        // Amount delta applied on the next cycle
        int128 nextCycle;
    }

    struct UserOrAccount {
        bool isAccount;
        address user;
        uint256 account;
    }

    struct DripsHubStorage {
        /// @notice Users' splits configuration hashes, see `hashSplits`.
        /// The key is the user address.
        mapping(address => bytes32) splitsHash;
        /// @notice Users' drips configuration hashes, see `hashDrips`.
        /// The key is the user address.
        mapping(address => bytes32) userDripsHashes;
        /// @notice Users' accounts' configuration hashes, see `hashDrips`.
        /// The key are the user address and the account.
        mapping(address => mapping(uint256 => bytes32)) accountDripsHashes;
        /// @notice Users' receiver states.
        /// The key is the user address.
        mapping(address => ReceiverState) receiverStates;
    }

    /// @param _cycleSecs The length of cycleSecs to be used in the contract instance.
    /// Low value makes funds more available by shortening the average time of funds being frozen
    /// between being taken from the users' drips balances and being collectable by their receivers.
    /// High value makes collecting cheaper by making it process less cycles for a given time range.
    constructor(uint64 _cycleSecs) {
        cycleSecs = _cycleSecs;
    }

    /// @notice Returns the contract storage.
    /// @return dripsHubStorage The storage.
    function _storage() internal pure returns (DripsHubStorage storage dripsHubStorage) {
        bytes32 slot = SLOT_STORAGE;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Based on OpenZeppelin's StorageSlot
            dripsHubStorage.slot := slot
        }
    }

