// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {TransientReentrancyGuard} from "../access/TransientReentrancyGuard.sol";
import {Auth} from "../access/Auth.sol";
import {IAToken} from "../interfaces/IAToken.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IBToken} from "../interfaces/IBToken.sol";
import {IPancakeRouter, IPancakePair} from "../interfaces/IPancake.sol";
import {DexSwapper} from "../lib/DexSwapper.sol";
import {IInsurancePool} from "../interfaces/IInsurancePool.sol";
import {IFISTDAO} from "../interfaces/IFISTDAO.sol";

// ============================================================
//  FILENAME:   Treasury.sol
//  PURPOSE:    Treasury management - 80M A-coin constant/DEX auto-refill/LP management
//  AUDIT RISK: CRITICAL - Treasury layer, directly controls all asset security
//  DUAL-PATH:  Serves both BNB deposit and FIST deposit fund-allocation paths (Requirement 2.0 section 2, 1/2);
//              both paths share the 10% burn / 20% insurance pool / 70% OSK/FIST LP structure, differing only in swap hop count.
//  RATIO:      A/quote ratio sliding window read by the getRatioInfo view (quote = the FIST side of OSK/FIST);
//              the LP execution guard function it used to drive has been removed, so the window is now purely observational.
//  FISTDAO-FEE: Requirement 2.0 section 1 L11 -- FISTDAO buy/sell tax 1.5% (FISTDAO.oskPool wired to this contract)
//              goes through convertFistdaoFeeToOskLp() over the five-hop FISTDAO->BNI->WBNB->USDT->FIST,
//              then reuses _fistHalfToOskLp to split in half and form OSK/FIST LP sent to the insurance pool. Callable by anyone (keeper-driven).
// ============================================================
contract Treasury is Auth, TransientReentrancyGuard {
  using SafeERC20 for IERC20;
  using DexSwapper for IPancakeRouter;

  // Pitfall: this contract uses its **own** REFILL_COOLDOWN (5 minutes), independent of GlobalConfig.REFILL_COOLDOWN;
  //       the GlobalConfig side currently has no reference point, so do not assume the two are linked.
  uint256 public constant TREASURY_TARGET = 80_000_000 * 1e18;
  // Design intent: 80M A-coin is the constant target -- below it the treasury auto-refills from the pair, above it stops. Maintains the treasury liquidity base pool, ensuring reward payout and farmVault redemption have sufficient reserves.
  uint256 public constant REFILL_COOLDOWN = 5 minutes; // Auto-refill cooldown: only once per 5 minutes
  // Pitfall: the 5-minute cooldown prevents MEV bots from repeatedly triggering refill arbitrage and also avoids gas waste.
  /// @dev The **upper bound** on the A-coin drawn from the pair per refill (BP, 1e4 precision).
  /// Design rationale (user-specified): restored to **5%** -- i.e. `aR / 20`, consistent with the original implementation.
  ///   Measured on the mainnet test build: each claim draws 5.996e24 OSK (exactly 5.00% of the reserves).
  /// Pitfall (known side effect, not a defect): a single 5% draw pushes the OSK relative price up by about 5%,
  ///   making `aPerB`/`aPerUsd` jump -> the tier hit drifts accordingly (measured effective tR 252 -> 74 -> 78).
  ///   That side effect has been largely mitigated by the "three-source median" oracle (OracleLib._selectPrice3):
  ///   the median filters out single-point outlier prices, so the tier no longer destabilizes from a single refill.
  /// Pitfall: the bound must be based on the **reserve proportion** rather than an absolute amount -- an absolute amount becomes too large an impact once the reserves shrink.
  uint256 public constant MAX_REFILL_IMPACT_BP = 500; // 5% of pair A reserves per refill
  uint256 public lastRefillTime; // Last refill timestamp

  IAToken public aToken;
  IBToken public bToken;
  IERC20 public wbnb;
  IPancakeRouter public router;
  /// @dev Requirement 2.0 L144: the A-side pair = OSK/FIST (OSK has only this pair).
  ///      Used for refill (_refillFromPair) and the ratio window; the quote side = FIST, no longer WBNB.
  IPancakePair public aPair;

  address public insurancePool;
  address public bPool;
  address public farmVault;
  address public aStaking;

  // ── Requirements doc section 2: external tokens and pairs needed for deposit fund allocation ──
  // Design intent: the pair topology is explicitly wired by the deployer, avoiding hard-coded addresses in the contract:
  //   FISTDAO mother token <- buy BNB->WBNB->BNI->FISTDAO then burn   (FISTDAO/BNI pair)
  //   OSK      <- BNB->WBNB->USDT->OSK                    (OSK/USDT routing)
  //   FIST     <- BNB->WBNB->USDT->FIST                   (only via FIST/USDT, the deepest liquidity)
  //   LP       <- OSK + FIST paired directly               (OSK/FIST pair)
  // Pitfall: when not wired, allocateDeposit reverts directly with Treasury_PathNotConfigured,
  //       never silently trading on a wrong path -- a fund-allocation error costs far more than a failed trade.
  address public fistdao;     // FISTDAO mother token address (burned after buying)
  address public fist;        // FIST token address (forms OSK/FIST LP)
  address public bni;         // BNI token address (the intermediate pair for FISTDAO)
  address public usdt;        // USDT address (intermediate for FIST / OSK)
  /// @dev FIST/USDT pair -- **this pair is not registered with the Pancake factory** (it is actually deployed on FstSwap on mainnet),
  ///      so `PancakeRouter.getAmountsOut`/`swap` cannot route it (the router only knows its own factory's pairs).
  ///      Every swap crossing USDT<->FIST must go through `_pairHop` directly on this pair.
  /// Pitfall: validate the direction when wiring (token0/token1 = one of USDT/FIST) -- a direction mismatch would reverse the swap arguments,
  ///      an unrecoverable fund misallocation.
  address public fistUsdtPair;
  address public oskFistPair; // OSK/FIST pair (LP target + reserve-ratio balancing)
  // Requirements doc section 2: the FIST staking pool address injected with the 2.5% withdrawal tax after buying FIST (i.e. CoreVault)
  // Design intent: FIST staking rewards are redeemed from CoreVault's own bToken balance (_payoutStaking), so the injection target is CoreVault.
  address public fistStakingPool;

  // ── A/quote ratio sliding window (last 3 blocks) ──
  // Design intent: store the A-per-quote ratio of the last 3 distinct blocks (1e18 precision); quote = the FIST side of OSK/FIST.
  // Purpose: for the getRatioInfo view's observation and operational cross-checking only; it does not participate in any fund allocation or LP execution path.
  // Pitfall: uint256 is enough to hold uint112*1e18/uint112 = ratio (at most ~5e33/1 ≈ 5e33).
  uint64  private _lastRatioBlock;
  uint256 private _ratioHistory0; // oldest
  uint256 private _ratioHistory1;
  uint256 private _ratioHistory2; // newest
  uint8   private _ratioFilledCount;

  uint256 internal constant RATIO_WINDOW_SIZE = 3;
  uint256 internal constant RATIO_STALE_BLOCKS = 10;
  uint256 internal constant MAX_DEVIATION_BP  = 1500; // 15%

  event TreasuryRefilled(uint256 amount, uint256 costWbnb);
  event RewardPaid(address indexed to, uint256 amount);
  event SyncFailed(address pair);
  event EmergencyWithdrawn(address indexed token, address indexed to, uint256 amount);
  event EthWithdrawn(address indexed to, uint256 amount);
  // Design intent: redemption funds are paid in BNB (regardless of whether the deposit token was BNB or FIST, redemption is always settled in BNB -- Requirement 2.0 L91)
  event TreasuryPayout(address indexed to, uint256 bnbAmount);
  event InsuranceFundsPulled(address indexed caller, address indexed token, uint256 amount);
  // V21-fix: ratio snapshot updated event
  event RatioSnapshotUpdated(uint64 indexed blockNumber, uint256 ratio);
  // M-7-fix: allocateDeposit entry-level summary event, for indexing and audit traceability
  event DepositAllocated(address indexed user, uint256 bnbAmt, uint256 lpAmt);
  // Requirements doc section 2: 10% of the deposit buys FISTDAO and burns it
  event FistdaoBurned(uint256 fistdaoAmount, uint256 bnbSpent);
  // Requirements doc section 2: 70% of the deposit buys OSK/FIST in halves and forms LP sent to the insurance pool
  event OskFistLpAdded(uint256 oskAmt, uint256 fistAmt, uint256 lpAmt);
  // swap change / LP dust forwarded to the insurance pool (zero retention)
  event DepositExcessForwarded(address indexed token, uint256 amount);
  // Requirements doc section 2: the 2.5% withdrawal tax buys via OSK->USDT->FIST then injects into the FIST staking pool
  event FistInjectedToStakingPool(uint256 oskSpent, uint256 fistInjected);
  // Requirement 2.0 section 2: FIST deposit fund-allocation summary (10% burn / 20% insurance pool / 70% LP)
  event FistDepositAllocated(address indexed user, uint256 fistAmt, uint256 fistdaoBurned, uint256 lpAmt);
  // Requirement 2.0 section 2: 10% of the FIST deposit buys via FIST->USDT->WBNB->BNI->FISTDAO then burns
  event FistdaoBurnedWithFist(uint256 fistdaoAmount, uint256 fistSpent);
  // Requirement 2.0 section 2: 20% of the FIST deposit is transferred to the insurance pool as FIST reserve (redemption reserve + automatic market-making)
  event FistReserveForwarded(address indexed to, uint256 fistAmt);
  // Requirement 2.0 section 3, staking rule 2 (WARNING: client change on 2026-09-26): the 2% fuel fee for FIST staking is **charged in FIST itself** ->
  //   half the FIST is swapped to OSK, the remaining FIST + obtained OSK form OSK/FIST LP -> insurance pool.
  event StakeFistFeeLpAdded(uint256 fistSpent, uint256 oskGot, uint256 lpAmt);
  // WARNING: no longer on the requirements path (after the 2026-09-26 change): the FIST staking fuel fee is now charged in **FIST itself**
  //   (via `injectFistToOskLp`), so the "OSK fuel fee -> form LP" direction has **no caller**.
  //   Kept only for ABI alignment with deployed instances and traceability; it no longer participates in any requirements path.
  event StakeOskFeeLpAdded(uint256 oskSpent, uint256 fistGot, uint256 lpAmt);
  // Requirement 2.0 section 1: FISTDAO buy/sell tax 1.5% -> BNI->WBNB->USDT->FIST -> split in half -> OSK/FIST LP -> insurance pool
  event FistdaoTaxConverted(uint256 fistdaoSpent, uint256 fistGot, uint256 oskGot, uint256 lpAmt);

  // Design intent: the constructor injects all external dependencies (IoC).
  // Pitfall: the zero-address checks cover the core dependencies; _insurancePool/_bPool can be updated via setters;
  //       _wbnb/_router have no setter, so the correct addresses must be passed at deployment.
  constructor(
    address _aToken, address _bToken, address _wbnb,
    address _router, address _insurancePool, address _bPool
  ) Auth() {
    if (_aToken == address(0) || _bToken == address(0) || _wbnb == address(0) || _router == address(0)) revert Treasury_ZeroAddress();
    aToken = IAToken(_aToken);
    bToken = IBToken(_bToken);
    wbnb = IERC20(_wbnb);
    router = IPancakeRouter(_router);
    insurancePool = _insurancePool;
    bPool = _bPool;
  }

  function setFarmVault(address _v) external onlyOwner { if (_v == address(0)) revert Treasury_ZeroAddress(); farmVault = _v; }
  function setAStaking(address _s) external onlyOwner { if (_s == address(0)) revert Treasury_ZeroAddress(); aStaking = _s; }
  function setInsurancePool(address _p) external onlyOwner { if (_p == address(0)) revert Treasury_ZeroAddress(); insurancePool = _p; }
  function setBPool(address _p) external onlyOwner { if (_p == address(0)) revert Treasury_ZeroAddress(); bPool = _p; }
  function setPair(address _pair) external onlyOwner { if (_pair == address(0)) revert Treasury_ZeroAddress(); aPair = IPancakePair(_pair); }

  // ── Requirements doc section 2: deposit allocation path wiring (Owner only) ──
  function setFistdao(address _f) external onlyOwner { if (_f == address(0)) revert Treasury_ZeroAddress(); fistdao = _f; }
  function setFist(address _f) external onlyOwner { if (_f == address(0)) revert Treasury_ZeroAddress(); fist = _f; }
  function setBni(address _b) external onlyOwner { if (_b == address(0)) revert Treasury_ZeroAddress(); bni = _b; }
  function setUsdt(address _u) external onlyOwner { if (_u == address(0)) revert Treasury_ZeroAddress(); usdt = _u; }
  function setOskFistPair(address _p) external onlyOwner { if (_p == address(0)) revert Treasury_ZeroAddress(); oskFistPair = _p; }
  /// @dev Wire the FIST/USDT pair (FstSwap); validate the direction (one of USDT/FIST) -- a direction mismatch is an unrecoverable misallocation.
  function setFistUsdtPair(address _p) external onlyOwner {
    if (_p == address(0)) revert Treasury_ZeroAddress();
    address t0 = IPancakePair(_p).token0();
    address t1 = IPancakePair(_p).token1();
    address u = usdt;
    address f = fist;
    if (u == address(0) || f == address(0)) revert Treasury_PathNotConfigured();
    if (!((t0 == u && t1 == f) || (t0 == f && t1 == u))) revert Treasury_PathNotConfigured();
    fistUsdtPair = _p;
  }
  function setFistStakingPool(address _p) external onlyOwner { if (_p == address(0)) revert Treasury_ZeroAddress(); fistStakingPool = _p; }

  // If below 80M, directly transfer A-coin from pair to refill treasury
  // A-coin reduction in pair -> A-coin price naturally rises, WBNB stays in pair to deepen liquidity
  // Design intent: manually trigger a refill; the 5-minute cooldown prevents frequent operations. Draw A-coin directly from the pair instead of swapping, avoiding slippage loss while naturally pushing the A-coin price up.
  // Pitfall: callable only by Owner; when the cooldown has not elapsed it returns silently without reverting.
  function refillTreasury() external transientNonReentrant onlyOwner {
    if (block.timestamp < lastRefillTime + REFILL_COOLDOWN) return;
    uint256 bal = aToken.balanceOf(address(this));
    if (bal >= TREASURY_TARGET) return;
    // L-001 fix: CEI order -- lastRefillTime is updated before the external call
    lastRefillTime = block.timestamp;
    _refillFromPair(TREASURY_TARGET - bal);
  }

  // Design intent: Requirement 2.0 section 2, "OSK on-chain mining mechanism 1" deposit fund allocation -- 10% buys FISTDAO and burns / 20% insurance pool BNB reserve / 70% forms OSK+FIST LP.
  //   |- 10% = BNB->WBNB->BNI->FISTDAO then burned directly (FISTDAO/BNI pair)
  //   |- 20% = insurance pool multisig address (BNB reserve, redemption reserve + automatic market-making)
  //   |- 70% = split in half: 0.35 buys OSK (WBNB->USDT->OSK), 0.35 buys FIST (WBNB->USDT->FIST)
  //            -> OSK + FIST automatically add LP, LP sent to the insurance pool address (OSK/FIST pair)
  // Pitfall: ratio change history -- requirement 1.0 was 10/30/60, requirement 2.0 explicitly says 10/20/70; 2.0 prevails.
  // Pitfall: the remainder is entirely folded into the LP share, with no Floor truncation -- avoiding wei-level dust lingering in the treasury long-term.
  // Pitfall: callable only by FarmVault, preventing any address from depositing directly and bypassing FarmVault's staking logic.
  function allocateDeposit(address user, uint256 bnbAmt, uint256 slippageBp)
    external payable transientNonReentrant returns (uint256 lpAmt)
  {
    if (msg.sender != farmVault) revert Treasury_Unauthorized();
    if (bnbAmt == 0) revert Treasury_ZeroAmount();
    if (msg.value != bnbAmt) revert Treasury_ValueMismatch();
    if (slippageBp == 0 || slippageBp > 9900) revert Treasury_BadSlippage(slippageBp);
    uint256 deadline = block.timestamp + 30 minutes;

    uint256 burnBnb = Math.mulDiv(bnbAmt, 10, 100, Math.Rounding.Floor); // 10% -> buy FISTDAO and burn
    uint256 insBnb  = Math.mulDiv(bnbAmt, 20, 100, Math.Rounding.Floor); // 20% -> insurance pool
    uint256 lpBnb   = bnbAmt - burnBnb - insBnb;                         // 70% + remainder -> LP

    // 10% -> BNB->WBNB->BNI->FISTDAO, burn after buying
    _buyAndBurnFistdao(burnBnb, slippageBp, deadline);

    // 20% -> insurance pool BNB reserve (redemption reserve + automatic market-making yield)
    if (insBnb > 0) {
      (bool insSuccess,) = insurancePool.call{value: insBnb}("");
      if (!insSuccess) revert Treasury_TransferFailed();
    }

    // 70% -> buy OSK / FIST in halves, form OSK/FIST LP sent to the insurance pool
    uint256 halfLp = lpBnb / 2;
    lpAmt = _buyOskFistAndAddLp(halfLp, lpBnb - halfLp, slippageBp, deadline);

    emit DepositAllocated(user, bnbAmt, lpAmt);
  }

  // ════════════════════════════════════════════════════════════
  //  Requirement 2.0 section 2, "FIST on-chain mining mechanism 2": FIST deposit fund allocation
  // ════════════════════════════════════════════════════════════

  /// @notice Fund allocation for a FIST deposit (isomorphic to the BNB channel, differing only in the settlement token and swap path)
  /// @dev Requirement 2.0 section 2:
  ///   |- 10% FIST = FIST->USDT->WBNB->BNI->FISTDAO then burned directly after buying
  ///   |- 20% FIST = insurance pool multisig address (FIST reserve, redemption reserve + automatic market-making)
  ///   |- 70% FIST = split in half: 35% FIST->OSK (direct on the OSK/FIST pair), 35% FIST retained
  ///                -> OSK + FIST automatically add LP, LP sent to the insurance pool address
  /// Design intent: the caller (CoreVault) first safeTransfers the FIST into this contract, then calls this function;
  ///           everything is measured by the "actual received balance delta", never trusting the router's quote array.
  /// Pitfall: reverts when not wired (any of usdt/fist/fistdao/bni/oskFistPair is 0),
  ///       never silently trading on a wrong path -- a fund-allocation error costs far more than a failed trade.
  /// Pitfall: callable only by FarmVault, preventing any address from bypassing CoreVault's position and referral logic.
  function allocateFistDeposit(address user, uint256 fistAmt, uint256 slippageBp)
    external transientNonReentrant returns (uint256 lpAmt)
  {
    if (msg.sender != farmVault) revert Treasury_Unauthorized();
    if (fistAmt == 0) revert Treasury_ZeroAmount();
    if (slippageBp == 0 || slippageBp > 9900) revert Treasury_BadSlippage(slippageBp);
    address f = fist;
    // Pitfall: FIST must be validated as wired before calling balanceOf -- calling address(0) reverts with empty data,
    //       so the caller would get an uninformative revert instead of the locatable Treasury_PathNotConfigured.
    if (f == address(0)) revert Treasury_PathNotConfigured();
    uint256 deadline = block.timestamp + 30 minutes;

    // Pitfall: the baseline is the balance "before this transfer" (= current balance - fistAmt).
    //        If the post-transfer balance were used as the baseline, swap change and LP dust could not be swept and would linger in the treasury long-term.
    uint256 fistBal = IERC20(f).balanceOf(address(this));
    if (fistBal < fistAmt) revert Treasury_InsufficientTransfer(fistAmt, fistBal);
    uint256 fistBaseline = fistBal - fistAmt;
    uint256 oskBaseline = IERC20(address(aToken)).balanceOf(address(this));

    uint256 burnAmt = Math.mulDiv(fistAmt, 10, 100, Math.Rounding.Floor); // 10% -> buy FISTDAO and burn
    uint256 insAmt  = Math.mulDiv(fistAmt, 20, 100, Math.Rounding.Floor); // 20% -> insurance pool FIST reserve
    uint256 lpAmtIn = fistAmt - burnAmt - insAmt;                         // 70% + remainder -> LP

    // 10% -> FIST->USDT->WBNB->BNI->FISTDAO, burn after buying
    uint256 burned = _burnFistdaoWithFist(burnAmt, slippageBp, deadline);

    // 20% -> insurance pool FIST reserve (redemption reserve + automatic market-making)
    if (insAmt > 0) {
      IERC20(fist).safeTransfer(insurancePool, insAmt);
      emit FistReserveForwarded(insurancePool, insAmt);
    }

    // 70% -> split in half: half the FIST swapped directly for OSK, the other half retained -> form OSK/FIST LP
    uint256 halfLp = lpAmtIn / 2;
    lpAmt = _buyOskWithFistAndAddLp(
      halfLp, lpAmtIn - halfLp, slippageBp, deadline, oskBaseline, fistBaseline
    );

    emit FistDepositAllocated(user, fistAmt, burned, lpAmt);
  }

  /// @dev 10% -> FIST->USDT->WBNB->BNI->FISTDAO, burned immediately after buying (the path explicitly specified in Requirement 2.0 section 2)
  /// Pitfall: FIST->USDT must be **direct on the pair** (that pair is on FstSwap, which PancakeRouter cannot route);
  ///   the latter half USDT->WBNB->BNI->FISTDAO is all on Pancake, so it goes through the router.
  function _burnFistdaoWithFist(uint256 fistAmt, uint256 slippageBp, uint256 deadline)
    private returns (uint256 burned)
  {
    if (fistAmt == 0) return 0;
    address f = fist;
    address u = usdt;
    address b = bni;
    address fd = fistdao;
    if (f == address(0) || u == address(0) || b == address(0) || fd == address(0)) {
      revert Treasury_PathNotConfigured();
    }
    // first half: FIST->USDT direct on the pair; second half: USDT->WBNB->BNI->FISTDAO via the router
    address[] memory path = new address[](4);
    path[0] = u;
    path[1] = router.WETH();
    path[2] = b;
    path[3] = fd;
    burned = _pairHopToUsdtThenRouter(fistAmt, path, slippageBp, deadline);
    if (burned > 0) IFISTDAO(fd).burn(burned);
    emit FistdaoBurnedWithFist(burned, fistAmt);
  }

  /// @dev 70% split in half: half the FIST swapped for OSK (direct path, Requirement 2.0 section 2), the other half retained -> form LP
  ///      Pitfall: the baseline is passed by the caller as the balance "before this transfer", used to sweep swap change and LP dust;
  ///            if the post-transfer balance were used as the baseline, the remainder would linger in the treasury long-term.
  function _buyOskWithFistAndAddLp(
    uint256 fistToSwap, uint256 fistToLp,
    uint256 slippageBp, uint256 deadline,
    uint256 oskBaseline, uint256 fistBaseline
  ) private returns (uint256 lpAmt) {
    address f = fist;
    address osk = address(aToken);
    if (f == address(0)) revert Treasury_PathNotConfigured();

    // Requirement 2.0 section 2 path: fist->OSK (direct on the OSK/FIST pair)
    address[] memory path = new address[](2);
    path[0] = f;
    path[1] = osk;
    uint256 oskGot = _swapExactTokensForTokens(fistToSwap, path, slippageBp, deadline);
    lpAmt = _addOskFistLp(oskGot, fistToLp, slippageBp, deadline);

    // the remainder (swap change + addLiquidity dust) is all forwarded to the insurance pool, zero retention
    _sweepExcess(osk, oskBaseline);
    _sweepExcess(f, fistBaseline);
  }

  // ════════════════════════════════════════════════════════════
  //  Requirements doc section 2: deposit allocation execution primitives
  // ════════════════════════════════════════════════════════════

  /// @dev 10% -> BNB->WBNB->BNI->FISTDAO, burned immediately after buying (FISTDAO/BNI pair)
  ///      Pitfall: reverts directly when the path is not wired, never silently trading on a wrong path -- a fund-allocation error costs far more than a failed trade.
  function _buyAndBurnFistdao(uint256 bnbAmt, uint256 slippageBp, uint256 deadline) private {
    if (bnbAmt == 0) return;
    address f = fistdao;
    address b = bni;
    if (f == address(0) || b == address(0)) revert Treasury_PathNotConfigured();
    address[] memory path = new address[](3);
    path[0] = router.WETH();
    path[1] = b;
    path[2] = f;
    uint256 got = _swapExactEthForTokens(bnbAmt, path, slippageBp, deadline);
    if (got > 0) IFISTDAO(f).burn(got);
    emit FistdaoBurned(got, bnbAmt);
  }

  /// @dev 70% buys OSK / FIST in halves, forming OSK/FIST LP sent to the insurance pool
  /// Pitfall: the two legs' swap paths must match the pair topology stated in Requirement 2.0 L144 --
  ///   - FIST leg: WBNB->USDT->FIST (via the FIST/USDT pair, the deepest liquidity)
  ///   - OSK  leg: WBNB->USDT->FIST->OSK -- OSK has only the OSK/FIST pair, and **no direct USDT/OSK pair exists**,
  ///     so after WBNB->USDT it must first obtain FIST, then swap out OSK via OSK/FIST.
  ///     (The original implementation used three hops WBNB->USDT->OSK, which reverts on the real chain due to the missing pair.)
  function _buyOskFistAndAddLp(uint256 oskBnb, uint256 fistBnb, uint256 slippageBp, uint256 deadline)
    private returns (uint256 lpAmt)
  {
    address u = usdt;
    address f = fist;
    address osk = address(aToken);
    if (u == address(0) || f == address(0)) revert Treasury_PathNotConfigured();

    uint256 oskBefore = IERC20(osk).balanceOf(address(this));
    uint256 fistBefore = IERC20(f).balanceOf(address(this));

    // FIST leg: WBNB->USDT via the router + USDT->FIST **direct on the pair** (that pair is on FstSwap)
    uint256 fistGot = _ethToUsdtThenFist(fistBnb, slippageBp, deadline);
    // OSK leg: after obtaining FIST as above, swap out OSK via OSK/FIST (Pancake)
    uint256 oskGot;
    {
      uint256 fistForOsk = _ethToUsdtThenFist(oskBnb, slippageBp, deadline);
      if (fistForOsk > 0) {
        address[] memory p = new address[](2);
        p[0] = f;
        p[1] = osk;
        oskGot = _swapExactTokensForTokens(fistForOsk, p, slippageBp, deadline);
      }
    }
    lpAmt = _addOskFistLp(oskGot, fistGot, slippageBp, deadline);

    // the remainder (swap change + addLiquidity dust) is all forwarded to the insurance pool, zero retention
    _sweepExcess(osk, oskBefore);
    _sweepExcess(f, fistBefore);
  }

  /// @dev ETH->token explicit-path swap
  /// Pitfall: the return value is measured by the "actual balance delta", never trusting the router's quote array --
  ///   a token with a transfer tax makes amounts[last] exceed the actual received amount, and approving/burning based on it would revert for insufficient balance.
  /// Pitfall (severe): the **tax-token-friendly** variant `swapExactETHForTokensSupportingFeeOnTransferTokens` must be used --
  ///   measured on mainnet, **BNI has a 2% transfer tax**, and this path's intermediate token is exactly BNI (`WBNB->BNI->FISTDAO`).
  ///   The exact-input variant would fail the next hop pair's K check because the intermediate token receives less, reverting the whole call with `Pancake: K`
  ///   (measured: for a 0.001 BNB deposit the quote was 152.21e18 BNI while the actual receipt was 149.17e18, a 2% difference).
  /// Pitfall: `amountOutMin` is still derived from the quote and keeps the slippage tolerance -- the tax-friendly variant only changes the "intermediate hop's input policy",
  ///   and the final output must still meet the lower bound, so protection is not weakened.
  function _swapExactEthForTokens(uint256 bnbAmt, address[] memory path, uint256 slippageBp, uint256 deadline)
    private returns (uint256 amountOut)
  {
    if (bnbAmt == 0) return 0;
    address tokenOut = path[path.length - 1];
    uint256[] memory amounts = router.getAmountsOut(bnbAmt, path);
    // Pitfall: the quote includes the intermediate token's pre-tax amount, while the post-tax receipt is lower -> the output lower bound must be additionally relaxed for tax consumption.
    //   Budgeted tax consumption: at worst 3% per intermediate hop (BNI measured at 2%), so relax by the number of intermediate hops.
    uint256 hops = path.length > 2 ? path.length - 2 : 0;
    uint256 taxAllowance = 10000 - (hops * 300);
    uint256 quotedOut = Math.mulDiv(amounts[amounts.length - 1], taxAllowance, 10000, Math.Rounding.Floor);
    uint256 minOut = Math.mulDiv(quotedOut, 10000 - slippageBp, 10000, Math.Rounding.Floor);
    if (minOut == 0) revert Treasury_ZeroAmount();
    uint256 balBefore = IERC20(tokenOut).balanceOf(address(this));
    router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: bnbAmt}(minOut, path, address(this), deadline);
    amountOut = IERC20(tokenOut).balanceOf(address(this)) - balBefore;
  }

  // ════════════════════════════════════════════════════════════
  //  FIST/USDT direct pair swap (this pair is not registered with the Pancake factory)
  // ════════════════════════════════════════════════════════════
  // Design intent: the mainnet FIST/USDT pair is deployed on FstSwap, **not on the Pancake factory** --
  //   `PancakeRouter.getAmountsOut` fails on a path containing this pair because `factory.getPair` returns 0.
  //   So every swap crossing USDT<->FIST must be direct on the pair (calling its `swap`), not through the router.
  // Implementation basis: the same verified pattern as jiedian's FistSwapper._usdtToFist --
  //   (1) read reserves -> (2) constant-product quote (including the 0.3% fee) -> (3) slippage threshold ->
  //   (4) transfer in tokenIn -> (5) call pair.swap -> (6) verify the output by balance delta.
  // Pitfall: UniswapV2 hard-requires `amountOut < reserveOut`, so reject explicitly in advance (otherwise it falls into the pair's opaque revert).
  // Pitfall: verify the output by "balance delta", never trusting the quote -- this catches abnormal implementations such as token transfer taxes.
  // Pitfall: the pair's K check rejects insufficient input, forming two-way insurance with our balance verification.

  /// @notice Direct FIST/USDT pair swap (tokenIn/tokenOut must be the two ends of this pair)
  /// @dev Supports only the FIST<->USDT directions; other combinations revert (preventing misuse on other pairs).
  function _pairHop(address tokenIn, uint256 amountIn, uint256 slippageBp) private returns (uint256 amountOut) {
    if (amountIn == 0) return 0;
    address pair = fistUsdtPair;
    if (pair == address(0)) revert Treasury_PathNotConfigured();
    address u = usdt;
    address f = fist;
    if (u == address(0) || f == address(0)) revert Treasury_PathNotConfigured();
    if (!((tokenIn == f) || (tokenIn == u))) revert Treasury_PathNotConfigured();

    bool inIsToken0 = IPancakePair(pair).token0() == tokenIn;
    (uint112 r0, uint112 r1,) = IPancakePair(pair).getReserves();
    (uint256 rIn, uint256 rOut) = inIsToken0 ? (uint256(r0), uint256(r1)) : (uint256(r1), uint256(r0));
    if (rIn == 0 || rOut == 0) revert Treasury_ZeroAmount();

    // constant product (0.3% fee = 997/1000, using 9970/10000 to stay consistent with the project's policy)
    uint256 amountInWithFee = amountIn * 9970;
    uint256 quoted = (amountInWithFee * rOut) / (rIn * 10000 + amountInWithFee);
    if (quoted == 0 || quoted >= rOut) revert Treasury_ZeroAmount();
    uint256 minOut = Math.mulDiv(quoted, 10000 - slippageBp, 10000, Math.Rounding.Floor);
    if (minOut == 0) revert Treasury_ZeroAmount();

    address tokenOut = inIsToken0 ? IPancakePair(pair).token1() : IPancakePair(pair).token0();
    uint256 balBefore = IERC20(tokenOut).balanceOf(address(this));
    IERC20(tokenIn).safeTransfer(pair, amountIn);
    IPancakePair(pair).swap(inIsToken0 ? 0 : quoted, inIsToken0 ? quoted : 0, address(this), "");
    amountOut = IERC20(tokenOut).balanceOf(address(this)) - balBefore;
    if (amountOut < minOut) revert Treasury_ZeroAmount();
  }

  /// @dev Swap to USDT via the router, then swap out FIST directly on the pair.
  ///      Use: all "BNB/other -> USDT -> FIST" paths -- the first half goes through Pancake (WBNB/USDT is on Pancake),
  ///      and the last segment USDT->FIST must be direct (that pair is on FstSwap).
  function _routerToUsdtThenFist(uint256 amountIn, address[] memory routerPathToUsdt, uint256 slippageBp, uint256 deadline)
    private returns (uint256 fistOut)
  {
    uint256 usdtGot = _swapExactTokensForTokens(amountIn, routerPathToUsdt, slippageBp, deadline);
    if (usdtGot == 0) return 0;
    fistOut = _pairHop(usdt, usdtGot, slippageBp);
  }

  /// @dev BNB->USDT (via router) -> FIST (direct on pair).
  ///      Use: both legs of the 70% of a BNB deposit -- mainnet WBNB/USDT is on Pancake while FIST/USDT is on FstSwap,
  ///      so a hybrid route of "first half via router + last segment direct on pair" is required.
  function _ethToUsdtThenFist(uint256 bnbAmt, uint256 slippageBp, uint256 deadline)
    private returns (uint256 fistOut)
  {
    if (bnbAmt == 0) return 0;
    address[] memory path = new address[](2);
    path[0] = router.WETH();
    path[1] = usdt;
    uint256 usdtGot = _swapExactEthForTokens(bnbAmt, path, slippageBp, deadline);
    if (usdtGot == 0) return 0;
    fistOut = _pairHop(usdt, usdtGot, slippageBp);
  }

  /// @dev Swap out USDT directly on the pair, then swap to the target token via the router.
  ///      Use: all "FIST -> USDT -> other" paths (e.g. the FISTDAO burn leg of a FIST deposit).
  function _pairHopToUsdtThenRouter(uint256 fistAmt, address[] memory routerPathFromUsdt, uint256 slippageBp, uint256 deadline)
    private returns (uint256 amountOut)
  {
    uint256 usdtGot = _pairHop(fist, fistAmt, slippageBp);
    if (usdtGot == 0) return 0;
    amountOut = _swapExactTokensForTokens(usdtGot, routerPathFromUsdt, slippageBp, deadline);
  }

  /// @dev Build the explicit path WBNB->USDT->tokenOut
  ///      Use: the FIST leg -- WBNB->USDT->FIST (via the mainnet FIST/USDT pair).
  function _pathViaUsdt(address u, address tokenOut) private view returns (address[] memory path) {
    path = new address[](3);
    path[0] = router.WETH();
    path[1] = u;
    path[2] = tokenOut;
  }

  /// @dev Build the explicit path WBNB->USDT->FIST->tokenOut
  ///      Use: the OSK leg -- under Requirement 2.0 L144, OSK has only the OSK/FIST pair,
  ///            no direct USDT/OSK pair exists, so it must route through FIST to swap out OSK.
  function _pathViaUsdtFist(address u, address f, address tokenOut) private view returns (address[] memory path) {
    path = new address[](4);
    path[0] = router.WETH();
    path[1] = u;
    path[2] = f;
    path[3] = tokenOut;
  }

  /// @dev LP deposit plan (balanced amounts + minimum accepted amounts)
  ///      Returned as a struct rather than 4 separate values -- reduces stack usage, letting this file
  ///      compile under forge coverage (optimizer off) (the original multiple return values triggered stack-too-deep).
  struct LpPlan {
    uint256 aUse;
    uint256 bUse;
    uint256 minA;
    uint256 minB;
  }

  /// @dev Add LP after balancing by the OSK/FIST pair's live reserve ratio; LP is sent directly to the insurance pool.
  ///      Balancing purpose: get both tokens into the pool as fully as possible, reducing dust from a one-sided remainder.
  /// Pitfall: token addresses are read from storage (not occupying argument stack slots), and balancing and minimum-amount computation are centralized in _lpPlan.
  function _addOskFistLp(uint256 oskAmt, uint256 fistAmt, uint256 slippageBp, uint256 deadline)
    private returns (uint256 lpAmt)
  {
    if (oskAmt == 0 || fistAmt == 0) return 0;
    address pair = oskFistPair;
    if (pair == address(0)) revert Treasury_PathNotConfigured();
    address osk = address(aToken);
    address f = fist;
    if (f == address(0)) revert Treasury_PathNotConfigured();

    LpPlan memory plan = _lpPlan(pair, osk, oskAmt, fistAmt, slippageBp);
    IERC20(osk).forceApprove(address(router), plan.aUse);
    IERC20(f).forceApprove(address(router), plan.bUse);
    lpAmt = _doAddLiquidity(osk, f, plan.aUse, plan.bUse, plan.minA, plan.minB, deadline);
  }

  /// @dev Only performs addLiquidity + emits the event (arguments already balanced).
  ///      Extracted separately: an 8-argument external call is too stack-deep under forge coverage (optimizer off),
  ///      and isolating it into a minimal context lets it compile without affecting the production bytecode's semantics.
  function _doAddLiquidity(address osk, address f, uint256 aUse, uint256 bUse,
    uint256 minA, uint256 minB, uint256 deadline) private returns (uint256 lpAmt)
  {
    uint256 usedA;
    uint256 usedB;
    (usedA, usedB, lpAmt) = router.addLiquidity(osk, f, aUse, bUse, minA, minB, insurancePool, deadline);
    emit OskFistLpAdded(usedA, usedB, lpAmt);
  }

  /// @dev Compute the balanced deposit amounts and minimum accepted amounts (by the pair's reserve ratio)
  ///      Balancing purpose: get both tokens into the pool as fully as possible, reducing dust from a one-sided remainder.
  function _lpPlan(address pair, address osk, uint256 oskAmt, uint256 fistAmt, uint256 slippageBp)
    private view returns (LpPlan memory plan)
  {
    plan.aUse = oskAmt;
    plan.bUse = fistAmt;
    (uint112 r0, uint112 r1,) = IPancakePair(pair).getReserves();
    address t0 = IPancakePair(pair).token0();
    uint256 rOsk  = t0 == osk ? uint256(r0) : uint256(r1);
    uint256 rFist = t0 == osk ? uint256(r1) : uint256(r0);
    if (rOsk > 0 && rFist > 0) {
      uint256 bNeeded = Math.mulDiv(plan.aUse, rFist, rOsk, Math.Rounding.Floor);
      if (bNeeded > plan.bUse) plan.aUse = Math.mulDiv(plan.bUse, rOsk, rFist, Math.Rounding.Floor);
      else plan.bUse = bNeeded;
    }
    plan.minA = Math.mulDiv(plan.aUse, 10000 - slippageBp, 10000, Math.Rounding.Floor);
    plan.minB = Math.mulDiv(plan.bUse, 10000 - slippageBp, 10000, Math.Rounding.Floor);
  }

  /// @dev Forward the entire balance delta relative to baseline to the insurance pool (swap change / LP dust)
  ///      Pitfall: sweep by the baseline delta rather than the "full balance" -- the Treasury itself holds the OSK treasury reserve,
  ///            and a full sweep would wrongly swallow the 80 million reserve.
  function _sweepExcess(address token, uint256 baseline) private {
    uint256 bal = IERC20(token).balanceOf(address(this));
    if (bal <= baseline) return;
    uint256 excess = bal - baseline;
    IERC20(token).safeTransfer(insurancePool, excess);
    emit DepositExcessForwarded(token, excess);
  }

  // ════════════════════════════════════════════════════════════
  //  Requirements doc section 2: the 2.5% withdrawal tax buys FIST and injects it into the FIST staking pool
  // ════════════════════════════════════════════════════════════

  /// @notice Swap oskAmt OSK held by the treasury into FIST, and inject the FIST into the FIST staking pool
  /// @dev Path: OSK -> FIST **direct two hops** (the OSK/FIST pair already exists, no need to route via USDT).
  ///      Caller: CoreVault (the 2.5% withdrawal tax drawn at farming claim time).
  /// Pitfall: must be direct rather than OSK->USDT->FIST -- going via USDT pays an extra fee and introduces extra slippage;
  ///       and Requirement 2.0 L144 states OSK has only the OSK/FIST pair, no USDT/OSK pair exists,
  ///       so the original three-hop path would revert directly on the real chain due to the missing pair.
  /// Pitfall: measure FIST by the "actual received delta", never trusting the router's quote array -- if FIST has a transfer tax,
  ///       the quote would exceed the actual receipt, and transferring based on it would revert for insufficient balance.
  /// Pitfall: OSK always completes the swap while staying in the Treasury, never held by an intermediate contract, so assets are not lost on failure.
  /// Pitfall: reverts when not wired (oskFistPair/fist/fistStakingPool), never silently trading on a wrong path.
  function swapOskToFistAndInject(uint256 oskAmt, uint256 slippageBp)
    external transientNonReentrant returns (uint256 fistInjected)
  {
    if (msg.sender != farmVault) revert Treasury_Unauthorized();
    if (oskAmt == 0) return 0;
    if (slippageBp == 0 || slippageBp > 9900) revert Treasury_BadSlippage(slippageBp);
    address f = fist;
    address pool = fistStakingPool;
    if (oskFistPair == address(0) || f == address(0) || pool == address(0)) revert Treasury_PathNotConfigured();

    uint256 oskBal = aToken.balanceOf(address(this));
    if (oskAmt > oskBal) oskAmt = oskBal; // fallback: do not exceed the treasury's actual holdings
    if (oskAmt == 0) return 0;

    // direct OSK/FIST (Requirement 2.0 L144: OSK has only this pair)
    address[] memory path = new address[](2);
    path[0] = address(aToken);
    path[1] = f;
    fistInjected = _swapExactTokensForTokens(oskAmt, path, slippageBp, block.timestamp + 30 minutes);

    if (fistInjected > 0) {
      IERC20(f).safeTransfer(pool, fistInjected);
      emit FistInjectedToStakingPool(oskAmt, fistInjected);
    }
  }

  // ════════════════════════════════════════════════════════════
  //  FIST -> OSK/FIST LP base pool (Requirement 2.0 section 3 rule 2 landing point, enabled after the 2026-09-26 change)
  // ════════════════════════════════════════════════════════════

  /// @notice Split FIST in half: 1% swapped to OSK + 1% FIST retained -> form OSK/FIST LP sent to the insurance pool
  /// @dev **The landing point after the client change on 2026-09-26**: the 2% fuel fee for FIST staking is now charged in **FIST itself**,
  ///      so this function becomes that fuel fee's landing path (the original `injectOskToOskFistLp` direction is thereby disabled).
  ///      Caller: `CoreVault` (`stakeB` in `Contracts/CoreVaultStaking.sol` = FIST staking).
  /// Design intent: the fuel fee is first transferred into this contract, which completes the swap + addLiquidity; LP goes to the insurance pool,
  ///           so CoreVault need not hold a router dependency.
  /// Pitfall: measure OSK by the "actual received delta", never trusting the router's quote array -- a token with a transfer tax makes the quote exceed the actual receipt.
  /// Pitfall: reverts when not wired (fist/oskFistPair), never silently trading on a wrong path.
  function injectFistToOskLp(uint256 fistAmt, uint256 slippageBp)
    external transientNonReentrant returns (uint256 lpAmt)
  {
    if (msg.sender != farmVault) revert Treasury_Unauthorized();
    if (fistAmt == 0) return 0;
    if (slippageBp == 0 || slippageBp > 9900) revert Treasury_BadSlippage(slippageBp);
    address f = fist;
    if (f == address(0) || oskFistPair == address(0)) revert Treasury_PathNotConfigured();

    uint256 oskGot;
    (lpAmt, oskGot) = _fistHalfToOskLp(fistAmt, slippageBp);
    emit StakeFistFeeLpAdded(fistAmt, oskGot, lpAmt);
  }

  /// @dev The **shared kernel** for splitting FIST in half into OSK/FIST LP: half the FIST buys OSK directly via OSK/FIST,
  ///      and forms LP with the other half of the FIST; LP is sent directly to the insurance pool. Returns (lpAmt, oskGot).
  /// Pitfall: this function **contains no permission check** -- the callers (injectFistToOskLp is farmVault-only;
  ///   convertFistdaoFeeToOskLp is callable by anyone) each handle that, avoiding the permission semantics being baked into the kernel.
  /// Pitfall: the baseline is the balance "before this operation", otherwise swap change and LP dust cannot be swept,
  ///   and the Treasury's own FIST/OSK reserves would be wrongly swallowed.
  function _fistHalfToOskLp(uint256 fistAmt, uint256 slippageBp)
    private returns (uint256 lpAmt, uint256 oskGot)
  {
    address f = fist;
    address osk = address(aToken);
    uint256 half = fistAmt / 2;
    uint256 fistForLp = fistAmt - half; // the 1% side's retained FIST goes directly into LP
    uint256 fistBal = IERC20(f).balanceOf(address(this));
    if (fistBal < fistAmt) revert Treasury_InsufficientTransfer(fistAmt, fistBal);
    uint256 fistBaseline = fistBal - fistAmt;
    uint256 oskBaseline = IERC20(osk).balanceOf(address(this));

    // 1% side FIST -> OSK (direct on the OSK/FIST pair, consistent with the Requirement 2.0 section 2 deposit path policy)
    address[] memory path = new address[](2);
    path[0] = f;
    path[1] = osk;
    oskGot = _swapExactTokensForTokens(half, path, slippageBp, block.timestamp + 30 minutes);
    lpAmt = _addOskFistLp(oskGot, fistForLp, slippageBp, block.timestamp + 30 minutes);

    // the remainder (swap change + LP dust) is forwarded to the insurance pool, zero retention
    _sweepExcess(osk, oskBaseline);
    _sweepExcess(f, fistBaseline);
  }

  // ════════════════════════════════════════════════════════════
  //  Requirement 2.0 section 1: FISTDAO buy/sell tax 1.5% -> OSK/FIST LP -> insurance pool
  // ════════════════════════════════════════════════════════════

  /// @notice Convert the FISTDAO buy/sell tax accumulated in the Treasury into OSK/FIST LP and send it to the insurance pool
  /// @dev Full path (the 5 hops of `_burnFistdaoWithFist` **in reverse order**, with identical pair dependencies):
  ///        FISTDAO -> BNI -> WBNB -> USDT -> FIST
  ///      then reuse `_fistHalfToOskLp`: FIST split in half -> half buys OSK via OSK/FIST -> form LP -> insurance pool.
  ///      Caller: **anyone can call it directly** (keeper-driven) -- the funding source is the tax passively transferred in on FISTDAO transfers
  ///      (FISTDAO.oskPool wired to this contract), with no trigger fee; isomorphic to NodePoolDistributor.
  /// Pitfall (severe): **this contract** must be added to the whitelist on the FISTDAO side -- otherwise when this contract transfers FISTDAO
  ///   into the pair it triggers FISTDAO's 3% sell tax (the router internally does transferFrom -> not whitelisted -> taxed),
  ///   making the deposited amount differ from expectations.
  /// Pitfall: the amount comes from "this contract's FISTDAO balance" rather than an argument -- the tax accumulates passively, so the caller need not compute the amount,
  ///   and it also avoids a lingering remainder.
  /// Pitfall: reverts when not wired (fistdao/bni/usdt/fist/oskFistPair), never silently trading on a wrong path.
  /// Pitfall: this function carries transientNonReentrant -- so it must **not** be called internally from other guarded functions of this contract (it would self-lock).
  ///   The caller must be an **external call chain** (a keeper script / operational multisig).
  function convertFistdaoFeeToOskLp(uint256 slippageBp)
    external transientNonReentrant returns (uint256 lpAmt)
  {
    if (slippageBp == 0 || slippageBp > 9900) revert Treasury_BadSlippage(slippageBp);
    address fd = fistdao;
    address f = fist;
    address b = bni;
    address u = usdt;
    if (fd == address(0) || f == address(0) || b == address(0) || u == address(0) || oskFistPair == address(0)) {
      revert Treasury_PathNotConfigured();
    }

    uint256 fdBal = IERC20(fd).balanceOf(address(this));
    if (fdBal == 0) return 0; // no accumulated tax, return silently

    // Path: FISTDAO->BNI->WBNB->USDT (via router) + USDT->FIST (**direct on pair** -- that pair is on FstSwap)
    // Pitfall: the last segment cannot be folded into the router path -- PancakeRouter only knows its own factory's pairs, and it would
    //   revert the whole call because factory.getPair(USDT, FIST) returns 0.
    address[] memory path = new address[](4);
    path[0] = fd;
    path[1] = b;
    path[2] = router.WETH();
    path[3] = u;
    uint256 fistGot = _routerToUsdtThenFist(fdBal, path, slippageBp, block.timestamp + 30 minutes);
    if (fistGot == 0) return 0;

    uint256 oskGot;
    (lpAmt, oskGot) = _fistHalfToOskLp(fistGot, slippageBp);
    emit FistdaoTaxConverted(fdBal, fistGot, oskGot, lpAmt);
  }

  /// @notice (WARNING: **no caller** as of 2026-09-26) Split OSK in half: 1% swapped to FIST + 1% OSK retained -> form OSK/FIST LP
  /// @dev WARNING: **no longer on the requirements path**: on 2026-09-26 the client changed the FIST staking fuel fee from "opposite OSK"
  ///      to "same-token FIST", with the landing point moved to `injectFistToOskLp`; so "OSK fuel fee -> form LP" has no caller.
  ///      Reason for keeping: ABI alignment with deployed instances + historical traceability; it must **not** be wired to any requirements path.
  /// Pitfall: measure FIST by the "actual received delta", never trusting the router's quote array.
  /// Pitfall: reverts when not wired (fist/oskFistPair), never silently trading on a wrong path.
  /// Pitfall: direct on the OSK/FIST pair (user statement: OSK has only the OSK/FIST pair).
  function injectOskToOskFistLp(uint256 oskAmt, uint256 slippageBp)
    external transientNonReentrant returns (uint256 lpAmt)
  {
    if (msg.sender != farmVault) revert Treasury_Unauthorized();
    if (oskAmt == 0) return 0;
    if (slippageBp == 0 || slippageBp > 9900) revert Treasury_BadSlippage(slippageBp);
    address f = fist;
    address osk = address(aToken);
    if (f == address(0) || oskFistPair == address(0)) revert Treasury_PathNotConfigured();

    uint256 half = oskAmt / 2;
    uint256 oskForLp = oskAmt - half; // the 1% side's retained OSK goes directly into LP
    uint256 oskBal = IERC20(osk).balanceOf(address(this));
    if (oskBal < oskAmt) revert Treasury_InsufficientTransfer(oskAmt, oskBal);
    uint256 oskBaseline = oskBal - oskAmt;
    uint256 fistBaseline = IERC20(f).balanceOf(address(this));

    // 1% side OSK -> FIST (direct on the OSK/FIST pair, consistent with Requirement 2.0 L66 policy)
    address[] memory path = new address[](2);
    path[0] = osk;
    path[1] = f;
    uint256 fistGot = _swapExactTokensForTokens(half, path, slippageBp, block.timestamp + 30 minutes);
    lpAmt = _addOskFistLp(oskForLp, fistGot, slippageBp, block.timestamp + 30 minutes);
    emit StakeOskFeeLpAdded(oskAmt, fistGot, lpAmt);

    _sweepExcess(osk, oskBaseline);
    _sweepExcess(f, fistBaseline);
  }
  ///      Pitfall: early-return on zero amount -- router.getAmountsOut(0) reverts in most implementations, so it cannot be left to the external quote as a fallback.
  /// @dev token->token explicit-path swap
  /// Pitfall (severe): the **tax-token-friendly** variant must be used -- an intermediate token in the path may be a taxed token
  ///   (measured on mainnet: **BNI has a 2% transfer tax**), and the exact-input variant would fail with `Pancake: K` because the intermediate hop receives less.
  function _swapExactTokensForTokens(uint256 amountIn, address[] memory path, uint256 slippageBp, uint256 deadline)
    private returns (uint256 amountOut)
  {
    if (amountIn == 0) return 0;
    address tokenOut = path[path.length - 1];
    uint256[] memory amounts = router.getAmountsOut(amountIn, path);
    // Pitfall: the quote includes the intermediate token's pre-tax amount, while the post-tax receipt is lower -> the output lower bound must be additionally relaxed for tax consumption.
    uint256 hops = path.length > 2 ? path.length - 2 : 0;
    uint256 taxAllowance = 10000 - (hops * 300);
    uint256 quotedOut = Math.mulDiv(amounts[amounts.length - 1], taxAllowance, 10000, Math.Rounding.Floor);
    uint256 minOut = Math.mulDiv(quotedOut, 10000 - slippageBp, 10000, Math.Rounding.Floor);
    if (minOut == 0) revert Treasury_ZeroAmount();
    uint256 balBefore = IERC20(tokenOut).balanceOf(address(this));
    IERC20(path[0]).forceApprove(address(router), amountIn);
    router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, minOut, path, address(this), deadline);
    amountOut = IERC20(tokenOut).balanceOf(address(this)) - balBefore;
  }
  // ════════════════════════════════════════════════════════════
  //  (removed) old _doAddLp -- the BNB channel's leftover OSK/WBNB LP implementation
  // ════════════════════════════════════════════════════════════
  // Pitfall: that function was **dead code** (zero calls repo-wide), and its behavior directly conflicted with Requirement 2.0 L144 --
  //   L144 states OSK has only the OSK/FIST pair, while it did addLiquidity(aToken, wbnb).
  //   If kept, a future maintainer might wire it by mistake and form an out-of-requirement OSK/WBNB pool. So it was removed entirely.
  //   The requirement-compliant LP paths are: _buyOskFistAndAddLp (BNB channel) / _buyOskWithFistAndAddLp (FIST channel).

  // Design intent: dual-caller pattern -- FarmVault unrestricted (redemption case), Owner capped at 5% of the balance per tx and only to aStaking/bPool (reward payout case). On insufficient balance it auto-refills from the pair, and auto-refills again after payment.
  // Pitfall: the cap is computed from the current balance rather than a fixed value, preventing the treasury from being drained in one go. The three-stage "refill, then pay, then refill" ensures the payment succeeds.
  /// @return paid the amount actually paid (may be **less than** aAmt due to insufficient treasury balance -- the caller must reconcile against it)
  /// @dev Pitfall: this function **silently truncates** on insufficient balance (pays the full balance instead of reverting) -- this is so a user's claim
  ///   is not blocked by a short-term treasury shortage; but the caller **must** use the return value to detect underpayment, otherwise an underpaid entitlement is unobservable.
  function payoutReward(address to, uint256 aAmt) external transientNonReentrant returns (uint256 paid) {
    bool isContractCaller = msg.sender == farmVault;
    if (!isContractCaller && msg.sender != owner()) revert Treasury_Unauthorized();
    // Owner restricted: max 5% treasury balance per tx, only to aStaking pool or bPool
    if (!isContractCaller) {
      if (to != aStaking && to != bPool) revert Treasury_Unauthorized();
      uint256 balCheck = aToken.balanceOf(address(this));
      uint256 cap = balCheck / 20; // 5% = 1/20
      if (aAmt > cap) aAmt = cap;
    }
    uint256 bal = aToken.balanceOf(address(this));
    // If balance insufficient, refill from pair first
    if (aAmt > bal && address(aPair) != address(0)) {
      _refillFromPair(aAmt - bal);
      bal = aToken.balanceOf(address(this));
    }
    if (aAmt > bal) aAmt = bal; // final fallback: if still insufficient after refill, pay the full balance
    if (aAmt > 0) {
      // M-6-fix: use SafeERC20.safeTransfer to check the return value, preventing a silent failure
      IERC20(address(aToken)).safeTransfer(to, aAmt);
      emit RewardPaid(to, aAmt);
    }
    paid = aAmt; // actual paid amount (for the caller to reconcile)
    // Auto-refill: check after every payout, cooldown + below target -> auto refill from pair
    _autoRefill();
  }

  // Directly transfer A-coin from pair to refill treasury, WBNB stays in pair -> A price rises
  // Design intent: instead of swapping, draw A-coin directly via transferFromPair, bypassing swap tax and slippage. Leaving WBNB in the pair makes A-coin scarcer relative to WBNB, naturally pushing the A-coin price up. Draw at most 5% of the pair reserves at a time to prevent a price impact.
  // Pitfall: after transferFromPair, sync() must be called to update the pair's internal reserve data, otherwise subsequent swaps would use stale prices and allow arbitrage. If sync fails, only emit an event without reverting, because the A-coin transfer already succeeded and a sync failure does not affect treasury safety.
  function _refillFromPair(uint256 need) private {
    if (need == 0 || address(aPair) == address(0)) return;
    uint256 bal = aToken.balanceOf(address(this));
    if (bal >= TREASURY_TARGET) return; // Already at target, skip refill
    uint256 gap = TREASURY_TARGET - bal;
    uint256 target = need > gap ? gap : need; // Not exceeding the gap
    (uint112 r0, uint112 r1,) = aPair.getReserves();
    address t0 = aPair.token0();
    uint256 aR = t0 == address(aToken) ? uint256(r0) : uint256(r1);
    if (aR == 0) return;
    // Max 5% of pair A reserves per tx
    // Pitfall: the bound must be based on the **reserve proportion** rather than an absolute amount -- an absolute amount becomes too large an impact once the reserves shrink.
    uint256 maxTake = aR * MAX_REFILL_IMPACT_BP / 10_000;
    if (target > maxTake) target = maxTake;
    if (target == 0) return;
    // Directly transfer A from pair (super._transfer bypasses allowance + tax), sync updates reserves
    aToken.transferFromPair(address(this), target);
    try aPair.sync() {} catch { emit SyncFailed(address(aPair)); }
    emit TreasuryRefilled(target, 0);
  }

  // Auto-refill: triggered after payoutReward, 5-min cooldown + below 80M -> refill from pair
  // Design intent: after each reward payout, automatically maintain the 80M reserve floor. Not exposed publicly; called only inside payoutReward.
  // Pitfall: the cooldown prevents gas waste and price impact from frequent refills.
  function _autoRefill() private {
    if (block.timestamp < lastRefillTime + REFILL_COOLDOWN) return;
    uint256 bal = aToken.balanceOf(address(this));
    if (bal >= TREASURY_TARGET) return;
    // H-1-fix (CEI): lastRefillTime must be updated before the external call _refillFromPair, ensuring the correct CEI order
    lastRefillTime = block.timestamp;
    _refillFromPair(TREASURY_TARGET - bal);
  }

  // ── A/quote ratio sliding window management ──

  // Design intent: callable by anyone; a keeper periodically triggers a refresh of the ratio window (read only by the getRatioInfo view).
  // Pitfall: multiple calls in the same block take effect only once.
  // Secure: transientNonReentrant prevents tampering with the ratio window via a treasury.call{value:} callback.
  //         Attack path: payoutBnb -> withdrawReserve -> treasury.call -> receive() -> updateRatioSnapshot()
  function updateRatioSnapshot() external transientNonReentrant {
    _updateRatioHistory();
  }

  // Design intent: read the pair's current A/quote ratio (A-per-quote, 1e18 precision; quote = the FIST side of OSK/FIST)
  function _readSpotRatio() private view returns (uint256) {
    if (address(aPair) == address(0)) return 0;
    (uint112 r0, uint112 r1,) = aPair.getReserves();
    if (r0 == 0 || r1 == 0) return 0;
    address t0 = aPair.token0();
    uint256 aR = t0 == address(aToken) ? uint256(r0) : uint256(r1);
    uint256 wR = t0 == address(aToken) ? uint256(r1) : uint256(r0);
    return Math.mulDiv(aR, 1e18, wR, Math.Rounding.Floor);
  }

  // Design intent: update the 3-block ratio sliding window. Writes in a new block, skips in the same block.
  // Pitfall: the current reserve value must be passed in (read externally), avoiding re-reading a stale value after the pair reserves update.
  // V22-fix: if the window has not been updated for more than RATIO_STALE_BLOCKS (10 blocks), it is treated as stale and the window is reset (fill count = 1),
  //          preventing stale data from making the avg ratio deviate severely from the current spot, which would make _getEffectiveRatio return an inflated avg ratio.
  function _updateRatioHistory() private {
    if (address(aPair) == address(0)) return;
    if (block.number == _lastRatioBlock) return;
    uint256 ratio = _readSpotRatio();
    // window stale: reset rather than shift, discarding stale historical data
    if (block.number - _lastRatioBlock > RATIO_STALE_BLOCKS) {
      _ratioHistory0 = 0;
      _ratioHistory1 = 0;
      _ratioHistory2 = ratio;
      _ratioFilledCount = 1;
    } else {
      _ratioHistory0 = _ratioHistory1;
      _ratioHistory1 = _ratioHistory2;
      _ratioHistory2 = ratio;
      if (_ratioFilledCount < RATIO_WINDOW_SIZE) _ratioFilledCount++;
    }
    _lastRatioBlock = uint64(block.number);
    emit RatioSnapshotUpdated(_lastRatioBlock, ratio);
  }

  // Design intent: compute the 3-block average ratio.
  // Pitfall: returns 0 when never updated; falls back to the current spot when not updated for more than RATIO_STALE_BLOCKS (10) blocks.
  function _getAvgRatio() private view returns (uint256) {
    if (_ratioFilledCount == 0) return 0;
    if (block.number - _lastRatioBlock > RATIO_STALE_BLOCKS) return _readSpotRatio();
    uint256 sum = _ratioHistory0 + _ratioHistory1 + _ratioHistory2;
    return sum / _ratioFilledCount;
  }

  // Design intent: compute the deviation (bp). Returns 0 when avg=0.
  function _deviationBp(uint256 spot, uint256 avg) private pure returns (uint256) {
    if (avg == 0) return 0;
    uint256 diff = spot > avg ? spot - avg : avg - spot;
    return diff * 10000 / avg;
  }

  // Design intent: return the effective A/quote ratio (A-per-quote, 1e18 precision).
  //   Rule: spot deviation <= 15% -> use spot; deviation > 15% -> fall back to avg.
  //   When avg is unavailable (uninitialized), use spot.
  //  Design boundary: the result is only for the getRatioInfo view; it is not passed through to CoreVault's business settlement, AToken's buy gating, or any fund path.
  function _getEffectiveRatio() private view returns (uint256) {
    uint256 spotRatio = _readSpotRatio();
    if (spotRatio == 0) return 0;
    uint256 avgRatio = _getAvgRatio();
    if (avgRatio == 0) return spotRatio;
    return _deviationBp(spotRatio, avgRatio) > MAX_DEVIATION_BP ? avgRatio : spotRatio;
  }

  // ── Public view functions ──
  // Design intent: return the current spot ratio (A-per-quote), the 3-block avg ratio, the deviation (bp), and the effective ratio.
  function getRatioInfo() external view returns (
    uint256 spotRatio, uint256 avgRatio, uint256 deviationBp, uint256 effectiveRatio
  ) {
    spotRatio = _readSpotRatio();
    avgRatio = _getAvgRatio();
    deviationBp = _deviationBp(spotRatio, avgRatio);
    effectiveRatio = _getEffectiveRatio();
  }

  // Get the A/quote exchange rate (1 quote = ? A, 1e18 precision), read directly from the pair reserves
  // Design intent: compute the A-per-quote rate directly from the pair reserves, with no external dependency and zero gas (a view function). Used for frontend display and computation.
  // Note: under Requirement 2.0 L144, quote = FIST (pair = OSK/FIST). For A_per_USD, use CoreVault.getAPerUsd().
  function getAPerQuote() external view returns (uint256) {
    if (address(aPair) == address(0)) return 0;
    (uint112 r0, uint112 r1,) = aPair.getReserves();
    address t0 = aPair.token0();
    uint256 aR = t0 == address(aToken) ? r0 : r1;
    uint256 quoteR = t0 == address(aToken) ? r1 : r0;
    if (aR == 0 || quoteR == 0) return 0;
    // 1 quote = aR / quoteR A  (1e18 precision)
    return Math.mulDiv(aR, 1e18, quoteR, Math.Rounding.Floor);
  }

  /// @notice Pay out redemption principal in BNB (replacing the original payoutFromTreasury USDT path, which was cleaned up)
  /// @dev   When the treasury's BNB is insufficient, automatically pull the difference from the insurance pool; callable only by farmVault
  /// @dev   User's explicit requirement: when the recipient cannot receive BNB it **must revert the whole call**, no pending/deferred claim allowed.
  ///        So the atomic semantics are kept here -- a failed transfer reverts, rolled back together by `redeemPrincipal`.
  function payoutBnb(address to, uint256 bnbAmount) external transientNonReentrant {
    if (msg.sender != farmVault) revert Treasury_Unauthorized();
    if (bnbAmount == 0) return;
    uint256 balance = address(this).balance;
    if (balance < bnbAmount) {
      uint256 deficit = bnbAmount - balance;
      uint256 insuranceBal = address(insurancePool).balance;
      uint256 toPull = deficit < insuranceBal ? deficit : insuranceBal;
      if (toPull > 0) {
        IInsurancePool(insurancePool).withdrawReserve(address(0), toPull);
      }
    }
    balance = address(this).balance;
    if (balance < bnbAmount) revert Treasury_ReserveInsufficient(bnbAmount, balance);
    // Design rationale (user requirement, hard constraint): a recipient refusing payment -> **revert the whole call**, no pending, no deferral.
    //   That is, when an EIP-7702 delegated account (or its delegated code) refuses native BNB, its redemption necessarily fails,
    //   and the position state stays unchanged as the transaction rolls back -- this is **expected behavior**, not a defect.
    //   If the user wants to redeem, they must first remove the delegation or switch to an address that can receive native currency.
    // Pitfall: do not change this to a fault-tolerant "record pending + event" path -- that would break redemption atomicity,
    //   and introduce an intermediate state of "position already deducted but funds stuck in the contract", inconsistent with the requirements.
    (bool success,) = to.call{value: bnbAmount}("");
    if (!success) revert Treasury_TransferFailed();
    emit TreasuryPayout(to, bnbAmount);
  }

  /// @notice Pull the specified asset from the insurance pool to the Treasury (generic function, supports ERC20 + native BNB)
  /// @param token  token address (ERC20, or address(0) for native BNB)
  /// @param amount amount to pull
  /// @dev Pulled directly via InsurancePool.withdrawReserve, with no approve needed
  function pullFromInsurancePool(address token, uint256 amount) external transientNonReentrant {
    if (msg.sender != farmVault && msg.sender != owner()) revert Treasury_Unauthorized();
    if (amount == 0) revert Treasury_ZeroAmount();
    uint256 toPull;
    if (token == address(0)) {
      uint256 insuranceBal = address(insurancePool).balance;
      toPull = amount < insuranceBal ? amount : insuranceBal;
      if (toPull == 0) revert Treasury_ZeroAmount();
      IInsurancePool(insurancePool).withdrawReserve(address(0), toPull);
    } else {
      uint256 insuranceBal = IERC20(token).balanceOf(insurancePool);
      toPull = amount < insuranceBal ? amount : insuranceBal;
      if (toPull == 0) revert Treasury_ZeroAmount();
      IInsurancePool(insurancePool).withdrawReserve(token, toPull);
    }
    emit InsuranceFundsPulled(msg.sender, token, toPull);
  }

  // ── Emergency withdrawal ──

  // Design intent: owner emergency withdrawal -- the A token is the protocol's core reserve (constant 80M) and is hard-locked against withdrawal; any other ERC20/native BNB can be withdrawn by the owner.
  // Pitfall: the A token blacklist is hard-coded in the withdrawal path, ensuring the treasury's A-coin reserve cannot be misappropriated; even if the owner is compromised, the A coin cannot be moved out.
  function emergencyWithdraw(address token, address to, uint256 amount) external onlyOwner {
    if (to == address(0)) revert Treasury_ZeroAddress();
    if (token == address(aToken)) revert Treasury_AProtected(); // A coin hard lock
    IERC20(token).safeTransfer(to, amount);
    emit EmergencyWithdrawn(token, to, amount);
  }

  // Design intent: withdraw native BNB held by the contract (leftovers before deposit wrap, MEV refunds, accidental transfers). Callable only by owner.
  // Pitfall: BNB is not the A token, so it is within the withdrawable range; permissions are aligned with emergencyWithdraw, both under owner.
  function withdrawEth(address to, uint256 amount) external onlyOwner transientNonReentrant {
    if (to == address(0)) revert Treasury_ZeroAddress();
    (bool ok,) = to.call{value: amount}("");
    if (!ok) revert Treasury_WithdrawFailed();
    emit EthWithdrawn(to, amount);
  }

  receive() external payable {}

  error Treasury_ZeroAddress();
  error Treasury_ZeroAmount();
  error Treasury_WrapFailed();
  error Treasury_Unauthorized();
  error Treasury_WithdrawFailed();
  error Treasury_AProtected(); // A coin hard lock, cannot be withdrawn via emergencyWithdraw
  // Design intent: explicit error when the treasury's BNB reserve is insufficient -- never let a redemption fail silently
  error Treasury_ReserveInsufficient(uint256 required, uint256 balance);
  error Treasury_TransferFailed();
  error Treasury_ValueMismatch();
  error Treasury_BadSlippage(uint256 bp);
  // Requirements doc section 2: the deposit allocation path is not wired (any of fistdao/bni/usdt/fist/oskFistPair is 0)
  error Treasury_PathNotConfigured();
  // Pitfall: the semantics must be precise -- the caller (e.g. CoreVault) claims it transferred in X FIST but the treasury's actual delta is insufficient,
  //       indicating a wrong call order (calling allocate before transferring) or insufficient approval/balance.
  //       If Treasury_ZeroAmount were reused, debugging could not distinguish "argument is 0" from "not transferred first", violating the precise-localization principle.
  error Treasury_InsufficientTransfer(uint256 expected, uint256 actual);
}
// 0xFACEB00C - treasury with auto-refill
// DUAL-PATH: both the BNB deposit and FIST deposit fund-allocation paths coexist (Requirement 2.0 section 2, 1/2)
