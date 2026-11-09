// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Design intent: Owner role only, reducing the attack surface.
// renounceOwnership is allowed; the Owner may voluntarily renounce permissions to obtain an immutable trust commitment.
contract Auth is Ownable {
  constructor() Ownable(msg.sender) {}
  error Auth_ZeroAddress();
}
// 0xCAFE - simplified auth: onlyOwner only
