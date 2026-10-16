    function _storage() internal pure returns (DripsHubStorage storage dripsHubStorage) {
        bytes32 slot = SLOT_STORAGE;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Based on OpenZeppelin's StorageSlot
            dripsHubStorage.slot := slot
        }
    }
