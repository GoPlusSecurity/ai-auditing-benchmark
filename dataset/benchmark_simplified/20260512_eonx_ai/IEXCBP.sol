// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

interface IPancakeRouter02 {
    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
}

contract IEXCBP is ReentrancyGuard {
    struct Investment {
        uint256 amount;
        uint256 depositTime;
        uint256 lastWithdrawTime;
        uint256 earned;
        bool isLevelVolumeRemoved;
    }

    struct User {
        bool isExist;
        address referrer;
        uint256 activePartners;
        uint256 totalDepositUSD;
        uint256 totalNetworkDepositUSD;
        Investment[] investments;
        uint256[30] levelVolume;
        uint256 lastLevelWithdraw;
        uint256 dailyIncomeRate;
        uint256 accumulatedLevelIncome;
        uint256 lastUplineWithdraw;
        bool isUplineQualified;
        uint256 earnedFromRoi;
        uint256 earnedFromLevel;
        uint256 earnedFromUpline;
        uint256 roiPercentage;
        uint256 currentCapUSD;
        uint256 totalEarnedUSD;
        uint256 availableWalletUSD;
    }

    IERC20 public iexToken;
    IERC20 public usdtToken;
    IPancakeRouter02 public pancakeRouter;

    address public constant COMPANY_ID =
        0x1c093FD10781b1BDa27b8E9c00DF9696686B68Ed;
    address public CONTROLLER_ID =
        0x1FF167F029aD98B9C84eEbdBEc8f6b04d19d96d5;

    uint256 public withdrawal_deduction = 5;

    uint256 public constant QUALIFIED_THRESHOLD = 100 * 1e18;
    uint256 public constant PERC_DIVIDER = 10000;
    uint256 public constant TIME_STEP = 1 days;

    mapping(address => User) public users;
    mapping(address => address[]) public directReferrals;

    uint256[30] public levelPercents = [
        1500, 1000, 700, 500, 400, 300, 200, 100, 200, 200, 200, 200, 200, 200,
        200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 300, 300, 300, 300,
        300
    ];

    uint256[30] public levelSelfInvestment = [
        100 * 1e18, 200 * 1e18, 300 * 1e18, 400 * 1e18, 500 * 1e18, 600 * 1e18,
        700 * 1e18, 800 * 1e18, 900 * 1e18, 900 * 1e18, 900 * 1e18, 900 * 1e18,
        900 * 1e18, 900 * 1e18, 900 * 1e18, 900 * 1e18, 900 * 1e18, 1000 * 1e18,
        1000 * 1e18, 1000 * 1e18, 1000 * 1e18, 1000 * 1e18, 1000 * 1e18,
        1000 * 1e18, 1000 * 1e18, 2000 * 1e18, 2000 * 1e18, 2000 * 1e18,
        2000 * 1e18, 2000 * 1e18
    ];

    uint256[30] public levelDirectsReq = [
        1, 2, 3, 4, 5, 6, 7, 8, 10, 10, 10, 10, 10, 10, 10, 10, 10, 15, 15, 15,
        15, 15, 15, 15, 15, 20, 20, 20, 20, 20
    ];

    event LevelIncome(address indexed user, uint256 amountUSD);
    event UplineIncome(address indexed user, uint256 amountUSD);
    event Withdraw(address indexed user, uint256 amountIex, uint256 valueUSD);
    event TokenDeduction(address indexed user, uint256 amountBurned);

    constructor(address _iexToken, address _usdtAddress, address _router) {
        iexToken = IERC20(_iexToken);
        usdtToken = IERC20(_usdtAddress);
        pancakeRouter = IPancakeRouter02(_router);

        User storage user = users[COMPANY_ID];
        user.isExist = true;
        user.roiPercentage = 100;
        user.currentCapUSD = 1000000000 * 1e18;
        user.lastLevelWithdraw = block.timestamp;
        user.lastUplineWithdraw = block.timestamp;

        uint256 investAmount = 30000 * 1e18;
        user.totalDepositUSD = investAmount;
        user.totalNetworkDepositUSD = investAmount;
        user.investments.push(
            Investment({
                amount: investAmount,
                depositTime: block.timestamp,
                lastWithdrawTime: block.timestamp,
                earned: 0,
                isLevelVolumeRemoved: false
            })
        );
    }

    function withdraw() public nonReentrant {
        User storage user = users[msg.sender];
        require(user.isExist, "User not exist");

        uint256 roiPending = _calculatePendingROI(msg.sender);
        uint256 levelPending = _calculatePendingLevelIncome(msg.sender);
        uint256 uplinePending = _calculatePendingUplineIncome(msg.sender);

        if (roiPending > 0) {
            user.earnedFromRoi += roiPending;
            _distributeRoiToInvestments(msg.sender, user);
        }
        if (levelPending > 0) {
            user.earnedFromLevel += levelPending;
            user.accumulatedLevelIncome = 0;
            emit LevelIncome(msg.sender, levelPending);
        }
        if (uplinePending > 0) {
            user.earnedFromUpline += uplinePending;
            emit UplineIncome(msg.sender, uplinePending);
        }

        user.lastLevelWithdraw = block.timestamp;
        user.lastUplineWithdraw = block.timestamp;

        _creditIncome(user, roiPending + levelPending + uplinePending);

        uint256 payoutUSD = user.availableWalletUSD;
        require(payoutUSD > 0, "No funds");
        user.availableWalletUSD = 0;

        uint256 totalIex = _getIexAmountFromUsd(payoutUSD);
        require(
            iexToken.balanceOf(address(this)) >= totalIex,
            "Contract Low Bal"
        );

        uint256 deduction = (totalIex * withdrawal_deduction) / 100;
        uint256 userAmount = totalIex - deduction;

        if (deduction > 0) {
            _safeTransfer(iexToken, CONTROLLER_ID, deduction);
            emit TokenDeduction(msg.sender, deduction);
        }

        _safeTransfer(iexToken, msg.sender, userAmount);
        emit Withdraw(msg.sender, userAmount, payoutUSD);
    }

    function _isUserQualifiedForCommissions(
        address _user
    ) internal view returns (bool) {
        return users[_user].totalNetworkDepositUSD >= QUALIFIED_THRESHOLD;
    }

    function _safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "Transfer failed"
        );
    }

    function _removeUplineLevelVolume(
        address _referrer,
        uint256 _amount
    ) internal {
        address current = _referrer;
        for (uint256 i = 0; i < 30; i++) {
            if (current == address(0)) break;
            User storage upline = users[current];

            _checkpointLevelIncome(upline);

            upline.levelVolume[i] = (upline.levelVolume[i] >= _amount)
                ? upline.levelVolume[i] - _amount
                : 0;

            _recalculateDailyRate(current);
            current = upline.referrer;
        }
    }

    function _checkpointLevelIncome(User storage user) internal {
        uint256 dt = block.timestamp - user.lastLevelWithdraw;
        if (
            user.totalEarnedUSD < user.currentCapUSD &&
            dt > 0 &&
            user.dailyIncomeRate > 0
        ) {
            user.accumulatedLevelIncome +=
                (user.dailyIncomeRate * dt) /
                TIME_STEP;
        }
        user.lastLevelWithdraw = block.timestamp;
    }

    function _recalculateDailyRate(address _userAddr) internal {
        User storage user = users[_userAddr];

        if (user.totalEarnedUSD >= user.currentCapUSD) {
            user.dailyIncomeRate = 0;
            return;
        }

        uint256 newRate = 0;
        uint256 currentRoi = user.roiPercentage;
        bool allLevelsOpen = user.totalDepositUSD >= 2500e18;

        for (uint256 i = 0; i < 30; i++) {
            bool levelUnlocked = allLevelsOpen ||
                (user.activePartners >= levelDirectsReq[i] &&
                    user.totalNetworkDepositUSD >= levelSelfInvestment[i]);

            if (levelUnlocked) {
                newRate +=
                    (user.levelVolume[i] * currentRoi * levelPercents[i]) /
                    (PERC_DIVIDER * PERC_DIVIDER);
            }
        }
        user.dailyIncomeRate = newRate;
    }

    function _getActiveNetworkROICapital(
        address _userAddr
    ) internal view returns (uint256) {
        User storage user = users[_userAddr];
        if (user.totalEarnedUSD >= user.currentCapUSD) return 0;

        uint256 activeCapital = 0;
        for (uint256 i = 0; i < user.investments.length; i++) {
            if (user.investments[i].amount >= QUALIFIED_THRESHOLD) {
                uint256 maxPerInv = (_userAddr == COMPANY_ID)
                    ? user.investments[i].amount * 20000
                    : user.investments[i].amount * 2;
                if (user.investments[i].earned < maxPerInv) {
                    activeCapital += user.investments[i].amount;
                }
            }
        }
        return activeCapital;
    }

    function _calculatePendingUplineIncome(
        address _user
    ) internal view returns (uint256) {
        User storage user = users[_user];
        if (!user.isUplineQualified) return 0;
        uint256 timeDiff = block.timestamp - user.lastUplineWithdraw;
        if (timeDiff == 0) return 0;

        uint256 totalUplineIncome = 0;
        address[3] memory uplines;
        uplines[0] = user.referrer;
        uplines[1] = (uplines[0] != address(0))
            ? users[uplines[0]].referrer
            : address(0);
        uplines[2] = (uplines[1] != address(0))
            ? users[uplines[1]].referrer
            : address(0);

        uint256[3] memory poolPercents = [uint256(500), 300, 200];

        for (uint i = 0; i < 3; i++) {
            if (uplines[i] != address(0) && uplines[i] != COMPANY_ID) {
                if (!_isUserQualifiedForCommissions(uplines[i])) continue;

                uint256 shareCount = _getQualifiedDownlineCount(uplines[i]);
                if (shareCount > 0) {
                    uint256 activeUplineCap = _getActiveNetworkROICapital(
                        uplines[i]
                    );
                    if (activeUplineCap > 0) {
                        uint256 pool = (activeUplineCap *
                            users[uplines[i]].roiPercentage *
                            poolPercents[i]) / (PERC_DIVIDER * PERC_DIVIDER);
                        totalUplineIncome +=
                            ((pool * timeDiff) / TIME_STEP) /
                            shareCount;
                    }
                }
            }
        }
        return totalUplineIncome;
    }

    function _getQualifiedDownlineCount(
        address _upline
    ) internal view returns (uint256) {
        uint256 count = 0;
        address[] memory directs = directReferrals[_upline];
        for (uint256 i = 0; i < directs.length; i++) {
            if (
                users[directs[i]].isUplineQualified &&
                _isUserQualifiedForCommissions(directs[i])
            ) count++;
        }
        return count;
    }

    function _distributeRoiToInvestments(
        address _userAddr,
        User storage user
    ) internal {
        for (uint256 i = 0; i < user.investments.length; i++) {
            Investment storage inv = user.investments[i];

            uint256 timeDiff = block.timestamp - inv.lastWithdrawTime;
            uint256 maxPerInv = (_userAddr == COMPANY_ID)
                ? inv.amount * 20000
                : inv.amount * 2;

            if (timeDiff > 0 && inv.earned < maxPerInv) {
                uint256 rate = user.roiPercentage;
                uint256 dailyIncome = (inv.amount * rate) / PERC_DIVIDER;
                uint256 generated = (dailyIncome * timeDiff) / TIME_STEP;

                if (inv.earned + generated >= maxPerInv) {
                    generated = maxPerInv - inv.earned;
                    inv.earned += generated;

                    if (
                        !inv.isLevelVolumeRemoved &&
                        inv.amount >= QUALIFIED_THRESHOLD
                    ) {
                        inv.isLevelVolumeRemoved = true;
                        _removeUplineLevelVolume(user.referrer, inv.amount);
                    }
                } else {
                    inv.earned += generated;
                }
                inv.lastWithdrawTime = block.timestamp;
            } else if (
                inv.earned >= maxPerInv &&
                !inv.isLevelVolumeRemoved &&
                inv.amount >= QUALIFIED_THRESHOLD
            ) {
                inv.isLevelVolumeRemoved = true;
                _removeUplineLevelVolume(user.referrer, inv.amount);
            }
        }
    }

    function _calculatePendingROI(
        address _userAddr
    ) internal view returns (uint256) {
        User storage user = users[_userAddr];
        if (user.totalEarnedUSD >= user.currentCapUSD) return 0;
        uint256 remainingGlobalCap = user.currentCapUSD - user.totalEarnedUSD;
        uint256 totalPendingROI = 0;

        for (uint256 i = 0; i < user.investments.length; i++) {
            Investment storage inv = user.investments[i];

            uint256 maxPerInv = (_userAddr == COMPANY_ID)
                ? inv.amount * 20000
                : inv.amount * 2;

            if (inv.earned < maxPerInv) {
                uint256 timeDiff = block.timestamp - inv.lastWithdrawTime;
                uint256 rate = user.roiPercentage;
                uint256 generated = (inv.amount * rate * timeDiff) /
                    (PERC_DIVIDER * TIME_STEP);
                if (inv.earned + generated > maxPerInv)
                    generated = maxPerInv - inv.earned;
                totalPendingROI += generated;
            }
        }
        return
            (totalPendingROI > remainingGlobalCap)
                ? remainingGlobalCap
                : totalPendingROI;
    }

    function _creditIncome(User storage user, uint256 _amount) internal {
        if (_amount == 0) return;
        bool wasUnderCap = user.totalEarnedUSD < user.currentCapUSD;
        if (user.totalEarnedUSD + _amount <= user.currentCapUSD) {
            user.totalEarnedUSD += _amount;
            user.availableWalletUSD += _amount;
        } else {
            uint256 remaining = user.currentCapUSD - user.totalEarnedUSD;
            user.totalEarnedUSD += remaining;
            user.availableWalletUSD += remaining;
        }
        if (wasUnderCap && user.totalEarnedUSD >= user.currentCapUSD) {
            user.dailyIncomeRate = 0;
        }
    }

    function _calculatePendingLevelIncome(
        address _userAddr
    ) internal view returns (uint256) {
        User storage user = users[_userAddr];
        uint256 pending = user.accumulatedLevelIncome;

        if (user.totalEarnedUSD >= user.currentCapUSD) return pending;

        uint256 dt = block.timestamp - user.lastLevelWithdraw;
        return pending + ((user.dailyIncomeRate * dt) / TIME_STEP);
    }

    function _getIexAmountFromUsd(
        uint256 _usdAmount
    ) internal view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(usdtToken);
        path[1] = address(iexToken);
        return pancakeRouter.getAmountsOut(_usdAmount, path)[1];
    }
}
