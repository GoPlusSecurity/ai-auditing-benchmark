// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPancakePair} from "../src/interfaces/IPancake.sol";
import {OracleLib} from "../src/core/OracleLib.sol";
import {GlobalConfig} from "../src/core/GlobalConfig.sol";
import {CoreVaultStorage} from "./CoreVaultStorage.sol";

/// @title  CoreVaultAdmin -- admin configuration & Oracle price views
/// @notice set* admin functions + spot/average price query functions
/// @dev WARNING: this file is the "3rd generation" rewritten version -- for evidence and limitations see the top note of CoreVaultStorage.sol.
///      Differences from the 2nd generation (byte-for-byte reconstructed version), each item established by **on-chain selector probing**:
///        - `setAWbnbPair(address)`      -> `setAOskFistPair(address)`   (b484743b hit)
///        - `setBWbnbPair(address)`      -> `setBUsdtPair(address)`      (95fb3312 hit)
///        - `setWbnbAddress(address)`    -> **removed** (all naming variants, none hit)
///        - `setSwapEngine(address)`     -> **removed** (60f3b696 miss)
///        - added `setDepositBounds(uint256,uint256,uint256,uint256)` (92736b07 hit)
///        - added `depositBounds()`                                   (562705dc hit)
abstract contract CoreVaultAdmin is CoreVaultStorage {
  using SafeERC20 for IERC20;

  // ── Oracle configuration ──
  function setAPerUsd(uint256 r) external onlyOwner { if (r == 0) revert CoreVault_ZeroPrice(); _oracle.aPerUsd = r; }
  function setBPerUsd(uint256 r) external onlyOwner { if (r == 0) revert CoreVault_ZeroPrice(); _oracle.bPerUsd = r; }
  function setWbnbPerUsd(uint256 r) external onlyOwner { if (r == 0) revert CoreVault_ZeroPrice(); _oracle.wbnbPerUsd = r; }
  /// @dev Requirement 2.0 L144: the USD price source of FIST = the mainnet FIST/USDT pair (the original aWbnb/bWbnb dual pairs are deprecated).
  ///      Since the 3rd generation this contract configures only **three** pairs: OSK/FIST, WBNB/USDT, FIST/USDT.
  function setAOskFistPair(address p) external onlyOwner { if (p == address(0)) revert CoreVault_ZeroAddress(); _oracle.aOskFistPair = IPancakePair(p); }
  function setBUsdtPair(address p) external onlyOwner { if (p == address(0)) revert CoreVault_ZeroAddress(); _oracle.bUsdtPair = IPancakePair(p); }
  function setWbnbUsdtPair(address p) external onlyOwner { if (p == address(0)) revert CoreVault_ZeroAddress(); _oracle.wbnbUsdtPair = IPancakePair(p); }
  function setBPool(address p) external onlyOwner { if (p == address(0)) revert CoreVault_ZeroAddress(); bPool = p; }
  function setAPool(address p) external onlyOwner { if (p == address(0)) revert CoreVault_ZeroAddress(); aPool = p; }
  function setFeewallet1(address w) external onlyOwner { if (w == address(0)) revert CoreVault_ZeroAddress(); feewallet1 = w; }

  /// @notice Wiring contract for the node mining pool 30% dividend routing (NodePoolDistributor)
  /// @dev Source: `node-requirements-doc.txt` section 1, entitlements -- 30% of network-wide static revenue -> four-pool weighting 5/5/10/10.
  ///      The 9/21 on-chain deployment has this selector (3b00b729); this function restores it.
  /// Pitfall: only owner is allowed; reject address(0) -- if zeroing were allowed, the node leg would be silently disabled with no trace.
  ///      At runtime, when not wired the node leg is **silently skipped** (see CoreVaultFarming), so disabling it should go through "not calling" rather than "calling with zero".
  function setNodePoolDistributor(address p) external onlyOwner {
    if (p == address(0)) revert CoreVault_ZeroAddress();
    nodePoolDistributor = p;
    emit NodePoolDistributorSet(p);
  }

  // ════════════════════════════════════════════════════════════
  //  3rd generation addition: farming deposit bounds (owner-adjustable)
  // ════════════════════════════════════════════════════════════
  // Design intent: production takes the GlobalConfig production values by default (0.1-10 BNB / 100-10000 USD);
  //   the mainnet test build has owner override them with small bounds, so end-to-end verification runs on the real chain without moving large funds.
  // Pitfall: deposit validation must read these 4 **storage** variables, not the GlobalConfig constants directly --
  //   otherwise the test-build override has no effect, and the test build and the production build must be compiled and deployed separately.
  // Pitfall: only owner is allowed; revert when the bounds are invalid (min > max or max == 0) to prevent permanently locking the deposit channel.
  function setDepositBounds(uint256 minBnb, uint256 maxBnb, uint256 minUsd, uint256 maxUsd) external onlyOwner {
    if (maxBnb == 0 || maxUsd == 0 || minBnb > maxBnb || minUsd > maxUsd) revert CoreVault_InvalidAmount();
    _minDepositBnb = minBnb;
    _maxDepositBnb = maxBnb;
    _minDepositUsd = minUsd;
    _maxDepositUsd = maxUsd;
    emit DepositBoundsUpdated(minBnb, maxBnb, minUsd, maxUsd);
  }

  /// @notice Emergency withdrawal (owner only) -- operational fallback confirmed by the client on 2026-09-25.
  /// @dev Policy: **no token restriction, full-amount withdrawal allowed**.
  /// WARNING: safety boundary (must be understood): CoreVault only holds OSK and FIST, and both **are user staking principal**
  ///   (principal of pools A/B + static yield held on exit). So this function is equivalent to "owner can withdraw user principal" --
  ///   this is a capability **deliberately granted to a trusted owner** (for testnet recovery / extreme failure rescue),
  ///   and production must replace owner with a multisig (Ownable2Step / AccessControl).
  /// Pitfall: apply `transientNonReentrant` -- token is an arbitrary address, and a malicious token can reenter during transfer.
  /// Pitfall: reject the zero address to avoid an accidental transfer into a black hole.
  function emergencyWithdraw(address token, address to, uint256 amount) external onlyOwner transientNonReentrant {
    if (token == address(0) || to == address(0)) revert CoreVault_ZeroAddress();
    if (amount == 0) revert CoreVault_InvalidAmount();
    IERC20(token).safeTransfer(to, amount);
    emit EmergencyWithdrawn(token, to, amount);
  }

  /// @dev Currently effective farming deposit bounds (post-deployment check / frontend display)
  ///      Returns: (BNB lower bound, BNB upper bound, USD lower bound, USD upper bound)
  function depositBounds() external view returns (uint256 minBnb, uint256 maxBnb, uint256 minUsd, uint256 maxUsd) {
    return (_minDepositBnb, _maxDepositBnb, _minDepositUsd, _maxDepositUsd);
  }

  // ── Price views ──

  function getAPerUsd() external virtual returns (uint256) {
    (uint256 aPerUsd, , ) = OracleLib.getAccountingPrices(_oracle);
    return aPerUsd;
  }

  function getBPerUsd() external virtual returns (uint256) {
    (, uint256 bPerUsd, ) = OracleLib.getAccountingPrices(_oracle);
    return bPerUsd;
  }

  function getWbnbPerUsd() external virtual returns (uint256) {
    (, , uint256 wbnbPerUsd) = OracleLib.getAccountingPrices(_oracle);
    return wbnbPerUsd;
  }

  // WARNING: 3rd generation change 4: `getSwapPrices()` **has been removed from this layer**.
  //   Rationale: in `src/CoreVault.sol` the signature of this function is `override(IAccounting)` -- listing **only**
  //   `IAccounting`. If this layer still declared it, the compiler would require CoreVault to also override this contract
  //   (Error 4327: Function needs to specify overridden contract "CoreVaultAdmin").
  //   So the 3rd generation pulled `getSwapPrices` back into the `CoreVault` body as a direct implementation (it is
  //   a required member of IAccounting; relying only on wrapper forwarding would leave the interface unsatisfied -> CoreVault becomes abstract and undeployable).
  //   The on-chain `getSwapPrices()` (9f7bf1e1) still hits, consistent with "the implementation stays in CoreVault".
  //   Note: getAPerUsd/getBPerUsd/getWbnbPerUsd **remain in this layer** (CoreVault overrides them with
  //   `override(CoreVaultAdmin, IAccounting)`, which shows the multiple-base inheritance relationship holds).

  // ── Staking fuel fee spot prices (deprecated) ──
  // Requirement 2.0 sections 3/4: the fuel fee is charged "in the staking token itself", so the 2% no longer needs to be converted into the opposite token;
  //   the original _getSpotStakePrices() has no remaining callers and was deleted to avoid confusion (following this repo's "delete dead code" convention).
  //   The spot definitions of aPrice/bPrice are still provided by OracleLib.spot*, callable directly from sub-contracts when needed.

  // ── Shared payout (exposed upward for CoreVaultReferral / CoreVaultStaking to call) ──

  function _payoutStaking(address to, uint256 amount, TokenType t) internal {
    if (amount == 0) return;
    IERC20 token = (t == TokenType.A) ? IERC20(address(aToken)) : IERC20(address(bToken));
    uint256 bal = token.balanceOf(address(this));
    if (amount > bal) revert CoreVault_Shortfall(amount, bal);
    token.safeTransfer(to, amount);
  }
}
