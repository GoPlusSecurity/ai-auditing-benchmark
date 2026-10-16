    function _reserveSlot() private pure returns (StorageSlot.AddressSlot storage) {
        return StorageSlot.getAddressSlot(SLOT_RESERVE);
    }
