// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

library TransientSlot {
    type AddressSlot is bytes32;

    type BooleanSlot is bytes32;

    function asBoolean(bytes32 slot) internal pure returns (BooleanSlot) {
        return BooleanSlot.wrap(slot);
    }

    type Bytes32Slot is bytes32;

    type Uint256Slot is bytes32;

    type Int256Slot is bytes32;

    function tload(BooleanSlot slot) internal view returns (bool value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    function tstore(BooleanSlot slot, bool value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }
}
