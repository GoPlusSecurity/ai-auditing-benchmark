// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IMokeRelease.sol";
import "./interfaces/IMokeToken.sol";
import "./interfaces/IMokeAC.sol";
import "./interfaces/IMokeReferral.sol";

interface IPancakePair {
    function getReserves() external view returns (uint112, uint112, uint32);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function sync() external;
}

interface ITokenX {
    function burnFromPair(uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title MokeRelease
 * @dev Per-user linear release from `userFirstSettleDay` (UTC+8 day index).
 *      Accrued factor = min(periodsSinceFirst * dailyRate / 10000, 1) in PRECISION.
 *      Per-period accrual is computed on `(totalQuotaUsdt - claimedSnapshotAtReset)`
 *      so the rate is always dailyRate% of *what remains to vest in the current window*.
 *
 *      Additional deposits behaviour (v4):
 *        - Every new deposit RESTARTS the vesting window from today. Whatever has
 *          already been released (claimed + vested-but-unclaimed pending) is frozen
 *          as `claimedSnapshotAtReset` (consumed by the previous window); only the
 *          still-unvested remainder of the old quota PLUS the new quota vests over a
 *          fresh dailyRate × maxSettleDays cycle from today.
 *        - This removes the v3 path where topping up an already-aged, still-active
 *          window instantly released `quota * currentFactor` (the "账户叠加秒放" bug).
 *
 *      `pendingUsdt` is always capped so claimed + pending never exceeds total quota.
 */
contract MokeRelease is IMokeRelease, Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    IERC20 public mokeToken;
    IMokeAC public mokeAC;
    IMokeReferral public referral;
    address public mokeBnbPair;
    address public bnbUsdtPair;
    address public wbnb;

    // X/MOKE reserve pool
    ITokenX public xToken;
    address public xMokePair;

    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SETTLE_OFFSET = 28800; // UTC+8

    uint256 public dailyRate = 100; // 1% in basis points
    uint256 public settlePeriod = 86400;
    uint256 public maxSettleDays = 30;

    uint256 public claimFee = 0.000341 ether;
    address public feeReceiver;

    uint256 public settledMokePrice;
    uint256 public maxPriceDeviation = 2000;
    uint256 public settleMinInterval = 600; // 10 minutes
    uint256 public lastSettleTime;

    uint256 public referralL1Rate = 2000;
    uint256 public referralL2_10Rate = 500;
    uint256 public maxReferralLayers = 10;
    uint256 public claimInterval = 1 days;

    uint256 public cumulativeReleaseFactor;
    uint256 public lastSettledDay;

    struct UserRelease {
        uint256 totalQuotaUsdt;
        uint256 pendingUsdt;
        uint256 claimedUsdt;
        uint256 lastReleaseFactor;
        uint256 lastClaimTime;
        // Claimed amount at the moment the current vesting window started.
        // 0 for the first-ever window; updated on every "window expired & re-deposit" reset.
        uint256 claimedSnapshotAtReset;
    }

    /// @notice One row for `batchMigrateUsers` (keeps stack shallow for Ignition/solc).
    struct UserMigrateRow {
        address user;
        uint256 totalQuotaUsdt;
        uint256 claimedUsdt;
        uint256 pendingUsdt;
        uint256 lastReleaseFactor;
        uint256 lastClaimTime;
        uint256 firstSettleDay;
        uint256 claimedSnapshotAtReset;
    }

    mapping(address => UserRelease) public userRelease;
    mapping(address => bool) public isSettler;
    /// @dev Day index (same as _trySettle's `today`) when user first received release quota; 0 = none yet
    mapping(address => uint256) public userFirstSettleDay;

    address[] private _allUsers;
    mapping(address => bool) private _isKnownUser;

    event ReleaseQuotaAdded(address indexed user, uint256 quotaUsdt);
    event Settled(uint256 newFactor, uint256 daysPassed);
    event Claimed(address indexed user, uint256 mokeAmount, uint256 usdtValue);
    event DynamicReward(address indexed referrer, address indexed downline, uint256 layer, uint256 acAmount);
    event DailyRateSet(uint256 newRate);
    event ClaimFeeSet(uint256 newFee);
    event FeeReceiverSet(address indexed receiver);
    event SettlerSet(address indexed settler, bool status);
    event PriceSettled(uint256 mokePrice);
    event MaxPriceDeviationSet(uint256 deviation);
    event ReferralRatesSet(uint256 l1Rate, uint256 l2_10Rate);
    event MaxReferralLayersSet(uint256 layers);
    event ClaimIntervalSet(uint256 interval);
    event SettlePeriodSet(uint256 period);
    event MaxSettleDaysSet(uint256 maxDays);
    event EmergencyWithdraw(address indexed token, uint256 amount, address indexed to);
    event DynamicRewardFailed(address indexed referrer, address indexed downline, uint256 layer, uint256 acAmount);
    event UsersMigrated(uint256 count);

    constructor(
        address _mokeToken,
        address _mokeAC,
        address _referral,
        address _feeReceiver
    ) Ownable(msg.sender) {
        mokeToken = IERC20(_mokeToken);
        mokeAC = IMokeAC(_mokeAC);
        referral = IMokeReferral(_referral);
        feeReceiver = _feeReceiver;
    }

    modifier onlyAuthorized() {
        require(isSettler[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }

    // ============ Admin Functions ============

