// SPDX-License-Identifier: MIT
import '@openzeppelin/contracts/utils/math/Math.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';
import '@openzeppelin/contracts/utils/math/SafeCast.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol';

import './interfaces/IOstiumVault.sol';
import './interfaces/IOstiumOpenPnl.sol';
import './interfaces/IOstiumRegistry.sol';
import './interfaces/IOstiumLockedDepositNft.sol';

pragma solidity ^0.8.24;

contract OstiumVault is IOstiumVault, ERC4626Upgradeable, MulticallUpgradeable {
    using Math for uint256;
    using SafeCast for uint256;

    IOstiumRegistry public registry;

    uint64 constant PRECISION_18 = 1e18; // 18 decimals
    uint64 constant MIN_DAILY_ACC_PNL_DELTA = 1e13; // PRECISION_18

    uint16 constant MAX_DISCOUNT_P = 5000; // PRECISION_2 - 50%
    uint16 constant MAX_SUPPLY_INCREASE_DAILY_P = 30000; // PRECISION_2 300% per day

    uint32 constant PRECISION_6 = 1e6; // 6 decimals
    uint32 constant MAX_LOCK_DURATION = 365 days;
    uint32 constant MIN_LOCK_DURATION = 1 weeks;

    uint8 constant PRECISION_2 = 1e2; // 2 decimals

    uint32 constant MAX_SETTLEMENT_LENGTH = 3 days;
    uint32 constant MIN_SETTLEMENT_LENGTH = 10 minutes;
    uint8 constant MAX_WITHDRAW_SETTLEMENT_DELAY = 10;

    uint8[3] __DEPRECATED_WITHDRAW_EPOCHS_LOCKS;

    uint32 public currentEpochStart; //Obsolete
    uint32 public lastMaxSupplyUpdateTs;
    uint32 public lastDailyAccPnlDeltaResetTs;

    uint16 public currentEpoch; // Obsolete
    uint16 public __DEPRECATED_maxDiscountP; // PRECISION_2 (%)
    uint16 public __DEPRECATED_maxDiscountThresholdP; // PRECISION_2 (%)
    uint16 public maxSupplyIncreaseDailyP; // PRECISION_2 (% per day)
    uint16[2] public __DEPRECATED_withdrawLockThresholdsP; // PRECISION_2

    uint256 public currentMaxSupply;
    uint256 public shareToAssetsPrice;
    uint256 public accRewardsPerToken;
    uint256 public lockedDepositsCount;
    uint256 public maxAccOpenPnlDeltaPerToken;
    uint256 public maxDailyAccPnlDeltaPerToken;
    uint256 public __DEPRECATED_currentEpochPositiveOpenPnl;

    int256 public accPnlPerToken;
    int256 public accPnlPerTokenUsed; // (snapshot of accPnlPerToken)
    int256 public dailyAccPnlDeltaPerToken;

    uint256 public __DEPRECATED_totalDeposited;
    int256 public totalClosedPnl;
    uint256 public __DEPRECATED_totalRewards;
    int256 public __DEPRECATED_totalLiability;
    uint256 public totalLockedDiscounts;
    uint256 public totalDiscounts;

    mapping(uint256 depositId => LockedDeposit) public lockedDeposits;
    mapping(address trader => mapping(uint16 withdrawEpoch => uint256)) public __DEPRECATED_withdrawRequests;

    // Settlement Variables
    uint32 public lastSettlementId; // ID of last settlement executed
    uint32 public lastSettlementTs; // timestamp of last settlement
    int256 public lastSettlementOpenPnl; // open PnL at last settlement
    uint32 public maxSettlementInterval; // max time before next settlements can start

    // Total Settlement deposit/withdraw.
    mapping(uint32 settlementId => uint256) public totalAssetsToDeposit;
    mapping(uint32 settlementId => uint256) public totalSharesToWithdraw;
    //shareToAssetsPriceSettlement[settlement][isDeposit]
    mapping(uint32 settlementId => uint256) public settlementShareToAssetsPrice;
    //pendingDepositRequest[owner][settlementId]
    mapping(address owner => mapping(uint32 settlementId => uint256)) public pendingDepositRequest;
    //pendingWithdrawRequest[owner][settlementId]
    mapping(address owner => mapping(uint32 settlementId => uint256)) public pendingWithdrawRequest;

    // additional number of settlements to wait before a withdrawal request can be finalized (0 = no extra delay)
    uint32 public withdrawSettlementDelay;

    // Tracks allocation ratio for oversubscribed settlements (1e18 = 100%)
    mapping(uint32 settlementId => uint256) public settlementAllocationScaleP;

    // Governance-controlled maximum supply cap
    uint256 public supplyCap;

    constructor() {
        _disableInitializers();
    }

    function initialize(
