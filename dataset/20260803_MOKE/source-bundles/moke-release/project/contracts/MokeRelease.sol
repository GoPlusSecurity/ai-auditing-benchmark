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

    function setMokeToken(address _mokeToken) external onlyOwner {
        require(_mokeToken != address(0), "Invalid token");
        mokeToken = IERC20(_mokeToken);
    }

    function setMokeAC(address _mokeAC) external onlyOwner {
        require(_mokeAC != address(0), "Invalid AC");
        mokeAC = IMokeAC(_mokeAC);
    }

    function setReferral(address _referral) external onlyOwner {
        require(_referral != address(0), "Invalid referral");
        referral = IMokeReferral(_referral);
    }

    function setSettler(address settler, bool status) external onlyOwner {
        isSettler[settler] = status;
        emit SettlerSet(settler, status);
    }

    function setDailyRate(uint256 _rate) external override onlyOwner {
        _trySettle();
        dailyRate = _rate;
        emit DailyRateSet(_rate);
    }

    function setClaimFee(uint256 _fee) external onlyOwner {
        claimFee = _fee;
        emit ClaimFeeSet(_fee);
    }

    function setFeeReceiver(address _receiver) external onlyOwner {
        require(_receiver != address(0), "Invalid receiver");
        feeReceiver = _receiver;
        emit FeeReceiverSet(_receiver);
    }

    function setReferralRates(uint256 _l1Rate, uint256 _l2_10Rate) external onlyOwner {
        require(_l1Rate <= 5000 && _l2_10Rate <= 2000, "Rate too high");
        referralL1Rate = _l1Rate;
        referralL2_10Rate = _l2_10Rate;
        emit ReferralRatesSet(_l1Rate, _l2_10Rate);
    }

    function setMaxReferralLayers(uint256 _layers) external onlyOwner {
        require(_layers > 0 && _layers <= 20, "Invalid layers");
        maxReferralLayers = _layers;
        emit MaxReferralLayersSet(_layers);
    }

    function setClaimInterval(uint256 _interval) external onlyOwner {
        claimInterval = _interval;
        emit ClaimIntervalSet(_interval);
    }

    function setPairs(address _mokeBnbPair, address _bnbUsdtPair, address _wbnb) external onlyOwner {
        require(_wbnb != address(0), "Invalid WBNB");
        mokeBnbPair = _mokeBnbPair;
        bnbUsdtPair = _bnbUsdtPair;
        wbnb = _wbnb;
    }

    function setXToken(address _xToken) external onlyOwner {
        require(_xToken != address(0), "Invalid X token");
        xToken = ITokenX(_xToken);
    }

    function setXMokePair(address _pair) external onlyOwner {
        require(_pair != address(0), "Invalid pair");
        xMokePair = _pair;
    }

    function setMaxPriceDeviation(uint256 _deviation) external onlyOwner {
        require(_deviation <= 5000, "Max 50%");
        maxPriceDeviation = _deviation;
        emit MaxPriceDeviationSet(_deviation);
    }

    function setSettleMinInterval(uint256 _interval) external onlyOwner {
        settleMinInterval = _interval;
    }

    function setSettlePeriod(uint256 _period) external onlyOwner {
        require(_period >= 60, "Min 60s");
        _trySettle();
        settlePeriod = _period;
        if (lastSettledDay > 0) {
            lastSettledDay = (block.timestamp + SETTLE_OFFSET) / _period;
        }
        emit SettlePeriodSet(_period);
    }

    function setMaxSettleDays(uint256 _maxDays) external onlyOwner {
        require(_maxDays >= 1 && _maxDays <= 365, "Invalid");
        maxSettleDays = _maxDays;
        emit MaxSettleDaysSet(_maxDays);
    }

    function setSettledMokePrice(uint256 _price) external onlyOwner {
        require(_price > 0, "Invalid price");
        settledMokePrice = _price;
        emit PriceSettled(_price);
    }

    function setCumulativeReleaseFactor(uint256 _factor) external onlyOwner {
        require(_factor < PRECISION, "Factor must < 1e18");
        cumulativeReleaseFactor = _factor;
    }

    function setLastSettledDay(uint256 _day) external onlyOwner {
        lastSettledDay = _day;
    }

    function resetUserRelease(address user) external onlyOwner {
        _snapshotUser(user);
        UserRelease storage ur = userRelease[user];
        ur.pendingUsdt = 0;
        ur.claimedUsdt = 0;
        ur.lastClaimTime = 0;
        ur.claimedSnapshotAtReset = 0;
    }

    function setUserQuota(address user, uint256 quotaUsdt) external onlyOwner {
        _trackUser(user);
        _trySettle();
        _snapshotUser(user);

        UserRelease storage ur2 = userRelease[user];
        if (quotaUsdt > 0) {
            uint256 today = (block.timestamp + SETTLE_OFFSET) / settlePeriod;
            userFirstSettleDay[user] = today;
            ur2.lastReleaseFactor = 0;
            // Owner override starts a fresh window. Already-claimed AND already-vested
            // (but not yet claimed) amounts count as "consumed by previous window".
            ur2.claimedSnapshotAtReset = ur2.claimedUsdt + ur2.pendingUsdt;
        }

        ur2.totalQuotaUsdt = quotaUsdt;
        _clampPendingUser(user);
    }

    /// @notice Owner-only migration of user rows (e.g. new release contract). Caps pending per quota.
    function batchMigrateUsers(UserMigrateRow[] calldata rows) external onlyOwner {
        uint256 n = rows.length;
        require(n > 0 && n <= 100, "Batch size");
        for (uint256 i; i < n; ) {
            UserMigrateRow calldata r = rows[i];
            require(r.user != address(0), "Zero user");
            _trackUser(r.user);
            userFirstSettleDay[r.user] = r.firstSettleDay;
            UserRelease storage ur = userRelease[r.user];
            ur.totalQuotaUsdt = r.totalQuotaUsdt;
            ur.claimedUsdt = r.claimedUsdt;
            ur.pendingUsdt = r.pendingUsdt;
            ur.lastReleaseFactor = r.lastReleaseFactor;
            ur.lastClaimTime = r.lastClaimTime;
            ur.claimedSnapshotAtReset = r.claimedSnapshotAtReset;
            _clampPendingUser(r.user);
            unchecked {
                ++i;
            }
        }
        emit UsersMigrated(n);
    }

    // ============ Settlement (O(1) global) ============

    function settle() external override {
        require(
            isSettler[msg.sender] || msg.sender == owner() || msg.sender == tx.origin,
            "Only authorized or EOA"
        );
        require(
            block.timestamp >= lastSettleTime + settleMinInterval,
            "Settle cooldown"
        );
        _trySettle();
        uint256 price = getMokeUsdtPrice();
        if (price > 0) {
            settledMokePrice = price;
            lastSettleTime = block.timestamp;
            emit PriceSettled(price);
        }
    }

    function _trySettle() internal {
        uint256 today = (block.timestamp + SETTLE_OFFSET) / settlePeriod;
        if (lastSettledDay == 0) {
            lastSettledDay = today;
            return;
        }
        if (today <= lastSettledDay) return;

        uint256 daysPassed = today - lastSettledDay;
        lastSettledDay = today;
        emit Settled(cumulativeReleaseFactor, daysPassed);
    }

    function _accruedReleaseFactor(address user) internal view returns (uint256) {
        uint256 firstDay = userFirstSettleDay[user];
        if (firstDay == 0) return 0;
        uint256 today = (block.timestamp + SETTLE_OFFSET) / settlePeriod;
        if (today <= firstDay) return 0;
        uint256 periods = today - firstDay;
        if (periods > maxSettleDays) periods = maxSettleDays;
        uint256 f = periods * PRECISION * dailyRate / BASIS_POINTS;
        if (f > PRECISION) return PRECISION;
        return f;
    }

    function _snapshotUser(address user) internal {
        UserRelease storage ur = userRelease[user];
        uint256 currentFactor = _accruedReleaseFactor(user);
        if (currentFactor > ur.lastReleaseFactor) {
            uint256 delta = currentFactor - ur.lastReleaseFactor;
            uint256 vestBase = ur.totalQuotaUsdt > ur.claimedSnapshotAtReset
                ? ur.totalQuotaUsdt - ur.claimedSnapshotAtReset
                : 0;
            if (vestBase > 0) {
                ur.pendingUsdt += vestBase * delta / PRECISION;
            }
        }
        ur.lastReleaseFactor = currentFactor;
        _clampPendingUser(user);
    }

    /// @dev Ensures released (pending + claimed) never exceeds total quota.
    function _clampPendingUser(address user) internal {
        UserRelease storage ur = userRelease[user];
        uint256 cap = ur.totalQuotaUsdt > ur.claimedUsdt ? ur.totalQuotaUsdt - ur.claimedUsdt : 0;
        if (ur.pendingUsdt > cap) {
            ur.pendingUsdt = cap;
        }
    }

    // ============ Core Functions ============

    function addReleaseQuota(address user, uint256 quotaUsdt) external override onlyAuthorized {
        _trackUser(user);
        _trySettle();

        // Snapshot first so any already-accrued (but unsnapshotted) portion of the
        // existing quota is captured into `pendingUsdt` before we change anything.
        _snapshotUser(user);

        UserRelease storage ur = userRelease[user];

        if (quotaUsdt > 0) {
            // v4: EVERY deposit restarts the vesting window from today.
            // Everything already released (claimed + vested-but-unclaimed pending) is
            // frozen as "consumed by the previous window"; only the still-unvested
            // remainder of the old quota plus the new quota vests from today, i.e.:
            //   vestBase = totalQuotaUsdt - claimedSnapshotAtReset
            //            = (oldUnvestedRemainder) + quotaUsdt
            // This removes the v3 "top-up onto an aged active window instantly releases
            // quota * currentFactor" behaviour.
            uint256 today = (block.timestamp + SETTLE_OFFSET) / settlePeriod;
            userFirstSettleDay[user] = today;
            ur.lastReleaseFactor = 0;
            ur.claimedSnapshotAtReset = ur.claimedUsdt + ur.pendingUsdt;

            ur.totalQuotaUsdt += quotaUsdt;
            _clampPendingUser(user);
        }

        emit ReleaseQuotaAdded(user, quotaUsdt);
    }

    function claim() external payable override nonReentrant whenNotPaused {
        require(msg.value >= claimFee, "Insufficient claim fee");

        _trySettle();
        _snapshotUser(msg.sender);

        UserRelease storage ur = userRelease[msg.sender];
        require(ur.pendingUsdt > 0, "Nothing to claim");
        require(
            block.timestamp >= ur.lastClaimTime + claimInterval,
            "Claim interval not reached"
        );

        if (claimFee > 0 && feeReceiver != address(0)) {
            (bool sent,) = payable(feeReceiver).call{value: claimFee}("");
            require(sent, "Fee transfer failed");
        }
        uint256 refund = msg.value - claimFee;
        if (refund > 0) {
            (bool refunded,) = payable(msg.sender).call{value: refund}("");
            require(refunded, "Refund failed");
        }

        uint256 pendingUsdt = ur.pendingUsdt;
        require(settledMokePrice > 0, "Price not settled");

        uint256 livePrice = getMokeUsdtPrice();
        if (livePrice > 0) {
            uint256 deviation = livePrice > settledMokePrice
                ? (livePrice - settledMokePrice) * BASIS_POINTS / settledMokePrice
                : (settledMokePrice - livePrice) * BASIS_POINTS / settledMokePrice;
            require(deviation <= maxPriceDeviation, "Price deviation too high");
        }

        uint256 mokeAmount = pendingUsdt * PRECISION / settledMokePrice;

        require(address(xToken) != address(0), "X token not set");
        require(xMokePair != address(0), "X/MOKE pair not set");

        uint256 mokeBalBefore = mokeToken.balanceOf(xMokePair);
        require(mokeBalBefore >= mokeAmount, "Insufficient MOKE in reserve pool");

        ur.pendingUsdt = 0;
        ur.claimedUsdt += pendingUsdt;
        ur.lastClaimTime = block.timestamp;

        // 1. Extract MOKE from X/MOKE reserve pool → user
        IMokeToken(address(mokeToken)).releaseFromPair(msg.sender, mokeAmount);

        // 2. Burn proportional X to maintain ratio
        uint256 xBal = xToken.balanceOf(xMokePair);
        if (xBal > 0 && mokeBalBefore > 0) {
            uint256 xAmount = mokeAmount * xBal / mokeBalBefore;
            if (xAmount > 0) {
                xToken.burnFromPair(xAmount);
            }
        }

        // 3. Sync pair reserves after balance changes
        IPancakePair(xMokePair).sync();

        // 4. Mark released balance
        IMokeToken(address(mokeToken)).addReleasedBalance(msg.sender, mokeAmount);

        // 5. Referral rewards
        _distributeDynamicReward(msg.sender, pendingUsdt);

        emit Claimed(msg.sender, mokeAmount, pendingUsdt);
    }

    // ============ Referral Rewards ============

    function _distributeDynamicReward(address user, uint256 claimedUsdtVal) internal {
        address current = referral.getReferrer(user);

        for (uint256 i = 0; i < maxReferralLayers && current != address(0); i++) {
            uint256 effectiveCount = _countEffectiveReferrals(current);
            if (effectiveCount <= i) {
                current = referral.getReferrer(current);
                continue;
            }

            uint256 rate = (i == 0) ? referralL1Rate : referralL2_10Rate;
            uint256 acReward = claimedUsdtVal * rate / BASIS_POINTS;

            if (acReward > 0) {
                try mokeAC.mint(current, acReward) {
                    emit DynamicReward(current, user, i + 1, acReward);
                } catch {
                    emit DynamicRewardFailed(current, user, i + 1, acReward);
                }
            }

            current = referral.getReferrer(current);
        }
    }

    function _countEffectiveReferrals(address user) internal view returns (uint256) {
        return referral.effectiveReferralCount(user);
    }

    // ============ Price Oracle ============

    function getMokeUsdtPrice() public view returns (uint256) {
        if (mokeBnbPair == address(0) || bnbUsdtPair == address(0) || wbnb == address(0)) return 0;

        uint256 mokeBnbPrice = _getPriceFromPair(mokeBnbPair, address(mokeToken));
        uint256 bnbUsdtPrice = _getPriceFromPair(bnbUsdtPair, wbnb);

        if (mokeBnbPrice == 0 || bnbUsdtPrice == 0) return 0;
        return mokeBnbPrice * bnbUsdtPrice / PRECISION;
    }

    function _getPriceFromPair(address pairAddr, address tokenAddr) internal view returns (uint256) {
        IPancakePair pairContract = IPancakePair(pairAddr);
        (uint112 reserve0, uint112 reserve1,) = pairContract.getReserves();
        if (reserve0 == 0 || reserve1 == 0) return 0;

        address token0 = pairContract.token0();

        if (token0 == tokenAddr) {
            return uint256(reserve1) * PRECISION / uint256(reserve0);
        } else {
            return uint256(reserve0) * PRECISION / uint256(reserve1);
        }
    }

    // ============ View Functions ============

    function getPendingRelease(address user) external view override returns (uint256 mokeAmount) {
        uint256 pending = _pendingUsdtCapped(user);
        if (pending == 0) return 0;
        uint256 price = settledMokePrice > 0 ? settledMokePrice : getMokeUsdtPrice();
        if (price == 0) return 0;
        return pending * PRECISION / price;
    }

    function getUserRelease(address user) external view override returns (
        uint256 totalQuota,
        uint256 releasedQuota,
        uint256 pendingUsdt,
        uint256 lastClaimTime
    ) {
        UserRelease storage ur = userRelease[user];
        uint256 pending = _pendingUsdtCapped(user);
        uint256 released = ur.claimedUsdt + pending;
        return (ur.totalQuotaUsdt, released, pending, ur.lastClaimTime);
    }

    /// @dev Pending USDT including not-yet-snapshotted accrual, capped by remaining quota.
    function _pendingUsdtCapped(address user) internal view returns (uint256) {
        UserRelease storage ur = userRelease[user];
        uint256 currentFactor = _accruedReleaseFactor(user);
        uint256 pending = ur.pendingUsdt;
        if (currentFactor > ur.lastReleaseFactor) {
            uint256 vestBase = ur.totalQuotaUsdt > ur.claimedSnapshotAtReset
                ? ur.totalQuotaUsdt - ur.claimedSnapshotAtReset
                : 0;
            if (vestBase > 0) {
                uint256 delta = currentFactor - ur.lastReleaseFactor;
                pending += vestBase * delta / PRECISION;
            }
        }
        uint256 cap = ur.totalQuotaUsdt > ur.claimedUsdt ? ur.totalQuotaUsdt - ur.claimedUsdt : 0;
        return pending > cap ? cap : pending;
    }

    // ============ User Tracking ============

    function _trackUser(address user) internal {
        if (!_isKnownUser[user]) {
            _isKnownUser[user] = true;
            _allUsers.push(user);
        }
    }

    function getUserCount() external view returns (uint256) {
        return _allUsers.length;
    }

    /// @notice Enumerate tracked users (same order as internal `_allUsers`) for off-chain migration.
    function getUserAt(uint256 index) external view returns (address) {
        require(index < _allUsers.length, "Index OOB");
        return _allUsers[index];
    }

    // ============ Emergency / Pausable ============

    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            (bool sent,) = payable(owner()).call{value: amount}("");
            require(sent, "BNB transfer failed");
        } else {
            IERC20(token).safeTransfer(owner(), amount);
        }
        emit EmergencyWithdraw(token, amount, owner());
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    receive() external payable {}
}
