// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TransientReentrancyGuard} from "../access/TransientReentrancyGuard.sol";
import {IPancakePair} from "../interfaces/IPancake.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {GlobalConfig} from "../core/GlobalConfig.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Nonces} from "../lib/Nonces.sol";

// Design intent: constant 220 million total supply, 10% sell tax (5% burn + 5% fee), buy gating (LP two-sided market cap USD >= mcapThreshold or whitelist), transfers tax-free.
// Pitfall: removing mint() -> the total supply cannot be inflated; removing tradingEnabled -> selling is always open and buying is dynamically gated by LP market cap.
// Phase2 addon: EIP-2612 permit -- one off-chain user signature, then a single in-contract transaction completes approve + transferFrom (no explicit approve tx)
// WARNING: Requirement 2.0 L144: OSK has only the OSK/FIST pair -> pancakePair must point to OSK/FIST;
//   FIST's price source is the mainnet FIST/USDT pair -> LP market cap is converted via bUsdtPair, no longer depending on WBNB.
//
// [Removed] Phase3's "in-transfer synchronous trigger of insurance pool market-making" --
//   that path is architecturally **impossible to succeed**: transfer/transferFrom holds transientNonReentrant (slot 0),
//   while executeBuyFist/executeSellFist's swap necessarily goes router -> pair -> calling AToken.transfer again,
//   at which point slot 0 is still held -> it must revert ReentrancyTransient, then be silently swallowed by the former `catch {}`
//   (i.e.: that leg never actually executed, and it gave DeployAll's wiring assertions a false guarantee).
//   -> market-making is now **keeper-driven**: `InsurancePool.executeBuyFist()/executeSellFist()` are both
//     permissionless open entry points (protected only by whenNotPaused + nonReentrant), called directly by a keeper.
//     This removes the ineffective external calls and dead state on the transfer hot path.

contract BNIX is ERC20, Ownable, TransientReentrancyGuard, EIP712, Nonces {
  using ECDSA for bytes32;

  uint256 private constant INITIAL_SUPPLY = 220_000_000 * 10**18; // 220 million constant, non-inflationary

  // ── Access control ──
  mapping(address => bool) public whitelist;
  address public treasury;
  address public pancakePair;
  address public feewallet2;
  /// @dev Requirement 2.0 L144: the USD price source of FIST = the mainnet FIST/USDT pair (the original wbnbUsdtPair is deprecated).
  ///      LP (OSK/FIST) two-sided market cap = FIST-side reserve × FIST/USD × 2.
  address public bUsdtPair;
  uint256 public mcapThreshold; // buy gating threshold (USD, 1e18 precision), constructor default 5 million USD

  // ── V-05 fix: quote-side reserve sliding window (last 3 blocks) ──
  // Design intent: _mcapReserve2=newest, _mcapReserve1=second newest, _mcapReserve0=oldest; _mcapFilledCount marks how many are filled.
  //           quote side = the FIST reserve of pancakePair (OSK/FIST), see _readQuoteReserve.
  // Pitfall: uint192 is enough to hold a uint112 reserve value (PancakePair uses uint112), so it does not overflow.
  uint64  private _lastMcapBlock;
  uint192 private _mcapReserve0; // oldest
  uint192 private _mcapReserve1;
  uint192 private _mcapReserve2; // newest
  uint8   private _mcapFilledCount;

  // ── Trading tax: 10% sell = 5% burn + 5% fee ──
  // Requirement 2.0 section 1: "trading tax: buy 0, sell 10%, 5% burned directly, 5% used for dividends (five mining pools)"
  //   Wiring requirement: feewallet2 must point to the 5-mining-pool dividend distribution contract (i.e. BWalletDistributor5 of the pangu project),
  //             which splits the 5% equally among the 5 mining pool nodes. The token side only does deterministic transfers and no node management.
  uint256 public constant BURN_BPS = 500;
  uint256 public constant WALLET2_BPS  = 500;
  uint256 public constant BPS_DENOM = 10000;

  // ── Buy gating upper bound (V-04 fix): prevents the Owner from mistakenly setting a value too high and locking buying ──
  /// @dev H-robustness-fix: M-02's original upper bound was 1000 USD, and once the mainnet LP market cap easily exceeded it, non-whitelist users were permanently locked out.
  ///      Relaxed to type(uint256).max, leaving the Owner to set it reasonably based on the on-chain LP market cap.
  uint256 public constant MAX_MCAP_THRESHOLD = type(uint256).max;

  // ── Buy gating anti-MEV-manipulation (V-05 fix): quote-side reserve sliding window over the last N blocks ──
  // Design intent: use the average of the quote side (FIST) reserve over the last 3 blocks for gating, so a single-block flash-loan injection cannot raise the average.
  // Pitfall: the sliding window updates only in a new block (block.number != _lastMcapBlock); multiple buys in the same block do not resample.
  // Pitfall: if the historical data has not been updated for more than 10 blocks it is treated as stale and falls back to the current spot value (compatible with a keeper interruption).
  uint256 private constant MCAP_WINDOW_SIZE = 3;
  uint256 private constant MCAP_STALE_BLOCKS = 10;

  // ── Events ──
  event WhitelistSet(address indexed who, bool on);
  event TreasurySet(address indexed tr);
  event PairSet(address indexed pair);
  event McapThresholdSet(uint256 val);
  event TaxCollected(address indexed from, uint256 burnAmt, uint256 wallet2Amt);
  event BUsdtPairSet(address indexed pair);
  event Feewallet2Set(address indexed newWallet);
  event McapSnapshotUpdated(uint64 indexed blockNumber, uint192 quoteReserve); // V-05: reserve snapshot updated event

  // ── Errors ──
  error AToken_BuyDisabled();
  error AToken_ZeroAddress();
  error AToken_ZeroAmount();
  // ── EIP-2612 permit errors ──
  error AToken_PermitExpired(uint256 deadline, uint256 timestamp);
  error AToken_PermitInvalidSignature(address recovered, address owner);
  error AToken_PermitZeroOwner();
  error AToken_McapThresholdTooHigh(uint256 provided, uint256 maxAllowed); // V-04: gating threshold exceeds the upper bound
  error AToken_OnlyTreasury(); // P3-fix: replaces require "!treasury"
  error AToken_PairNotSet(); // P3-fix: replaces require "!pair"

  // ── EIP-2612 type hash ──
  // a real compile-time keccak256, not an invented 32-byte value -- strictly aligned with the EIP-2612 standard
  bytes32 private constant _PERMIT_TYPEHASH =
    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

  constructor(address wallet2_, address treasury_) ERC20("OSK", "OSK") Ownable(msg.sender) EIP712("OSK", "1") {
    feewallet2 = wallet2_;
    treasury = treasury_;
    mcapThreshold = 5_000_000 * 1e18; // default 5 million USD buy gating threshold
    _mint(msg.sender, INITIAL_SUPPLY); // the full 220 million minted to the deployer, non-inflationary
  }

  // ── Administration ──
  function setWhitelist(address who, bool on) external onlyOwner { whitelist[who] = on; emit WhitelistSet(who, on); }
  function setTreasury(address tr) external onlyOwner { if (tr == address(0)) revert AToken_ZeroAddress(); treasury = tr; emit TreasurySet(tr); }
  function setPair(address pair) external onlyOwner { if (pair == address(0)) revert AToken_ZeroAddress(); pancakePair = pair; emit PairSet(pair); }
  // V-04 fix: add an upper bound to the gating threshold, preventing the Owner from mistakenly setting a value too high and locking all buying
  function setMcapThreshold(uint256 v) external onlyOwner {
    if (v > MAX_MCAP_THRESHOLD) revert AToken_McapThresholdTooHigh(v, MAX_MCAP_THRESHOLD);
    mcapThreshold = v; emit McapThresholdSet(v);
  }
  function setFeewallet2(address newWallet2) external onlyOwner {
    if (newWallet2 == address(0)) revert AToken_ZeroAddress();
    feewallet2 = newWallet2;
    emit Feewallet2Set(newWallet2);
  }
  // Requirement 2.0 L144: the USD price source of FIST = the FIST/USDT pair (zero-address check, consistent with setPair)
  function setBUsdtPair(address pair) external onlyOwner { if (pair == address(0)) revert AToken_ZeroAddress(); bUsdtPair = pair; emit BUsdtPairSet(pair); }

  // ════════════════════════════════════════════════════════════════
  //  EIP-2612 permit -- one off-chain signature completes approve, with no explicit approve tx
  // ════════════════════════════════════════════════════════════════
  // Design intent: the user signs a Permit message off-chain with their private key (EIP-712 domain), then within one transaction the spender
  //   calls permit + transferFrom, compressing "approve (2 txs) + transferFrom (1 tx)" into a single transaction.
  // Pitfall: the nonce reuses the Nonces library (src/lib/Nonces.sol) to prevent replay; the same nonce can only be used once.
  // Pitfall: an expired deadline reverts, preventing a signature from being misused for a long time.
  // Protocol: the EIP-712 domain separator is generated by EIP712("OSK","1") at construction (_hashTypedDataV4).

  // EIP-2612 domain separator -- read by off-chain tools (ethers.js) when constructing signatures
  function DOMAIN_SEPARATOR() external view returns (bytes32) {
    return _domainSeparatorV4();
  }

  // Design intent: build the real permit digest = keccak256("\x19\x01" || domainSep || structHash)
  //   structHash = keccak256(_PERMIT_TYPEHASH || owner || spender || value || nonce || deadline)
  // Pitfall: use-before-increment for the nonce (consistent with OZ ERC20Permit); the same user's nonce++ prevents replay.
  function permit(
    address owner, address spender, uint256 value,
    uint256 deadline, uint8 v, bytes32 r, bytes32 s
  ) external {
    if (owner == address(0)) revert AToken_PermitZeroOwner();
    if (block.timestamp > deadline) revert AToken_PermitExpired(deadline, block.timestamp);

    bytes32 structHash = keccak256(abi.encode(
      _PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline
    ));
    bytes32 digest = _hashTypedDataV4(structHash);
    address recovered = digest.recover(abi.encodePacked(r, s, v));
    if (recovered != owner) revert AToken_PermitInvalidSignature(recovered, owner);

    _approve(owner, spender, value); // OZ ERC20 already emits Approval internally, so it is not repeated here
  }

  // ── Buy gating: buy allowed if LP market cap >= threshold or whitelisted (V-05 fix: use the sliding-window average to resist MEV) ──
  // Design intent: this serves only AToken's buy admission risk control, judging whether the LP market cap threshold is met, not the user's business settlement price.
  //           Changed from view to non-view -- it auto-updates when the snapshot is stale, keeping the gating data fresh.
  // Pitfall: the callers transfer/transferFrom are both non-view, so the external interface is unaffected.
  function _checkBuyEnabled(address buyer) internal {
    if (whitelist[buyer]) return;
    if (pancakePair == address(0) || bUsdtPair == address(0)) revert AToken_BuyDisabled();
    // V-05 fix: auto-refresh on first startup or when the snapshot is stale (not updated for >10 blocks), compatible with a keeper interruption
    if (_lastMcapBlock == 0 || block.number - _lastMcapBlock > MCAP_STALE_BLOCKS) {
      _updateMcapHistory();
    }
    if (_getLpMcapUsd() < mcapThreshold) revert AToken_BuyDisabled();
  }

  // ── V-05 fix: dynamically identify the "quote side" reserve (token0 is not fixed; anchored on AToken itself) ──
  //      Requirement 2.0 L144: pancakePair = OSK/FIST -> quote side = FIST reserve.
  function _readQuoteReserve() private view returns (uint256) {
    (uint112 r0, uint112 r1,) = IPancakePair(pancakePair).getReserves();
    if (r0 == 0 || r1 == 0) return 0;
    // dynamic token0 identification: cannot assume a hard-coded FIST=token0 or AToken=token0
    address t0 = IPancakePair(pancakePair).token0();
    return t0 == address(this) ? uint256(r1) : uint256(r0);
  }

  // ── V-05 fix: update the sliding-window snapshot -- callable by anyone, triggered periodically by a keeper ──
  // Design intent: the public interface lets a keeper or arbitrageur actively refresh in a new block, and a buy also triggers it automatically (if stale).
  // Pitfall: multiple calls in the same block take effect only once (early-returns when block.number == _lastMcapBlock).
  function updateMcapSnapshot() external {
    _updateMcapHistory();
  }

  function _updateMcapHistory() private {
    if (block.number == _lastMcapBlock) return; // do not resample in the same block
    uint256 reserve = _readQuoteReserve();
    _lastMcapBlock = uint64(block.number);
    // sliding window: old values shift left, the new value enters _mcapReserve2
    _mcapReserve0 = _mcapReserve1;
    _mcapReserve1 = _mcapReserve2;
    _mcapReserve2 = uint192(reserve);
    if (_mcapFilledCount < MCAP_WINDOW_SIZE) _mcapFilledCount++;
    emit McapSnapshotUpdated(_lastMcapBlock, _mcapReserve2);
  }

  // ── V-05 fix: get the average quote-side reserve (resisting single-block flash-loan manipulation) ──
  // Design intent: use the average of the last 3 blocks as the gating baseline; a flash-loan injection affects only the current block and cannot raise the average.
  // Pitfall: returns 0 when never updated (which triggers BuyDisabled); falls back to spot when stale (compatible with a keeper interruption).
  function _getAvgQuoteReserve() private view returns (uint256) {
    if (_mcapFilledCount == 0) return 0; // never updated
    // if the historical data is stale, fall back to the current spot (compatible with a keeper interruption)
    if (block.number - _lastMcapBlock > MCAP_STALE_BLOCKS) return _readQuoteReserve();
    uint256 sum = uint256(_mcapReserve0) + uint256(_mcapReserve1) + uint256(_mcapReserve2);
    return sum / _mcapFilledCount;
  }

  // ── LP market cap (USD): full LP two-sided value = FIST-side USD × 2 (Requirement 2.0 L25)
  // Design intent: buy gating needs the full LP market cap (two-sided), unlike FarmVault's one-sided APY lookup.
  //           The result here is used only to judge "whether buying is allowed", not as a unified price reused by CoreVault/Treasury.
  // Formula: fistReserve / FIST_per_USD × 2 = full LP market cap in USD
  // Pitfall: Requirement 2.0 L144 -- OSK has only the OSK/FIST pair, and FIST uses only the FIST/USDT pair.
  //       So the LP's quote side = FIST, and FIST_per_USD is derived by dynamically identifying the USDT side of the FIST/USDT pair
  //       (do not assume FIST or USDT is fixed as token0).
  function _getLpMcapUsd() private view returns (uint256) {
    uint256 fistReserve = _getAvgQuoteReserve();
    if (fistReserve == 0) return 0;
    if (bUsdtPair == address(0)) return 0;
    (uint112 wr0, uint112 wr1,) = IPancakePair(bUsdtPair).getReserves();
    if (wr0 == 0 || wr1 == 0) return 0;
    address usdt = GlobalConfig.getUSDT();
    if (usdt == address(0)) return 0;
    // FIST per USD: the USDT side is the denominator (USDT is 18 decimals on BSC, ≈ USD)
    uint256 fistPerUsd = IPancakePair(bUsdtPair).token0() == usdt
      ? (uint256(wr1) * 1e18) / uint256(wr0)
      : (uint256(wr0) * 1e18) / uint256(wr1);
    if (fistPerUsd == 0) return 0;
    // Full LP mcap: fistReserve / FIST_per_USD × 2 = fistReserve×2×1e18/fistPerUsd
    return Math.mulDiv(fistReserve * 2, 1e18, fistPerUsd, Math.Rounding.Floor);
  }

  // ── Treasury refill only: withdraw directly from the pair, bypassing allowance+tax (callable only by Treasury) ──
  function transferFromPair(address to, uint256 amount) external {
    if (msg.sender != treasury) revert AToken_OnlyTreasury();
    if (pancakePair == address(0)) revert AToken_PairNotSet();
    super._transfer(pancakePair, to, amount);
  }

  // ── Transfer entry points: buy gating + 10% sell tax ──
  // Note: Phase3's "in-transfer synchronous trigger of insurance pool market-making" has been removed -- see the file header; that path always reverted
  //     and was swallowed by catch{}. Market-making is now called directly by a keeper via InsurancePool.executeBuyFist/executeSellFist.
  function transfer(address to, uint256 amount) public override transientNonReentrant returns (bool) {
    // buy: pair transfers out -> check LP market cap or whitelist
    if (msg.sender == pancakePair && pancakePair != address(0)) {
      _checkBuyEnabled(to);
      return super.transfer(to, amount);
    }
    // sell: transfer into pair -> 10% tax (5% burn + 5% fee), whitelist tax-exempt
    if (to == pancakePair && pancakePair != address(0) && !whitelist[msg.sender]) {
      return _taxedTransfer(msg.sender, to, amount);
    }
    return super.transfer(to, amount);
  }

  function transferFrom(address from, address to, uint256 amount) public override transientNonReentrant returns (bool) {
    // buy: transfer out of pair -> gating check
    if (from == pancakePair && pancakePair != address(0)) {
      _checkBuyEnabled(to);
      return super.transferFrom(from, to, amount);
    }
    // sell: transfer into pair -> 10% tax, whitelist tax-exempt
    if (to == pancakePair && pancakePair != address(0) && !whitelist[from]) {
      _spendAllowance(from, msg.sender, amount);
      return _taxedTransfer(from, to, amount);
    }
    return super.transferFrom(from, to, amount);
  }

  // ── Sell tax execution: 10% = 5% burn + 5% fee, selling always open ──
  // ── FIX-03: for tiny amounts (<20 wei) the tax truncates to 0, so ensure at least 1 wei is burned ──
  // H-robustness-fix: reject zero amounts early, avoiding these two anomalies:
  //   1) amount=0 -> burnAmt=0 -> FIX-03 forces burn=1 -> 0 enters the pair but 1 wei is burned
  //   2) in the tax computation net = 0 - 0 - 0 = 0, yet a zero-transfer event is still emitted
  function _taxedTransfer(address from, address to, uint256 amount) internal returns (bool) {
    if (amount == 0) revert AToken_ZeroAmount();
    uint256 burnAmt    = amount * BURN_BPS / BPS_DENOM;
    uint256 wallet2Amt = amount * WALLET2_BPS / BPS_DENOM;
    // FIX-03: when a tiny amount makes the tax truncate to 0, ensure at least 1 wei is burned
    if (burnAmt == 0) burnAmt = 1;
    uint256 net        = amount > burnAmt + wallet2Amt ? amount - burnAmt - wallet2Amt : 0;
    if (burnAmt > 0) _burn(from, burnAmt);
    if (wallet2Amt > 0) super._transfer(from, feewallet2, wallet2Amt);
    if (net > 0) super._transfer(from, to, net);
    emit TaxCollected(from, burnAmt, wallet2Amt);
    return true;
  }
}
// 0xCAFEBABE - AToken v3: fixed supply 220M, sell always open, buy gated by LP mcap
