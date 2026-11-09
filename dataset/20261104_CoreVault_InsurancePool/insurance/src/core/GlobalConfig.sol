// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
// Global Constants Library
// 0xCAFE0001 - single source of truth for all constants

// Design intent: all business constants managed centrally, a single source of truth (SSOT).
//   1) change one value and all referencing contracts take effect automatically (inlined as constant at compile time)
//   2) chain-id-adaptive address functions: mainnet (bsc mainnet) and testnet (bsc testnet) switch automatically, with no deployment-time arguments
//   3) grouped by business module: staking/farming/treasury/oracle/token, clear at a glance
// Pitfall: an internal constant is inlined at compile time and cannot be changed after deployment; if a runtime-variable parameter is needed, use a storage variable
library GlobalConfig {
  // ── Precision ──
  // Design intent: unified precision constants, avoiding magic numbers. RATE_PRECISION=10000 (1e4) is used for bps calculations, PRICE_PRECISION=1e18 for price precision.
  uint256 internal constant RATE_PRECISION  = 10000; // 1e4, 100% = 10000
  uint256 internal constant PRICE_PRECISION = 1e18;  // 1e18
  uint256 internal constant TEAM_REWARD_SHARE_BP = 10000;
  // ── Token decimals (measured on-chain, not assumed) ──
  // Token A OSK/BNIX = 18 decimals; token B FIST = **6 decimals** (an external token, not deployed by this project; decimals() reads 6 on-chain).
  // Pitfall (severe, a Critical confirmed by fork measurement): MIN/MAX_STAKE_B were originally written on an 18-decimal basis as
  //   `100 ether` / `100_000 ether` = 1e20 / 1e23 raw FIST = 1e14 / 1e17 FIST tokens;
  //   but FIST's total supply is only **2e14 raw (200 million tokens)** -- the lower threshold alone is **500,000 times** the total supply,
  //   so `stakeB` reverted with CoreVault_InvalidAmount at any amount, and the FIST staking module was **completely unusable**.
  //   It is now derived at 6-decimal precision, so the doc's "staking amount 100-100,000 tokens" truly holds for FIST.
  uint256 internal constant FIST_DECIMALS   = 6;
  uint256 internal constant ONE_FIST        = 10 ** FIST_DECIMALS; // 1e6 raw = 1 FIST token

  // ── AStaking / token A staking ──
  // Design intent: CYCLE=10 days controls the staking cycle; MIN/MAX_STAKE_A limits the single-stake amount, preventing whale monopolization.
  // Rate policy (requirements doc sections 3/4): FIST staking / OSK staking = 0.7% daily yield, staking cycle 10 days/cycle.
  //   per-cycle yield = DAILY_RATE_BP × CYCLE_DAYS = 70 × 10 = 700 bp = 7%/cycle.
  // [Confirmed] Staking is per-cycle and accrues no interest beyond the cycle: after one full cycle, no matter how long overdue, the yield is always "principal × 7%",
  //           not accrued daily and not compounded. Locked in by testStakeARewardDoesNotAccrueBeyondOneCycle.
  // Pitfall: the old implementation wrote mulDiv(principal, 7000, 100000) -- denominator 1e5, also yielding 7%.
  //       It is now unified to the RATE_PRECISION (1e4) policy, and "daily yield × days" is expressed explicitly,
  //       with values and Floor rounding bit-for-bit equivalent to the old implementation (7000/100000 == 700/10000).
  //
  // FAST_TEST quick-test switch (introduced 2026-09-24 / set to the production value false on 2026-09-27)
  //   When true, the three **time** constants are shortened to under 10 minutes (the yield rate is unchanged, still 7%/cycle), to run the whole flow quickly on-chain.
  //   It is now **production policy**: staking 10 days/cycle, claim cooldown 7 days, redemption lockup 24 hours.
  //   Pitfall: CYCLE and FIXED_RATE_BP must be **decoupled** -- the yield policy is always computed with CYCLE_DAYS=10,
  //     and only the wall-clock duration of the "maturity determination" is affected by the switch; if FIXED_RATE_BP followed the shortened CYCLE,
  //     the yield rate would collapse from 7% to near 0 (e.g. 70/1e4 × 5 minutes/day).
  //   Pitfall: this switch is a **compile-time constant**; after toggling it CoreVault must be redeployed (it cannot be changed at runtime).
  bool internal constant FAST_TEST = false;
  // Production values: staking 10 days/cycle, claim cooldown 7 days, redemption lockup 24 hours
  uint256 internal constant CYCLE_DAYS        = 10;              // yield policy: always 10 days (does not change with FAST_TEST)
  uint256 internal constant CYCLE             = FAST_TEST ? 5 minutes : CYCLE_DAYS * 1 days;
  uint256 internal constant DAILY_RATE_BP     = 70;              // daily yield 0.7% (1e4 precision)
  uint256 internal constant FIXED_RATE_BP     = DAILY_RATE_BP * CYCLE_DAYS; // 7%/cycle (independent of FAST_TEST)
  // Requirement 2.0 sections 3/4 "staking amount: 100-100,000 tokens" -- production policy.
  uint256 internal constant MIN_STAKE_A       = 100 ether;      // 100 token A (OSK, 18-decimal precision)
  uint256 internal constant MAX_STAKE_A       = 100_000 ether;  // 100,000 tokens (requirements doc sections 3/4: staking amount 100-100,000 tokens)
  // Token B (FIST) has **6-decimal precision**, so it must be derived from ONE_FIST -- do not write `100 ether` (see the pitfall above).
  uint256 internal constant MIN_STAKE_B       = 100 * ONE_FIST;    // 100 FIST = 1e8 raw
  uint256 internal constant MAX_STAKE_B       = 100_000 * ONE_FIST;  // 100,000 FIST = 1e11 raw (requirements doc sections 3/4)
  // Requirement 2.0 section 3 rule 2 / section 4 rule 2: 2% staking fuel fee -- deducted additionally from the user's wallet, not touching the staking principal.
  //   Token policy (WARNING: after the client change on 2026-09-26, the two sides are **no longer symmetric**):
  //     staking OSK(A) -> additionally deduct "FIST(B) worth 2%" -> stays directly in CoreVault = FIST staking mining pool reserve
  //     staking FIST(B) -> additionally deduct "2% of FIST(B)" -> transfer to treasury to form OSK/FIST LP -> insurance pool (same token, no oracle conversion)
  //   Note: it is **not 2% deducted from the staking principal itself**. stakeA is still charged in the opposite token and must be converted by USD equivalent via the oracle.
  // Conversion formulas (word-for-word consistent with design doc section 7.2; avgARate = how many OSK per 1 USD, avgBRate = how many FIST per 1 USD):
  //   stakeA(OSK): fee(FIST) = amount × STAKE_FEE_BP/1e4 × avgBRate / avgARate
  //   stakeB(FIST): fee(FIST) = amount × STAKE_FEE_BP/1e4            (same token, no conversion)
  // Pitfall: stakeA must not directly use `amount × 2%` -- the opposite token has different precision (OSK 18 decimals / FIST 6 decimals),
  //   and without conversion the fuel fee would be off by 1e12 times. Implementation in `Contracts/CoreVaultStaking.sol::_stakeFeeInOpposite`.
  //   Pitfall: stakeB conversely must **not** convert -- it is charged in the same token, and conversion would wrongly change the fuel fee amount.
  uint256 internal constant STAKE_FEE_BP      = 200;             // 2% fuel fee (charged additionally)
  // Design intent: 9-generation referral + 100-level team depth, approximating an unlimited-depth referral network to incentivize viral growth.
  // Pitfall: MAX_REFERRAL_GEN=9 generations; beyond that the reward is zero, preventing infinite recursion.
  uint256 internal constant MAX_REFERRAL_GEN  = 9;               // 9 generations of direct referral
  uint256 internal constant MAX_TEAM_DEPTH    = 100;             // 100-level differential (on deposit, update 100 ancestors upward)
  uint256 internal constant REFERRAL_TAX_BP   = 2000;            // 20% referral reward tax
  uint256 internal constant REFERRAL_NET_BP   = 8000;            // 80% net value
  // Valid-user threshold (client ruling on 2026-09-27): a first deposit that **reaches this channel's deposit lower bound** counts as a "valid direct referral".
  //   BNB channel  -> **0.1 BNB** (judged by BNB token count, see `_depositBNBCore`'s validation of `MIN_DEPOSIT_BNB`)
  //   FIST channel -> **100 USD value** (see `_depositFistCore`'s validation of `MIN_DEPOSIT_USD`)
  // Pitfall: a single USD constant must **not** be used to judge both channels uniformly -- BNB price fluctuation can make 0.1 BNB's USD value
  //   fall below 100 USD (measured: when BNB≈$774, 0.1 BNB≈$77), thereby misjudging a "qualifying minimum BNB deposit" as an invalid direct referral,
  //   silently weakening the referral network's `validDirectCount` and the 9-generation gating.
  //   The BNB channel's lower bound is already validated by **token count** at the entry point, so no threshold is layered on its USD side.
  uint256 internal constant VALID_USER_MIN_USD = 100 ether;     // FIST channel valid threshold (100 USD)

  // ── FarmVault / BNB farming ──
  // Design intent: BNB deposit farming, single amount 0.1-10 BNB (requirements doc section 2), claimable once every 7 days, redeemable after 24 hours.
  uint256 internal constant MIN_DEPOSIT_BNB   = 0.1 ether;       // 0.1 BNB minimum deposit (requirements doc section 2)
  uint256 internal constant MAX_DEPOSIT_BNB   = 10 ether;        // 10 BNB maximum deposit (requirements doc section 2)
  // ── FarmVault / FIST farming (Requirement 2.0 section 2, "FIST on-chain mining mechanism 2") ──
  // Design intent: one farming mechanism supports both BNB and FIST deposits, with the deposit bounds defined by "gold-standard real-time USD value":
  //   BNB side 0.1-10 BNB; FIST side 100-10000 USD value. Position principal is always denominated in USD,
  //   so the two channels share the same yield/3x max-out/redemption formulas, differing only in deposit token and fund allocation path.
  // Pitfall: the bounds are defined in USD rather than FIST token count -- a token-count range would break when the FIST price fluctuates, while a USD range stays valid.
  uint256 internal constant MIN_DEPOSIT_USD   = 100 ether;       // 100 USD minimum deposit (Requirement 2.0 section 2)
  uint256 internal constant MAX_DEPOSIT_USD   = 10_000 ether;    // 10000 USD maximum deposit (Requirement 2.0 section 2)
  // WARNING: under FAST_TEST these shorten to 5 minutes / 1 minute (see the CYCLE note above); production is 7 days / 24 hours
  uint256 internal constant CLAIM_COOLDOWN    = FAST_TEST ? 5 minutes : 7 days;   // claim cooldown
  uint256 internal constant LOCKUP_MIN        = FAST_TEST ? 1 minutes : 24 hours; // redemption lockup
  uint256 internal constant MAX_MULTIPLIER    = 3;               // 3x max-out
  // Requirement 2.0 sections 3/4: the **level threshold** for staking 3x max-out -- only users with team level V1 or above
  //   have dynamic yield subject to the 3x max-out constraint; ordinary users without a V level are not limited by 3x max-out (principal refunded in full).
  // Pitfall: the threshold is 1 (= V1), not 0 -- writing 0 would apply it to everyone, inconsistent with the requirement text "team level reaching V1 or above".
  uint256 internal constant MIN_MAXOUT_TEAM_LEVEL = 1;
  uint256 internal constant FEE_BP_TOTAL      = 500;             // 5% total fee
  uint256 internal constant FEE_BP_ASTAKING   = 250;             // 2.5% to AStaking
  uint256 internal constant FEE_BP_WALLET2    = 250;             // 2.5% to the fee address

  // ── Node mining pool dividend, system 2 "30% of network-wide static revenue" (source: node-requirements-doc.txt section 1, entitlements) ──
  // Requirement text: "5% / 5% / 10% / 10% of network-wide static revenue is injected into the node mining pool and split equally" -> 30% total.
  // Policy (confirmed, 1.0 original design): gross expense = user 100% + direct referral 20% + team 50% + node 30%
  //   = 200% (all **pre-tax**) -- that is, the node leg is an **additional** expense, not deducted from the user's share,
  //   and **does not participate** in 3x max-out accounting.
  // Coverage (re-confirmed 2026-09-23): **farming + OSK staking + FIST staking**, all three modules **do** accrue it
  //   (the original "farming only" was revised). Evidence: the requirement wording is "**network-wide** static revenue", not "farming static revenue";
  //   `development-requirements-doc-2.0.md:134-140` also defines team rewards as "X% of **static revenue**" -> staking 7%/cycle is static revenue.
  // Landing points (sharing one implementation, avoiding policy divergence):
  //   - farming: `Contracts/CoreVaultFarming.sol::_processYieldPayout` -> `_payoutNodePoolLeg(pendingUsd, avgARate)`;
  //   - staking: `Contracts/CoreVaultReferral.sol::_distributeStakingRewards` -> first take the USD equivalent of the static yield
  //           (`reward × 1e18 / rate`), then call `_payoutNodePoolLeg`;
  //   - the leg itself: `Contracts/CoreVaultStorage.sol::_payoutNodePoolLeg(baseUsd, avgARate)`.
  // WARNING: token conversion: `NodePoolDistributor` is **single-token immutable = OSK**, so the FIST staking pool's (B) static yield
  //   must be converted **by value** into OSK when transferred out. Pitfall: token->USD is `amount × 1e18 / rate` (same form as CoreVaultStaking.sol:55);
  //   never write the reverse direction `amount × rate / 1e18`.
  // Downstream: `src/core/NodePoolDistributor.sol` -- four-pool weighting 5/5/10/10 -> A / B / E / D.
  // WARNING: this is a **separate** node dividend from "system 1" and must not be mixed up or merged:
  //   system 1 (reward source): OSK sell tax 5% + withdrawal tax 2.5% -> `BWalletDistributor5` -> A/B/C/D/E **split equally 5 ways**;
  //   system 2 (entitlement, this constant): 30% of network-wide static revenue -> `NodePoolDistributor` -> A/B/E/D **weighted 5/5/10/10**.
  // Pitfall: the community node (C) does not participate in system 2 -- in the requirements the community enjoys only a 0.5% withdrawal tax + 1% trading tax, with no static revenue share.
  //   So the weight table sums to 30 (5+5+10+10), excluding the community.
  uint256 internal constant NODE_POOL_BP      = 3000;            // 30% node mining pool (founder 5 + co-founder 5 + sponsor 10 + operation 10, sum = 30)

  // ── Treasury ──
  // Design intent: TREASURY_TARGET=80,000,000 A is the treasury target reserve (Requirement 2.0 section 1, "treasury pool: 80,000,000");
  //   REFILL_COOLDOWN limits the refill frequency to save gas.
  uint256 internal constant TREASURY_TARGET   = 80_000_000 ether; // 80,000,000 A target
  // WARNING: zero-reference constant (the production value is only for semantic alignment): `Treasury` uses its **own** `REFILL_COOLDOWN = 5 minutes`
  //   (see `src/core/Treasury.sol`), and the two are independent. This constant has no src reference.
  uint256 internal constant REFILL_COOLDOWN   = 5 minutes;        // refill cooldown (not wired; Treasury holds its own constant of the same value)
  // WARNING: [1.0 leftover, zero reference] Requirement 2.0 has no "single-withdrawal cap" clause; this constant is not wired to any path.
  uint256 internal constant MAX_PAYOUT_BP     = 500;              // [1.0 leftover, zero reference] 5% single cap
  uint256 internal constant LP_SLIPPAGE_BP    = 500;              // 5% LP slippage
  // ── Deposit path slippage (Requirement 2.0 section 2) ──
  // Pitfall: the two deposit channels' slippage is **named separately** -- their hop counts and fees already differ, so differing tolerances are reasonable;
  //       named constants replace bare literals, eliminating the drift risk of "two magic numbers in one piece of logic"
  //       (previously the BNB side was a bare literal 1500, and the FIST side reused LP_SLIPPAGE_BP, with no explanation).
  //   BNB path: BNB->WBNB->USDT->OSK and BNB->WBNB->USDT->FIST each one swap, plus addLiquidity (more hops)
  //   FIST path: fist->OSK one swap, plus addLiquidity (fewer hops)
  uint256 internal constant BNB_DEPOSIT_SLIPPAGE_BP  = 1500;      // 15% -- BNB path (2 swaps + addLiquidity)
  uint256 internal constant FIST_DEPOSIT_SLIPPAGE_BP = 500;       // 5%  -- FIST path (1 swap + addLiquidity)
  // Requirement 2.0 section 1 L11: the conversion slippage for the 1.5% FISTDAO buy/sell tax -> OSK/FIST LP.
  //   The path is the longest (FISTDAO->BNI->WBNB->USDT->FIST is 4 swaps, plus FIST->OSK 1 more + addLiquidity),
  //   so it takes the same 15% as the BNB path, preventing multi-hop accumulated slippage from causing the trade to fail.
  uint256 internal constant FISTDAO_CONVERT_SLIPPAGE_BP = 1500;   // 15% -- FISTDAO 5-hop conversion + addLiquidity
  // WARNING: [1.0 leftover, zero reference] Requirement 2.0 section 1 removed the WBNB share policy (all converted via USDT/FIST),
  //   so this constant is not wired to any path and is kept only for traceability.
  uint256 internal constant WBNB_SHARE        = 5000;             // [1.0 leftover, zero reference] 50% WBNB share

  // ── Oracle ──
  // Design intent: TWAP_PERIOD=30min window prevents flash-loan price manipulation; UQ112=2^112 is for PancakePair's UQ112x112 fixed-point format.
  uint256 internal constant TWAP_PERIOD       = 30 minutes;       // TWAP window
  // WARNING: zero-reference constant (the production value is only for semantic alignment): `OracleLib`'s TWAP advance criterion uses `TWAP_PERIOD`
  //   (30 minutes), and this constant has no src reference. Its value is aligned with `TWAP_PERIOD`.
  uint256 internal constant TWAP_MIN_ELAPSED  = 30 minutes;       // TWAP minimum interval (not wired, aligned with TWAP_PERIOD)
  uint256 internal constant UQ112             = 2**112;           // UQ112x112 divisor

  // ── AToken / token A ──
  // L-8-fix (SSOT): the authoritative source for the sell-tax constants (BURN_BPS/WALLET2_BPS) and the initial mint amount (INITIAL_SUPPLY) is AToken.sol,
  //   and they are no longer redefined here, avoiding a dual-source drift risk. For a global reference, import AToken and read its public constants.
  //   The former ATK_BURN_BPS/ATK_WALLET2_BPS/ATK_INITIAL_MINT were dead constants (zero src references) and were deleted.

  // ── BSC Addresses ──
  // Design intent: chain-id-adaptive return of the correct address, avoiding hard-coded mainnet/testnet addresses. No manual arguments at deployment.
  // Pitfall: on a chain id other than 56/97 it returns address(0); the caller must check the return value, otherwise interacting with the zero address will revert.
  function getWBNB() internal view returns (address) {
    if (block.chainid == 56) return 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    if (block.chainid == 97) return 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;
    return address(0);
  }
  function getUSDT() internal view returns (address) {
    if (block.chainid == 56) return 0x55d398326f99059fF775485246999027B3197955;
    if (block.chainid == 97) return 0x337610d27c682E347C9cD60BD4b3b107C9d34dDd;
    return address(0);
  }
  function getRouter() internal view returns (address) {
    if (block.chainid == 56) return 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    if (block.chainid == 97) return 0xD99D1c33F9fC3444f8101754aBC46c52416550D1;
    return address(0);
  }
  function getFactory() internal view returns (address) {
    if (block.chainid == 56) return 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
    if (block.chainid == 97) return 0x6725F303b657a9451d8BA641348b6761A6CC7a17;
    return address(0);
  }

  // ── Daily yield tier mcap upper bounds (Requirement 2.0 section 2, 13 tiers) ──
  // Design intent: one-to-one correspondence with YieldMath's 13 daily yield rates (0.5%-2.5%) --
  //   t[i] is tier i's mcap upper bound (USD); when mcap falls in (t[i-1], t[i]] tier i's rate is used.
  // Pitfall: this table is the **yield tiers**, a separate set of thresholds from TEAM_THRESHOLDS below (team levels V1-V7); do not confuse them.
  // Pitfall (severe): it must return **13** entries -- YieldMath.apySec uses binary search with `hi = len - 1`,
  //   so with n entries lo can be at most n-1, and the highest tier reached is tR(n-1).
  //   If only 12 entries were given (t[0..11]), then for mcap >= 50.01M only tR(11)=2.3%/day could be reached,
  //   and requirement L87's "above 50.01M, 2.5% daily" tR(12) would be **permanently unreachable**.
  //   After appending t[12] = type(uint256).max as the highest-tier sentinel, lo can reach 12 -> tR(12)=2.5%.
  function TIER_UPPERS() internal pure returns (uint256[] memory) {
    uint256[] memory t = new uint256[](13);
    t[0]  = 510_000 ether;   t[1]  = 1_010_000 ether;  t[2]  = 5_010_000 ether;  t[3]  = 10_010_000 ether;
    t[4]  = 15_010_000 ether; t[5]  = 20_010_000 ether; t[6]  = 25_010_000 ether; t[7]  = 30_000_000 ether;
    t[8]  = 35_010_000 ether; t[9]  = 40_010_000 ether; t[10] = 45_010_000 ether; t[11] = 50_010_000 ether;
    t[12] = type(uint256).max; // highest-tier sentinel (mcap >= 50.01M -> tR(12) = 2.5%/day)
    return t;
  }

  // Design intent: team level threshold array, where the index is the level (t[0]=V0 baseline 0, t[1]=V1 ... t[7]=V7).
  // Pitfall: requirements doc section 5 defines only V1-V7, 7 levels total, with no V8/V9.
  //       The array length determines _effectiveLevel's reachable maximum (l < thresholds.length); truncating to 8 entries
  //       caps it at V7 -- preventing an unauthorized high level (the former V8/V9) from being reached and claiming excess team rewards.
  function TEAM_THRESHOLDS() internal pure returns (uint256[] memory) {
    uint256[] memory t = new uint256[](8);
    t[0] = 0;                    // V0 baseline
    t[1] = 3_000 ether;          // V1 team 3000 U
    t[2] = 10_000 ether;         // V2 team 10k U
    t[3] = 30_000 ether;         // V3 team 30k U
    t[4] = 100_000 ether;        // V4 team 100k U
    t[5] = 300_000 ether;        // V5 team 300k U
    t[6] = 1_000_000 ether;      // V6 team 1M U
    t[7] = 3_000_000 ether;      // V7 team 3M U (highest level in the doc)
    return t;
  }
}
// 0xCAFE0001 - global config: single source of truth