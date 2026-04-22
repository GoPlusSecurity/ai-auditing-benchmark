// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.21;

/// @title InputChecker
/// @author Florida St
/// @notice Some basic input checks.
library InputChecker {
    error AddressZeroError();

    function checkNotZero(address _address) internal pure {
        if (_address == address(0)) {
            revert AddressZeroError();
        }
    }
}
