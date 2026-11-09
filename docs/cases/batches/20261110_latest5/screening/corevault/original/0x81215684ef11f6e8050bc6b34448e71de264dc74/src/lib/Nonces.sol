// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
// OZ v5.x Nonces compatibility layer -- v4.9.6 lacks this module
abstract contract Nonces {
  mapping(address => uint256) private _nonces;
  function nonces(address owner) public view virtual returns (uint256) { return _nonces[owner]; }
  function _useNonce(address owner) internal virtual returns (uint256 current) { current = _nonces[owner]; _nonces[owner]++; }
}
