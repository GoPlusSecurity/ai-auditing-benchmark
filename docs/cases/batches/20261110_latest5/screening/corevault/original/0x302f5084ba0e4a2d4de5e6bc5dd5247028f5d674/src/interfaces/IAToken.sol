// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// N7-fix: interface strictly aligned with the AToken V3 implementation -- tradingEnabled/setTradingEnabled removed (deleted in AToken V3), setMcapThreshold kept
// Phase3-removed: setInsurancePool / setPancakeRouter were removed along with "in-transfer synchronous market-making trigger"
//   (that path always reverted and was swallowed by catch{}; market-making changed to a keeper calling InsurancePool directly).
interface IAToken is IERC20 {
  function setWhitelist(address addr, bool enabled) external;
  function setMcapThreshold(uint256 v) external;
  function setPair(address pair) external;
  function setTreasury(address tr) external;
  function setBUsdtPair(address pair) external;
  function transferFromPair(address to, uint256 amount) external;
  function feewallet2() external view returns (address);
  function pancakePair() external view returns (address);
  function treasury() external view returns (address);
  function bUsdtPair() external view returns (address);
  function whitelist(address) external view returns (bool);
  function mcapThreshold() external view returns (uint256);
  // Phase2 addon: EIP-2612 permit -- lets the staking entry points (stakeA/stakeB) use zero-approval signatures for principal and opposite-token fuel fee
  function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
}
