// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBurnable {
    function burn(uint256 amount) external;
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

abstract contract Ownable {
    address private _owner;
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    constructor() {
        _transferOwnership(msg.sender);
    }
    modifier onlyOwner() {
        _checkOwner();
        _;
    }
    function owner() public view virtual returns (address) {
        return _owner;
    }
    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IPancakeRouter02 {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
}

contract IEXCBP is ReentrancyGuard, Ownable {
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
        uint256 partnersCount;
        uint256 activePartners;
        uint256 totalDepositUSD;
        uint256 totalNetworkDepositUSD;
        Investment[] investments;
        uint256 totalTeamVolume;
        uint256 totalDirectBusiness;
        uint256[30] levelVolume;
        uint256 joiningTime;
        uint256 activationTime;
        uint256 lastLevelWithdraw;
        uint256 dailyIncomeRate;
        uint256 accumulatedLevelIncome;
        uint256 lastRoiWithdraw;
        uint256 lastUplineWithdraw;
        bool isUplineQualified;
        bool[17] fundsReceived;
        uint256 salaryRank;
        uint256 lastSalaryWithdraw;
        uint256 salarySnapshotLegBC;
        uint256 salaryCycleTimestamp;
        uint256 rankMonthsPaid;
        uint256 earnedFromRoi;
        uint256 earnedFromDirect;
        uint256 earnedFromLevel;
        uint256 earnedFromUpline;
        uint256 earnedFromSalary;
        uint256 earnedFromFunds;
        uint256 roiPercentage;
        uint256 incomeCapMultiplier;
        uint256 currentCapUSD;
        uint256 totalEarnedUSD;
        uint256 availableWalletUSD;
        string nickname;
        uint256 fundRank;
    }

    IERC20 public iexToken;
    IERC20 public usdtToken;
    IPancakeRouter02 public pancakeRouter;

    address public constant USDT_ADDRESS = 0x55d398326f99059fF775485246999027B3197955;
    address public constant COMPANY_ID = 0x1c093FD10781b1BDa27b8E9c00DF9696686B68Ed;
    address public CONTROLLER_ID = 0x1FF167F029aD98B9C84eEbdBEc8f6b04d19d96d5;

    address public constant DEV_ADDRESS = 0x18B8d73562C57551544761CdffFA444C8be8013F;
    uint256 public uplineDepth = 300;
    uint256 public uplineRewardDepth = 300;
    uint256 public withdrawal_deduction = 5;

    uint256 public MIN_DEPOSIT_USD = 100 * 1e18;
    uint256 public constant QUALIFIED_THRESHOLD = 100 * 1e18;

    uint256 public constant MAX_DIRECTS = 1000;
    uint256 public constant MAX_INVESTMENTS = 100;
    uint256 public constant PERC_DIVIDER = 10000;
    uint256 public constant TIME_STEP = 1 days;
    uint256 public constant MONTH_STEP = 30 days;
    uint256 public constant MAX_SALARY_MONTHS = 6;
    uint256 public constant BASE_ROI = 70;
    mapping(address => mapping(uint256 => uint256)) public rankCount;

    mapping(address => User) public users;
    mapping(address => address[]) public directReferrals;
    mapping(string => address) public nicknameToAddress;

    uint256[30] public levelPercents = [
        1500,
        1000,
        700,
        500,
        400,
        300,
        200,
        100,
        200,
        200,
        200,
        200,
        200,
        200,
        200,
        200,
        200,
        200,
        200,
        200,
        200,
        200,
        200,
        200,
        200,
        300,
        300,
        300,
        300,
        300
    ];

    uint256[30] public levelSelfInvestment = [
        100 * 1e18,
        200 * 1e18,
        300 * 1e18,
        400 * 1e18,
        500 * 1e18,
        600 * 1e18,
        700 * 1e18,
        800 * 1e18,
        900 * 1e18,
        900 * 1e18,
        900 * 1e18,
        900 * 1e18,
        900 * 1e18,
        900 * 1e18,
        900 * 1e18,
        900 * 1e18,
        900 * 1e18,
        1000 * 1e18,
        1000 * 1e18,
        1000 * 1e18,
        1000 * 1e18,
        1000 * 1e18,
        1000 * 1e18,
        1000 * 1e18,
        1000 * 1e18,
        2000 * 1e18,
        2000 * 1e18,
        2000 * 1e18,
        2000 * 1e18,
        2000 * 1e18
    ];

    uint256[30] public levelDirectsReq = [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        10,
        10,
        10,
        10,
        10,
        10,
        10,
        10,
        10,
        15,
        15,
        15,
        15,
        15,
        15,
        15,
        15,
        20,
        20,
        20,
        20,
        20
    ];

    uint256[10] public salaryReqLeg = [
        1000 * 1e18,
        4000 * 1e18,
        12000 * 1e18,
        40000 * 1e18,
        100000 * 1e18,
        300000 * 1e18,
        800000 * 1e18,
        2000000 * 1e18,
        6000000 * 1e18,
        20000000 * 1e18
    ];
    uint256[10] public salaryReqRest = [
        500 * 1e18,
        2000 * 1e18,
        6000 * 1e18,
        20000 * 1e18,
        50000 * 1e18,
        150000 * 1e18,
        400000 * 1e18,
        1000000 * 1e18,
        3000000 * 1e18,
        10000000 * 1e18
    ];
    uint256[10] public salaryIncome = [
        50 * 1e18,
        250 * 1e18,
        750 * 1e18,
        2500 * 1e18,
        6250 * 1e18,
        18750 * 1e18,
        50000 * 1e18,
        150000 * 1e18,
        450000 * 1e18,
        1000000 * 1e18
    ];

    uint256[17] public fundLegReq = [
        2000 * 1e18,
        2000 * 1e18,
        4000 * 1e18,
        8000 * 1e18,
        16000 * 1e18,
        32000 * 1e18,
        64000 * 1e18,
        128000 * 1e18,
        250000 * 1e18,
        500000 * 1e18,
        1000000 * 1e18,
        2000000 * 1e18,
        4000000 * 1e18,
        6000000 * 1e18,
        10000000 * 1e18,
        15000000 * 1e18,
        20000000 * 1e18
    ];

    uint256[17] public fundReward = [
        200 * 1e18,
        400 * 1e18,
        800 * 1e18,
        1600 * 1e18,
        3200 * 1e18,
        6400 * 1e18,
        12800 * 1e18,
        25600 * 1e18,
        50000 * 1e18,
        100000 * 1e18,
        200000 * 1e18,
        500000 * 1e18,
        1000000 * 1e18,
        1200000 * 1e18,
        2000000 * 1e18,
        4000000 * 1e18,
        5000000 * 1e18
    ];

    uint256[17] public fundTimeLimit = [
        30 days,
        60 days,
        90 days,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0
    ];

    event Registration(
        address indexed user,
        address indexed referrer,
        string nickname
    );
    event Deposit(address indexed user, uint256 usdtAmount, uint256 IexBought);
    event DirectBonus(
        address indexed referrer,
        address indexed user,
        uint256 amountUSD
    );
    event LevelIncome(address indexed user, uint256 amountUSD);
    event UplineIncome(address indexed user, uint256 amountUSD);
    event SalaryIncome(
        address indexed user,
        uint256 rankIndex,
        uint256 amountUSD
    );
    event FundReward(
        address indexed user,
        uint256 fundIndex,
        uint256 amountUSD
    );
    event BoosterUpgrade(address indexed user, uint256 newRoi, uint256 newCap);
    event Withdraw(address indexed user, uint256 amountIex, uint256 valueUSD);
    event TokenDeduction(address indexed user, uint256 amountBurned);

    constructor(address _iexToken, address _usdtAddress, address _router) {
        iexToken = IERC20(_iexToken);
        usdtToken = IERC20(_usdtAddress);
        pancakeRouter = IPancakeRouter02(_router);

        User storage user = users[COMPANY_ID];
        user.isExist = true;
        user.roiPercentage = 100;

        user.incomeCapMultiplier = 3;
        user.currentCapUSD = 1000000000 * 1e18;

        user.activationTime = block.timestamp;
        user.joiningTime = block.timestamp;
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

    function updateDepth(uint256 _newUplineDepth, uint256 _newUplineRewardDepth) external {
        require(msg.sender == DEV_ADDRESS, "Only Developer");
        uplineDepth = _newUplineDepth;
        uplineRewardDepth = _newUplineRewardDepth;
    }

    function updateControllerAddress(address _newControllerAddress) external {
        require(msg.sender == DEV_ADDRESS, "Only Developer");
        CONTROLLER_ID = _newControllerAddress;
    }

    function updateDeduction(uint256 _newDeduction) external {
        require(msg.sender == DEV_ADDRESS, "Only Developer");
        require(_newDeduction >= 1 && _newDeduction <= 10, "Must be 1-10%");

        withdrawal_deduction = _newDeduction;
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

    function _safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferFrom failed"
        );
    }

    function getLegVolumes(
        address _user
    ) public view returns (uint256 legA, uint256 legB, uint256 legC) {
        address[] memory directs = directReferrals[_user];
        uint256 sumAll = 0;

        for (uint256 i = 0; i < directs.length; i++) {
            if (_isUserQualifiedForCommissions(directs[i])) {
                uint256 legVol = users[directs[i]].totalNetworkDepositUSD +
                    users[directs[i]].totalTeamVolume;
                sumAll += legVol;

                if (legVol > legA) {
                    legB = legA;
                    legA = legVol;
                } else if (legVol > legB) {
                    legB = legVol;
                }
            }
        }

        legC = (sumAll > (legA + legB)) ? sumAll - (legA + legB) : 0;
    }

    function _updateUplineRankCounts(address userAddr, uint256 rank) internal {
        uint256 depth = 0;
        address upline = users[userAddr].referrer;

        while (upline != address(0) && depth < uplineRewardDepth) {
            rankCount[upline][rank] += 1;
            upline = users[upline].referrer;
            depth++;
        }
    }

    function getLegVolumesForReward(
        address _user
    ) public view returns (uint256 legA, uint256 legB) {
        address[] memory directs = directReferrals[_user];

        for (uint256 i = 0; i < directs.length; i++) {
            if (!_isUserQualifiedForCommissions(directs[i])) continue;

            uint256 legVol = users[directs[i]].totalNetworkDepositUSD +
                users[directs[i]].totalTeamVolume;

            if (legVol > legA) {
                legB += legA;
                legA = legVol;
            } else {
                legB += legVol;
            }
        }
    }

    function getAchieverCountPerLeg(
        address _user,
        uint256 requiredRank
    ) public view returns (uint256 bigLegCount, uint256 otherLegCount) {
        address[] memory directs = directReferrals[_user];

        uint256 maxVol;
        address maxDirect;

        for (uint256 i = 0; i < directs.length; i++) {
            address d = directs[i];
            if (!_isUserQualifiedForCommissions(d)) continue;

            uint256 vol = users[d].totalNetworkDepositUSD +
                users[d].totalTeamVolume;

            if (vol > maxVol) {
                maxVol = vol;
                maxDirect = d;
            }
        }

        for (uint256 i = 0; i < directs.length; i++) {
            address d = directs[i];
            if (!_isUserQualifiedForCommissions(d)) continue;

            uint256 achievers = rankCount[d][requiredRank];

            if (users[d].fundsReceived[requiredRank]) {
                achievers += 1;
            }

            if (d == maxDirect) {
                bigLegCount += achievers;
            } else {
                otherLegCount += achievers;
            }
        }
    }

    function _processFundReward(address _userAddr) internal {
        User storage user = users[_userAddr];

        if (user.activationTime == 0) return;
        if (!_isUserQualifiedForCommissions(_userAddr)) return;

        (uint256 legA, uint256 legB) = getLegVolumesForReward(_userAddr);

        uint256 rewardWithCap;
        uint256 rewardNoCap;
        uint256 timeElapsed = block.timestamp - user.activationTime;

        for (uint256 i = 0; i < 17; i++) {
            if (user.fundsReceived[i]) continue;

            if (fundTimeLimit[i] > 0 && timeElapsed > fundTimeLimit[i])
                continue;

            bool legMet = true;
            if (i == 0) {
                uint256 req = fundLegReq[0];
                if (legA < req || legB < req) {
                    legMet = false;
                }
            }
            if (!legMet) continue;
            
            bool achieverMet = true;
            if (i >= 1) {
                (uint256 bigCount, uint256 otherCount) = getAchieverCountPerLeg(
                    _userAddr,
                    i - 1
                );
                achieverMet = (bigCount >= 1 && otherCount >= 1);
            }
            if (!achieverMet) continue;

            user.fundsReceived[i] = true;
            user.earnedFromFunds += fundReward[i];

            if (user.fundRank < i) {
                user.fundRank = i;
            }

            _updateUplineRankCounts(_userAddr, i);
            emit FundReward(_userAddr, i, fundReward[i]);

            if (i == 0) {
                rewardWithCap += fundReward[i];
            } else {
                rewardNoCap += fundReward[i];
            }
        }

        if (rewardNoCap > 0) {
            user.availableWalletUSD += rewardNoCap;
        }
        if (rewardWithCap > 0) {
            _creditIncome(user, rewardWithCap);
        }
    }

    function getUserAchieverProgress(
        address _user
    )
        public
        view
        returns (
            uint256[17] memory bigLegCounts,
            uint256[17] memory otherLegCounts,
            uint256[17] memory requiredCount,
            bool[17] memory legVolMet,
            bool[17] memory rankUnlocked
        )
    {
        address[] memory directs = directReferrals[_user];
        (uint256 legA, uint256 legB) = getLegVolumesForReward(_user);

        uint256 maxVol;
        address maxDirect;
        for (uint256 i = 0; i < directs.length; i++) {
            address d = directs[i];
            if (!_isUserQualifiedForCommissions(d)) continue;
            uint256 vol = users[d].totalNetworkDepositUSD +
                users[d].totalTeamVolume;
            if (vol > maxVol) {
                maxVol = vol;
                maxDirect = d;
            }
        }

        for (uint256 i = 0; i < 17; i++) {
            requiredCount[i] = (i == 0) ? 0 : 1;

            if (i == 0) {
                legVolMet[i] = (legA >= fundLegReq[0] && legB >= fundLegReq[0]);
            } else {
                legVolMet[i] = true;
            }

            if (i == 0) {
                bigLegCounts[i] = 0;
                otherLegCounts[i] = 0;
                rankUnlocked[i] = legVolMet[i];
                continue;
            }

            uint256 bigCount;
            uint256 otherCount;

            for (uint256 j = 0; j < directs.length; j++) {
                address d = directs[j];
                if (!_isUserQualifiedForCommissions(d)) continue;

                uint256 achievers = rankCount[d][i - 1];

                if (users[d].fundsReceived[i - 1]) {
                    achievers += 1;
                }

                if (d == maxDirect) {
                    bigCount += achievers;
                } else {
                    otherCount += achievers;
                }
            }

            bigLegCounts[i] = bigCount;
            otherLegCounts[i] = otherCount;
            rankUnlocked[i] = legVolMet[i] && bigCount >= 1 && otherCount >= 1;
        }
    }

    function register(address _referrer, string calldata _nickname) public {
        require(!users[msg.sender].isExist, "User exist");
        require(users[_referrer].isExist, "Referrer not exist");
        require(
            users[_referrer].totalDepositUSD > 0 || _referrer == COMPANY_ID,
            "Referrer must have an active deposit"
        );

        require(bytes(_nickname).length > 0, "Nickname cannot be empty");
        require(bytes(_nickname).length <= 32, "Nickname too long");
        require(
            nicknameToAddress[_nickname] == address(0),
            "Nickname already taken"
        );

        uint256 currentDirects = directReferrals[_referrer].length;
        require(currentDirects < MAX_DIRECTS, "Referrer max 1000 directs");

        User storage user = users[msg.sender];
        user.isExist = true;
        user.referrer = _referrer;
        user.joiningTime = block.timestamp;
        user.roiPercentage = 70;
        user.incomeCapMultiplier = 3;
        user.lastLevelWithdraw = block.timestamp;
        user.lastUplineWithdraw = block.timestamp;
        user.lastSalaryWithdraw = block.timestamp;
        user.nickname = _nickname;

        nicknameToAddress[_nickname] = msg.sender;

        users[_referrer].partnersCount++;
        directReferrals[_referrer].push(msg.sender);

        _recalculateDailyRate(_referrer);

        emit Registration(msg.sender, _referrer, _nickname);
    }

    function deposit(
        uint256 _usdtAmount,
        uint256 _minIexExpected
    ) public nonReentrant {
        require(users[msg.sender].isExist, "Register first");
        require(_usdtAmount >= MIN_DEPOSIT_USD, "Min 100 USDT");
        require(
            users[msg.sender].investments.length < MAX_INVESTMENTS,
            "Max 100 investments reached"
        );

        _safeTransferFrom(usdtToken, msg.sender, address(this), _usdtAmount);

        uint256 initialBal = iexToken.balanceOf(address(this));
        _swapUsdtToIex(_usdtAmount, _minIexExpected);
        uint256 IexBought = iexToken.balanceOf(address(this)) - initialBal;

        User storage user = users[msg.sender];

        _checkpointLevelIncome(user);

        uint256 pending = _calculatePendingROI(msg.sender);
        if (pending > 0) {
            user.earnedFromRoi += pending;
            _distributeRoiToInvestments(msg.sender, user);
            _creditIncome(user, pending);
        } else {
            if (
                user.totalEarnedUSD >= user.currentCapUSD &&
                user.currentCapUSD > 0
            ) {
                for (uint256 i = 0; i < user.investments.length; i++) {
                    user.investments[i].lastWithdrawTime = block.timestamp;
                }
                user.lastUplineWithdraw = block.timestamp;
                user.lastLevelWithdraw = block.timestamp;
            }
        }

        bool wasQualified = _isUserQualifiedForCommissions(msg.sender);
        bool isNetworkEligible = (_usdtAmount >= QUALIFIED_THRESHOLD);

        if (user.totalDepositUSD == 0) {
            user.activationTime = block.timestamp;
        }

        user.totalDepositUSD += _usdtAmount;
        if (isNetworkEligible) {
            user.totalNetworkDepositUSD += _usdtAmount;
        }

        bool isNowQualified = _isUserQualifiedForCommissions(msg.sender);

        if (!wasQualified && isNowQualified && user.referrer != address(0)) {
            users[user.referrer].activePartners++;
        }

        if (msg.sender != COMPANY_ID) {
            user.currentCapUSD += (_usdtAmount * user.incomeCapMultiplier);
        }

        user.investments.push(
            Investment({
                amount: _usdtAmount,
                depositTime: block.timestamp,
                lastWithdrawTime: block.timestamp,
                earned: 0,
                isLevelVolumeRemoved: false
            })
        );

        _recalculateDailyRate(msg.sender);

        if (isNowQualified && isNetworkEligible) {
            _updateUplineVolumeAndStats(user.referrer, _usdtAmount);

            if (user.referrer != address(0)) {
                users[user.referrer].totalDirectBusiness += _usdtAmount;
                _attemptUplineQualification(user.referrer);
                _checkBooster(user.referrer);
            }
        }

        if (user.referrer != address(0)) {
            _distributeDirect(user.referrer, _usdtAmount);
        }

        _attemptUplineQualification(msg.sender);
        _checkBooster(msg.sender);

        emit Deposit(msg.sender, _usdtAmount, IexBought);
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

        uint256 totalIex = getIexAmountFromUsd(payoutUSD);
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

    function _updateUplineVolumeAndStats(
        address _referrer,
        uint256 _amount
    ) internal {
        address current = _referrer;
        for (uint256 i = 0; i < uplineDepth; i++) {
            if (current == address(0)) break;
            User storage upline = users[current];

            _checkpointLevelIncome(upline);

            upline.totalTeamVolume += _amount;

            if (i < 30) {
                upline.levelVolume[i] += _amount;
                _recalculateDailyRate(current);
            }
            current = upline.referrer;
        }
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
    ) public view returns (uint256) {
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

    function _getQualifiedBoosterDirects(
        address _user
    ) internal view returns (uint256) {
        uint256 count = 0;
        address[] memory directs = directReferrals[_user];
        for (uint256 i = 0; i < directs.length; i++) {
            if (users[directs[i]].totalNetworkDepositUSD >= 100 * 1e18) {
                count++;
            }
        }
        return count;
    }

    function _checkBooster(address _user) internal {
        User storage user = users[_user];
        if (!user.isExist || user.activationTime == 0) return;
        if (!_isUserQualifiedForCommissions(_user)) return;

        if (block.timestamp > user.activationTime + 90 days) return;

        uint256 qualifiedDirects = _getQualifiedBoosterDirects(_user);
        uint256 vol = user.totalDirectBusiness;

        if (qualifiedDirects >= 10 && vol >= 10000 * 1e18) {
            if (user.roiPercentage < 100) _upgradeUser(_user, user, 100, 6);
        } else if (qualifiedDirects >= 5 && vol >= 5000 * 1e18) {
            if (user.roiPercentage < 90) _upgradeUser(_user, user, 90, 5);
        } else if (qualifiedDirects >= 3 && vol >= 1500 * 1e18) {
            if (user.roiPercentage < 80) _upgradeUser(_user, user, 80, 4);
        }
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

    function _upgradeUser(
        address _userAddr,
        User storage user,
        uint256 _newRoi,
        uint256 _newMult
    ) internal {
        uint256 pending = _calculatePendingROI(_userAddr);
        if (pending > 0) {
            user.earnedFromRoi += pending;
            _distributeRoiToInvestments(_userAddr, user);
            _creditIncome(user, pending);
        } else {
            if (
                user.totalEarnedUSD >= user.currentCapUSD &&
                user.currentCapUSD > 0
            ) {
                for (uint256 i = 0; i < user.investments.length; i++) {
                    user.investments[i].lastWithdrawTime = block.timestamp;
                }
                user.lastUplineWithdraw = block.timestamp;
            }
        }
        user.roiPercentage = _newRoi;
        user.incomeCapMultiplier = _newMult;

        if (_userAddr != COMPANY_ID) {
            user.currentCapUSD = user.totalDepositUSD * _newMult;
        }

        address current = user.referrer;
        for (uint256 i = 0; i < 30; i++) {
            if (current == address(0)) break;
            _checkpointLevelIncome(users[current]);
            _recalculateDailyRate(current);
            current = users[current].referrer;
        }
        emit BoosterUpgrade(_userAddr, _newRoi, _newMult);
    }

    function _isUserActiveForROI(
        address _userAddr
    ) internal view returns (bool) {
        User storage user = users[_userAddr];
        if (user.totalEarnedUSD >= user.currentCapUSD) return false;

        for (uint i = 0; i < user.investments.length; i++) {
            uint256 maxPerInv = (_userAddr == COMPANY_ID)
                ? user.investments[i].amount * 20000
                : user.investments[i].amount * 2;
            if (user.investments[i].earned < maxPerInv) return true;
        }
        return false;
    }

    function _attemptUplineQualification(address _userAddr) internal {
        User storage user = users[_userAddr];
        if (
            user.isUplineQualified ||
            block.timestamp > user.activationTime + 30 days
        ) return;
        if (!_isUserQualifiedForCommissions(_userAddr)) return;

        if (
            user.totalNetworkDepositUSD >= 1500 * 1e18 &&
            user.activePartners >= 5 &&
            user.totalTeamVolume >= 5000 * 1e18
        ) {
            user.isUplineQualified = true;
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

    function _calculateCurrentSalaryRank(
        address _userAddr
    ) public view returns (uint256) {
        (uint256 legA, uint256 legB, uint256 legC) = getLegVolumes(_userAddr);

        for (uint256 i = 10; i > 0; i--) {
            uint256 idx = i - 1;
            if (
                legA >= salaryReqLeg[idx] &&
                legB >= salaryReqLeg[idx] &&
                legC >= salaryReqRest[idx]
            ) {
                return idx + 1;
            }
        }
        return 0;
    }

    function processSalaryRank(address _userAddr) public {
        User storage user = users[_userAddr];
        if (!user.isExist) return;
        if (!_isUserQualifiedForCommissions(_userAddr)) return;

        uint256 currentRank = _calculateCurrentSalaryRank(_userAddr);
        (, uint256 legB, uint256 legC) = getLegVolumes(_userAddr);
        uint256 currentLegBC = legB + legC;

        if (currentRank > user.salaryRank) {
            user.salaryRank = currentRank;
            user.salarySnapshotLegBC = currentLegBC;
            user.lastSalaryWithdraw = block.timestamp;
            user.salaryCycleTimestamp = block.timestamp;
            user.rankMonthsPaid = 1;

            uint256 instantSalary = salaryIncome[currentRank - 1];
            user.earnedFromSalary += instantSalary;
            _creditIncome(user, instantSalary);

            emit SalaryIncome(_userAddr, currentRank, instantSalary);

            return;
        }

        if (user.salaryRank > 0) {
            if (user.rankMonthsPaid >= MAX_SALARY_MONTHS) return;

            uint256 monthsPassed = (block.timestamp - user.lastSalaryWithdraw) /
                MONTH_STEP;

            if (monthsPassed > 0) {
                uint256 pending = 0;

                if (currentRank >= user.salaryRank) {
                    uint256 target = (salaryReqLeg[user.salaryRank - 1] * 2) +
                        salaryReqRest[user.salaryRank - 1];
                    uint256 stepVolume = (target * 20) / 100;

                    uint256 validMonths = 0;

                    for (uint256 m = 1; m <= monthsPassed; m++) {
                        uint256 currentMonthToPay = user.rankMonthsPaid + m;

                        if (currentMonthToPay > MAX_SALARY_MONTHS) break;

                        uint256 requiredMultiplier = currentMonthToPay - 1;
                        uint256 requiredNewVol = stepVolume *
                            requiredMultiplier;
                        uint256 requiredTotalVol = user.salarySnapshotLegBC +
                            requiredNewVol;

                        if (currentLegBC >= requiredTotalVol) {
                            validMonths++;
                        } else {
                            break;
                        }
                    }

                    if (validMonths > 0) {
                        pending =
                            salaryIncome[user.salaryRank - 1] *
                            validMonths;
                        user.rankMonthsPaid += validMonths;
                    }
                }

                if (pending > 0) {
                    user.earnedFromSalary += pending;
                    _creditIncome(user, pending);
                    emit SalaryIncome(_userAddr, user.salaryRank, pending);
                    user.lastSalaryWithdraw = block.timestamp;
                }
            }
        }
    }

    function _distributeDirect(address _referrer, uint256 _amountUSD) internal {
        if (!users[_referrer].isExist || users[_referrer].totalDepositUSD == 0)
            return;
        uint256 comm = (_amountUSD * 500) / PERC_DIVIDER;
        users[_referrer].earnedFromDirect += comm;
        _creditIncome(users[_referrer], comm);
        emit DirectBonus(_referrer, msg.sender, comm);
    }

    function _swapUsdtToIex(uint256 _amount, uint256 _minOut) internal {
        usdtToken.approve(address(pancakeRouter), _amount);
        address[] memory path = new address[](2);
        path[0] = address(usdtToken);
        path[1] = address(iexToken);
        pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amount,
            _minOut,
            path,
            address(this),
            block.timestamp + 300
        );
    }

    function getIexAmountFromUsd(
        uint256 _usdAmount
    ) public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(usdtToken);
        path[1] = address(iexToken);
        return pancakeRouter.getAmountsOut(_usdAmount, path)[1];
    }

    function getUserInvestments(
        address _userAddr
    ) public view returns (Investment[] memory) {
        return users[_userAddr].investments;
    }

    function claimFundReward() external nonReentrant {
        _processFundReward(msg.sender);
    }

    function claimSalary() external nonReentrant {
        processSalaryRank(msg.sender);
    }
}