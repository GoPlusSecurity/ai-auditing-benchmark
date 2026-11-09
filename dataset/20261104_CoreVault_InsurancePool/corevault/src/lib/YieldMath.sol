// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

library YieldMath {
  uint256 internal constant SPD = 86400;
  uint256 internal constant RP = 1e4;

  function tR(uint8 i) internal pure returns (uint256 r) {
    assembly {
      switch i
      case 0  { r := 50 }    // 0.5%/d    lp<510k
      case 1  { r := 70 }    // 0.7%/d    510k<=lp<1.01M
      case 2  { r := 90 }    // 0.9%/d    1.01M<=lp<5.01M
      case 3  { r := 110 }   // 1.1%/d    5.01M<=lp<10.01M
      case 4  { r := 120 }   // 1.2%/d    10.01M<=lp<15.01M
      case 5  { r := 130 }   // 1.3%/d    15.01M<=lp<20.01M
      case 6  { r := 140 }   // 1.4%/d    20.01M<=lp<25.01M
      case 7  { r := 150 }   // 1.5%/d    25.01M<=lp<30M
      case 8  { r := 170 }   // 1.7%/d    30M<=lp<35.01M
      case 9  { r := 190 }   // 1.9%/d    35.01M<=lp<40.01M
      case 10 { r := 210 }   // 2.1%/d    40.01M<=lp<45.01M
      case 11 { r := 230 }   // 2.3%/d    45.01M<=lp<50.01M
      default { r := 250 }   // 2.5%/d    lp>=50.01M
    }
  }
  // ════════════════════════════════════════════════════════════
  //  External library entry points (public) -- so the library code is **no longer inlined** into CoreVault
  // ════════════════════════════════════════════════════════════
  // Design rationale (size constraint): the CoreVault inheritance chain already exceeds the EIP-170 limit (24,576 bytes).
  //   Changing the pure-function library's wrapper functions from `internal` to `public` -> the compiler switches to DELEGATECALL
  //   to this library's separately deployed instance, and the library logic (tR/apySec/calcInt/dRefR/tmR/redeemP/is3x)
  //   is thereby moved out of CoreVault's bytecode.
  // Cost: ~100-2600 extra gas per call (DELEGATECALL); deployment must link the library address (forge handles it automatically).
  // Pitfall: internal helper functions stay `internal` -- they are called by the public wrapper functions and compiled into the **library itself**,
  //   not back into CoreVault.

  function tierRate(uint8 i) public pure returns (uint256) { return tR(i); }

  function apySec(uint256 mcap) internal pure returns (uint256) {
    uint8 idx;
    if (mcap < 510_000 ether) { idx = 0; }          // < 510k
    else if (mcap < 1_010_000 ether) { idx = 1; }     // 510k~1.01M
    else if (mcap < 5_010_000 ether) { idx = 2; }   // 1.01M~5.01M
    else if (mcap < 10_010_000 ether) { idx = 3; }  // 5.01M~10.01M
    else if (mcap < 15_010_000 ether) { idx = 4; }  // 10.01M~15.01M
    else if (mcap < 20_010_000 ether) { idx = 5; }  // 15.01M~20.01M
    else if (mcap < 25_010_000 ether) { idx = 6; }  // 20.01M~25.01M
    else if (mcap < 30_000_000 ether) { idx = 7; }  // 25.01M~30M
    else if (mcap < 35_010_000 ether) { idx = 8; }  // 30M~35.01M
    else if (mcap < 40_010_000 ether) { idx = 9; }  // 35.01M~40.01M
    else if (mcap < 45_010_000 ether) { idx = 10; } // 40.01M~45.01M
    else if (mcap < 50_010_000 ether) { idx = 11; } // 45.01M~50.01M
    else { idx = 12; }                               // >= 50.01M
    return Math.mulDiv(tR(idx), 1e14, SPD, Math.Rounding.Floor);
  }
  function apyPerSecond(uint256 lpMarketCap) public pure returns (uint256) { return apySec(lpMarketCap); }

  function apySec(uint256 mcap, uint256[] memory tierUppers) internal pure returns (uint256) {
    uint8 len = uint8(tierUppers.length);
    uint8 lo = 0;
    uint8 hi = len - 1;
    while (lo < hi) {
      uint8 mid = uint8((uint16(lo) + uint16(hi)) >> 1);
      if (mcap < tierUppers[mid]) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return Math.mulDiv(tR(lo), 1e14, SPD, Math.Rounding.Floor);
  }
  function apyPerSecond(uint256 lpMarketCap, uint256[] memory tierUppers) public pure returns (uint256) {
    return apySec(lpMarketCap, tierUppers);
  }

  function calcInt(uint256 p, uint256 r1e18, uint256 dt) internal pure returns (uint256) {
    return Math.mulDiv(p, Math.mulDiv(r1e18, dt, 1, Math.Rounding.Floor), 1e18, Math.Rounding.Floor);
  }
  function calcInterest(uint256 principal, uint256 ratePerSec1e18, uint256 elapsed)
    public pure returns (uint256) { return calcInt(principal, ratePerSec1e18, elapsed); }

  // Direct referral generation rates (requirements doc section 5: gen 1 = 8%, gen 2 = 5%, gens 3-9 = 1% each)
  // Pitfall: the old implementation used 10%/6%/2%, inconsistent with the requirements doc; now aligned to the doc.
  //       Generation 10 (gen>=9) has no reward and returns 0 to prevent infinite recursion.
  function dRefR(uint8 gen) internal pure returns (uint256 r) {
    if (gen >= 9) return 0;
    assembly { switch gen case 0 { r := 800 } case 1 { r := 500 } default { r := 100 } }
  }
  function directReferralRate(uint8 generation) public pure returns (uint256) { return dRefR(generation); }

  // Team reward level rates (requirements doc section 5: V1 10% / V2 20% / V3 30% / V4 35% / V5 40% / V6 45% / V7 50%)
  // Pitfall: requirements doc section 5 defines only V1-V7. TEAM_THRESHOLDS is truncated to 8 entries, so V8/V9 are unreachable;
  //       lv8/lv9 are still capped at V7's 5000 here, to prevent any unauthorized path that reaches a high level from claiming excess team rewards.
  function tmR(uint8 lv) internal pure returns (uint256 r) {
    assembly {
      switch lv
      case 0 { r := 0 } case 1 { r := 1000 } case 2 { r := 2000 }
      case 3 { r := 3000 } case 4 { r := 3500 } case 5 { r := 4000 }
      case 6 { r := 4500 } case 7 { r := 5000 } case 8 { r := 5000 } case 9 { r := 5000 }
      default { r := 0 }
    }
  }
  function teamRate(uint8 level) public pure returns (uint256) { return tmR(level); }

  function redeemP(uint256 inv, uint256 ear) internal pure returns (uint256) {
    if ((ear >> 128) != 0) return 0;
    uint256 d2 = ear << 1;
    return d2 >= inv ? 0 : inv - d2;
  }
  function redeemablePrincipal(uint256 invested, uint256 earned)
    public pure returns (uint256) { return redeemP(invested, earned); }

  function is3x(uint256 inv, uint256 tot) internal pure returns (bool) {
    return tot >= Math.mulDiv(inv, 3, 1, Math.Rounding.Floor);
  }
  function isMaxOut(uint256 invested, uint256 totalEarned) public pure returns (bool) {
    return is3x(invested, totalEarned);
  }
}
