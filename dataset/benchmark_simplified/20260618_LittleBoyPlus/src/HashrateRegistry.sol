// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

contract HashrateRegistry {
    address public immutable lbp;

    address public immutable hashrate;

    address public immutable pair;

    address public immutable burnVault;

    address public immutable refVault;

    address public immutable polVault;

    address public immutable fomoVault;

    error ZeroAddress();

    constructor(
        address _lbp,
        address _hashrate,
        address _pair,
        address _burnVault,
        address _refVault,
        address _polVault,
        address _fomoVault
    ) {
        if (
            _lbp == address(0) || _hashrate == address(0) || _pair == address(0)
                || _burnVault == address(0) || _refVault == address(0) || _polVault == address(0)
                || _fomoVault == address(0)
        ) revert ZeroAddress();

        lbp = _lbp;
        hashrate = _hashrate;
        pair = _pair;
        burnVault = _burnVault;
        refVault = _refVault;
        polVault = _polVault;
        fomoVault = _fomoVault;
    }
}
