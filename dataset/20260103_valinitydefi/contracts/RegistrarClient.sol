// SPDX-License-Identifier: MIT

// solhint-disable one-contract-per-file
// solhint-disable gas-custom-errors

pragma solidity ^0.8.27;

import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { ValinityRegistrar } from "./ValinityRegistrar.sol";

abstract contract RegistrarClientBase is Context {
    ValinityRegistrar internal _registrar;

    modifier onlyRegistrar() {
        require(_msgSender() == address(_registrar), "Unauthorized, registrar only");
        _;
    }

    function getRegistrar() external view returns (address) {
        return address(_registrar);
    }
}

abstract contract RegistrarClient is RegistrarClientBase {
    constructor(address registrarAddress) {
        require(registrarAddress != address(0), "Invalid address");
        _registrar = ValinityRegistrar(registrarAddress);
    }
}

abstract contract RegistrarClientInitializable is Initializable, RegistrarClientBase {
    // solhint-disable-next-line func-name-mixedcase
    function __RegistrarClient_init(address registrarAddress) internal onlyInitializing {
        require(registrarAddress != address(0), "Invalid address");
        _registrar = ValinityRegistrar(registrarAddress);
    }
}
