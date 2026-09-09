// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {TransientSlot} from "./TransientSlot.sol";

abstract contract ReentrancyGuardTransient {
    using TransientSlot for *;

    bytes32 private constant REENTRANCY_GUARD_STORAGE =
        0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;

    error ReentrancyGuardReentrantCall();

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    modifier nonReentrantView() {
        _nonReentrantBeforeView();
        _;
    }

    function _nonReentrantBeforeView() private view {
        if (_reentrancyGuardEntered()) {
            revert ReentrancyGuardReentrantCall();
        }
    }

    function _nonReentrantBefore() private {

        _nonReentrantBeforeView();

        _reentrancyGuardStorageSlot().asBoolean().tstore(true);
    }

    function _nonReentrantAfter() private {
        _reentrancyGuardStorageSlot().asBoolean().tstore(false);
    }

    function _reentrancyGuardEntered() internal view returns (bool) {
        return _reentrancyGuardStorageSlot().asBoolean().tload();
    }

    function _reentrancyGuardStorageSlot() internal pure virtual returns (bytes32) {
        return REENTRANCY_GUARD_STORAGE;
    }
}
