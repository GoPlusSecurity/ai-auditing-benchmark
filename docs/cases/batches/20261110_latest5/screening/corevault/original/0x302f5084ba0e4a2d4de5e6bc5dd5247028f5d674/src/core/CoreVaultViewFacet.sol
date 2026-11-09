// src/core/CoreVaultViewFacet.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CoreVaultStorage} from "../../Contracts/CoreVaultStorage.sol";
import {OracleLib} from "./OracleLib.sol";
import {GlobalConfig} from "./GlobalConfig.sol";

/// @title  CoreVaultViewFacet -- CoreVault's **read-only view facet**
/// @notice Carries all of CoreVault's external view functions, called by CoreVault via `DELEGATECALL`.
///
/// @dev ===== design rationale (size constraint, must be understood) =====
/// The runtime bytecode of the CoreVault inheritance chain once reached **30,747 bytes**, exceeding the EIP-170 limit (24,576),
/// so it **could not be deployed** on BSC mainnet. Per-layer measurements showed the bottleneck was concentrated in the view and staking layers.
/// This contract inherits `CoreVaultStorage` -> **its storage layout is identical to CoreVault's**;
/// when called by CoreVault via `DELEGATECALL`, it reads and writes CoreVault's storage slots -- so the view logic
/// could be moved out as-is, with external callers (frontend / CoreVaultViewer / tests) **needing no changes at all**.
///
/// @dev ===== pitfalls =====
/// (1) **Do not inherit the CoreVault body** -- that would pull all the business code back and lose the slimming benefit.
///    Inherit only `CoreVaultStorage` (pure storage + events + errors + internal helpers).
/// (2) **Layout consistency is a hard constraint** -- this contract's inheritance chain must exactly match CoreVault's storage prefix.
///    CoreVault is: CoreVaultStorage -> CoreVaultAdmin -> ... , while this contract is: CoreVaultStorage.
///    Since CoreVaultAdmin and the layers after it **add no state variables** (functions only), the two layouts are the same.
///    If state variables are ever added in Admin/Referral/..., they **must also be declared here**, otherwise the views read the wrong slots.
/// (3) `getFarmingRaw` **no longer uses a hard-coded storage slot** -- the original relied on `keccak256(abi.encode(u, 45))`,
///    but that slot number's premise "aToken/bToken/treasury are immutable (occupy no slot)" no longer holds after the module split
///    (the three must become ordinary storage variables, shifting all slot numbers by 3). It now **reads the mapping directly** `_fvUsers[u]`,
///    fully decoupled from the layout -- see the note at `getFarmingRaw` in this file.
/// (4) This contract is **read-only**: it contains no state-changing function. If write logic were mistakenly added, it would modify
///    CoreVault's real storage via DELEGATECALL -- a high-severity error.
contract CoreVaultViewFacet is CoreVaultStorage {
    // ════════════════════════════════════════════════════════════
    //  Staking views (moved out of CoreVaultStaking)
    // ════════════════════════════════════════════════════════════

    function activeOrder(address user, uint8 t) external view returns (
        uint256 principal, uint256 endTime, uint8 flags
    ) {
        StakeState storage s = t == 0 ? _aStakes[user] : _bStakes[user];
        return (s.active.principal, s.active.endTime, s.active.flags);
    }

    function getModValues(address user) external view returns (
        uint256 teamA, uint256 teamB, uint256 directA, uint256 directB,
        uint256 maxA, uint256 maxB, uint256 earnedDirect, uint256 earnedTeam
    ) {
        teamA = _modA[user].teamUsd;
        directA = _modA[user].directUsd;
        maxA = _modA[user].maxUsd;
        teamB = _modB[user].teamUsd;
        directB = _modB[user].directUsd;
        maxB = _modB[user].maxUsd;
        earnedDirect = _modEarnedDirect[user];
        earnedTeam = _modEarnedTeam[user];
    }

    function totalEarnedAllStaking(address u) external view returns (uint256) {
        return _aStakes[u].totalEarned + _bStakes[u].totalEarned;
    }

    function getTotalPoolA() external view returns (uint256) {
        return _totalPoolA;
    }

    function getTotalPoolB() external view returns (uint256) {
        return _totalPoolB;
    }

    /// @dev Cumulative donated amount for this pool (measured in the original token) -- strictly separated from the principal pools _totalPoolA/B
    /// @param t 0 = OSK(A) staking pool, 1 = FIST(B) staking pool
    function getTotalDonated(uint8 t) external view returns (uint256) {
        return t == 0 ? _totalDonatedA : _totalDonatedB;
    }

    /// @dev Cumulative reward amount "retained in this pool because the upline had no valid stake" (measured in the original token).
    ///      Source: in `_distributeStakingLoop`, the upline has not staked / has maxed out -> skip payout, amount retained in this pool.
    /// Pitfall: strictly separated from `getTotalDonated` -- the former is an external donation, this is retained reward; different sources must not be merged.
    /// @param t 0 = OSK(A) staking pool, 1 = FIST(B) staking pool
    function getTotalRedirected(uint8 t) external view returns (uint256) {
        return t == 0 ? _redirectedToPoolA : _redirectedToPoolB;
    }

    /// @dev This pool's **actual redemption reserve** (the contract's balance of that token)
    ///      Pitfall: returns only the balance, with no USD conversion -- conversion requires reading the oracle, a state change, which cannot be done in a view.
    function getPoolReserve(uint8 t) external view returns (uint256) {
        return t == 0 ? IERC20(address(aToken)).balanceOf(address(this))
                      : IERC20(address(bToken)).balanceOf(address(this));
    }

    /// @dev Whether this pool's staking dynamic yield entitlement is closed (true after 3x max-out, restored after rebuilding a new order in this pool)
    /// Pitfall: must be queried per pool -- an OSK max-out does not affect FIST entitlements.
    function isStakingRightsClosed(address u, uint8 t) external view returns (bool) {
        return _stakingRightsClosed(u, t == 0 ? TokenType.A : TokenType.B);
    }

    /// @dev This pool's total dynamic yield (direct referral reward + team differential), denominated in that pool's token amount
    function getStakingDynamicEarned(address u, uint8 t) external view returns (uint256) {
        return _dynamicEarnedByPool(u, t == 0 ? TokenType.A : TokenType.B);
    }

    /// @dev This pool's **pending static yield to be paid** (deferred at max-out, paid when a new position is rebuilt in this pool)
    function getPendingStaticYield(address u, uint8 t) external view returns (uint256) {
        StakeState storage s = (t == 0) ? _aStakes[u] : _bStakes[u];
        return s.pendingStaticYield;
    }

    /// @dev This pool's 3x max-out progress: (accumulated dynamic yield, max-out threshold)
    function getStakingMaxOutProgress(address u, uint8 t)
        external view returns (uint256 dynamicEarned, uint256 threshold)
    {
        TokenType tt = t == 0 ? TokenType.A : TokenType.B;
        StakeState storage s = (tt == TokenType.A) ? _aStakes[u] : _bStakes[u];
        dynamicEarned = _dynamicEarnedByPool(u, tt);
        threshold = (s.active.principal + s.ready.principal) * GlobalConfig.MAX_MULTIPLIER;
    }

    /// @dev Three-module 3x max-out overview: the independent status of farming / OSK staking / FIST staking
    function getThreeSectorStatus(address u) external view returns (
        bool farmExited, bool oskRightsClosed, bool fistRightsClosed,
        uint256 farmTtu, uint256 oskTtu, uint256 fistTtu,
        uint8 lvFarm, uint8 lvOsk, uint8 lvFist, uint8 syncedLevel
    ) {
        farmExited = _fvUsers[u].flags & 1 != 0;
        oskRightsClosed = _stakingRightsClosed(u, TokenType.A);
        fistRightsClosed = _stakingRightsClosed(u, TokenType.B);
        farmTtu = _fvUsers[u].totalTeamUsd;
        oskTtu = _modA[u].teamUsd;
        fistTtu = _modB[u].teamUsd;
        (lvFarm, lvOsk, lvFist) = _levelBreakdown(u);
        syncedLevel = _refs[u].teamLevel;
    }

    // ════════════════════════════════════════════════════════════
    //  Farming / referral views (moved out of CoreVaultFarmingReferral)
    // ════════════════════════════════════════════════════════════

    function getRefInfo(address user) external view returns (address referrer, uint8 teamLevel, uint8 validDirectCount, uint8 flags) {
        RefInfo storage r = _refs[user];
        return (r.referrer, r.teamLevel, r.validDirectCount, r.flags);
    }

    function positionCount(address user) external view returns (uint256) {
        return _fvUsers[user].positions.length;
    }

    function getDirectReferralAt(address u, uint256 i) external view returns (address) {
        return _directReferrals[u][i];
    }

    function getDirectReferralsCount(address u) external view returns (uint256) {
        return _directReferrals[u].length;
    }

    /// @dev Pitfall: the original implementation used a **hard-coded storage slot 45** (`keccak256(abi.encode(u, 45))`) to read FvUser --
    ///      that slot number relied on the premise "aToken/bToken/treasury are immutable (occupy no slot)".
    ///      After the module split the three must become ordinary storage variables (immutable cannot be shared via delegatecall),
    ///      so all slot numbers shifted and the hard-coding immediately broke. Hence it now **reads the mapping directly** -- decoupled from the layout, never mismatching.
    function getFarmingRaw(address u) external view returns (
        uint256 invested, uint256 team, uint256 direct, uint256 earnedD, uint256 earnedT
    ) {
        FvUser storage fv = _fvUsers[u];
        return (fv.totalInvestedUsd, fv.totalTeamUsd, fv.totalDirectUsd, fv.earnedDirect, fv.earnedTeam);
    }

    function getPositionRaw(address u, uint256 pid) external view returns (
        uint256, uint256, uint256, uint256
    ) {
        if (pid >= _fvUsers[u].positions.length) return (0, 0, 0, 0);
        Position storage p = _fvUsers[u].positions[pid];
        return (p.principalUsd, p.earnedUsd, p.snapshotDirect, p.snapshotTeam);
    }

    function getPositionFlags(address u, uint256 pid) external view returns (uint8) {
        if (pid >= _fvUsers[u].positions.length) return 0;
        return _fvUsers[u].positions[pid].flags;
    }

    /// @dev Requirement 2.0 section 2: position deposit token (0 = BNB, 1 = FIST)
    function getPositionDepositToken(address u, uint256 pid) external view returns (uint8) {
        if (pid >= _fvUsers[u].positions.length) return 0;
        return _fvUsers[u].positions[pid].depositToken;
    }

    /// @dev Requirement 2.0 section 2: first-order redemption entitlement status
    function getFirstRedeemStatus(address u) external view returns (bool used, bool redeemable, uint8 flags) {
        return _firstRedeemStatus(u);
    }

    function totalFarmingEarned(address u) external view returns (uint256) {
        return _fvUsers[u].totalEarned;
    }

    function getEffectiveLevel(address user) external view returns (uint8) {
        return _effectiveLevel(user);
    }

    function getFvUserMaxAndFlags(address u) external view returns (uint256 maxUsd, uint8 fvFlags) {
        FvUser storage fv = _fvUsers[u];
        return (fv.maxUsd, fv.flags);
    }

    /// @dev Direct referral summary (paginated)
    function getDirectReferralSummary(address user, uint256 offset, uint256 limit) external view returns (
        address[] memory refs,
        uint256[] memory farmingInvested,
        uint256[] memory farmingTeam,
        uint256[] memory stakingTeamA,
        uint256[] memory stakingTeamB
    ) {
        uint256 total = _directReferrals[user].length;
        if (offset >= total) {
            refs = new address[](0);
            farmingInvested = new uint256[](0);
            farmingTeam = new uint256[](0);
            stakingTeamA = new uint256[](0);
            stakingTeamB = new uint256[](0);
            return (refs, farmingInvested, farmingTeam, stakingTeamA, stakingTeamB);
        }
        uint256 end = offset + limit;
        if (end > total) end = total;
        uint256 n = end - offset;
        refs = new address[](n);
        farmingInvested = new uint256[](n);
        farmingTeam = new uint256[](n);
        stakingTeamA = new uint256[](n);
        stakingTeamB = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            address r = _directReferrals[user][offset + i];
            refs[i] = r;
            farmingInvested[i] = _fvUsers[r].totalInvestedUsd;
            farmingTeam[i] = _fvUsers[r].totalTeamUsd;
            stakingTeamA[i] = _modA[r].teamUsd;
            stakingTeamB[i] = _modB[r].teamUsd;
        }
    }

    // ════════════════════════════════════════════════════════════
    //  Price views
    // ════════════════════════════════════════════════════════════
    // Note: `getSwapPrices` is **not declared here** -- it is a required implementation of `IAccounting`, kept in CoreVault
    //   (otherwise the interface would be unsatisfied -> CoreVault becomes abstract). It is not redeclared here to avoid an override conflict.
}
