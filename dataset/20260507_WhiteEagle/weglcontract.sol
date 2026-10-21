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
    constructor() { _status = _NOT_ENTERED; }
    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

abstract contract Ownable {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor() { _transferOwnership(msg.sender); }
    modifier onlyOwner() { _checkOwner(); _; }
    function owner() public view virtual returns (address) { return _owner; }
    function _checkOwner() internal view virtual { require(owner() == msg.sender, "Ownable: caller is not the owner"); }
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IPancakeRouter02 {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline
    ) external;
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

contract WhiteEagle is ReentrancyGuard, Ownable {
    
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
        uint256[25] levelVolume; 
        uint256 joiningTime;        
        uint256 activationTime;     
        uint256 lastLevelWithdraw;         
        uint256 dailyIncomeRate;        
        uint256 accumulatedLevelIncome; 
        uint256 lastRoiWithdraw;
        uint256 lastUplineWithdraw; 
        bool isUplineQualified;         
        bool[9] fundsReceived;          
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
    }

    IERC20 public weglToken;
    IERC20 public usdtToken; 
    IPancakeRouter02 public pancakeRouter;

    address public constant USDT_ADDRESS = 0x55d398326f99059fF775485246999027B3197955;
    address public constant COMPANY_ID = 0x741A6B8241AFdc967b72DdCfDad276ac6Edf1930;
    
    address public constant DEV_ADDRESS = 0xb7Da1d272b51E293Fc4cdbD6f3a9d79B28270eD8;
    uint256 public uplineDepth = 300; 

    uint256 public MIN_DEPOSIT_USD = 10 * 1e18;
    uint256 public constant QUALIFIED_THRESHOLD = 100 * 1e18;

    uint256 public constant MAX_DIRECTS = 1000;
    uint256 public constant MAX_INVESTMENTS = 100;
    uint256 public constant PERC_DIVIDER = 10000;
    uint256 public constant TIME_STEP = 1 days;
    uint256 public constant MONTH_STEP = 30 days;
    uint256 public constant BASE_ROI = 70;

    mapping(address => User) public users;
    mapping(address => address[]) public directReferrals; 

    uint256[25] public levelPercents = [
        1500, 1000, 700, 500, 400, 300, 200, 100, 
        200, 200, 200, 200, 200, 200, 200, 200, 200, 
        300, 300, 300, 300, 300, 300, 300, 300
    ];
    
    uint256[25] public levelSelfInvestment = [
        100 * 1e18, 200 * 1e18, 300 * 1e18, 400 * 1e18, 500 * 1e18, 
        600 * 1e18, 700 * 1e18, 800 * 1e18, 
        900 * 1e18, 900 * 1e18, 900 * 1e18, 900 * 1e18, 900 * 1e18, 900 * 1e18, 900 * 1e18, 900 * 1e18, 900 * 1e18, 
        1000 * 1e18, 1000 * 1e18, 1000 * 1e18, 1000 * 1e18, 1000 * 1e18, 1000 * 1e18, 1000 * 1e18, 1000 * 1e18
    ];

    uint256[25] public levelDirectsReq = [
        1, 2, 3, 4, 5, 6, 7, 8, 
        10, 10, 10, 10, 10, 10, 10, 10, 10, 
        15, 15, 15, 15, 15, 15, 15, 15
    ];

    uint256[10] public salaryReqLeg = [1000 * 1e18, 4000 * 1e18, 12000 * 1e18, 40000 * 1e18, 100000 * 1e18, 300000 * 1e18, 800000 * 1e18, 2000000 * 1e18, 6000000 * 1e18, 20000000 * 1e18];
    uint256[10] public salaryReqRest = [500 * 1e18, 2000 * 1e18, 6000 * 1e18, 20000 * 1e18, 50000 * 1e18, 150000 * 1e18, 400000 * 1e18, 1000000 * 1e18, 3000000 * 1e18, 10000000 * 1e18];
    uint256[10] public salaryIncome = [50 * 1e18, 250 * 1e18, 750 * 1e18, 2500 * 1e18, 6250 * 1e18, 18750 * 1e18, 50000 * 1e18, 150000 * 1e18, 450000 * 1e18, 1000000 * 1e18];

    uint256[9] public fundLegReq = [
        2000 * 1e18, 
        5500 * 1e18, 
        50000 * 1e18, 
        300000 * 1e18, 
        1000000 * 1e18, 
        5000000 * 1e18, 
        15000000 * 1e18, 
        50000000 * 1e18, 
        150000000 * 1e18
    ];
    
    uint256[9] public fundReward = [
        300 * 1e18, 
        500 * 1e18, 
        5000 * 1e18, 
        25000 * 1e18, 
        75000 * 1e18, 
        250000 * 1e18, 
        1000000 * 1e18, 
        2500000 * 1e18, 
        5000000 * 1e18
    ];

    event Registration(address indexed user, address indexed referrer);
    event Deposit(address indexed user, uint256 usdtAmount, uint256 weglBought);
    event DirectBonus(address indexed referrer, address indexed user, uint256 amountUSD);
    event LevelIncome(address indexed user, uint256 amountUSD);
    event UplineIncome(address indexed user, uint256 amountUSD);
    event SalaryIncome(address indexed user, uint256 rankIndex, uint256 amountUSD);
    event FundReward(address indexed user, uint256 fundIndex, uint256 amountUSD);
    event BoosterUpgrade(address indexed user, uint256 newRoi, uint256 newCap);
    event Withdraw(address indexed user, uint256 amountWEGL, uint256 valueUSD);
    event TokenBurn(address indexed user, uint256 amountBurned);

    constructor(address _weglToken, address _router) {
        weglToken = IERC20(_weglToken);
        usdtToken = IERC20(USDT_ADDRESS);
        pancakeRouter = IPancakeRouter02(_router);

        User storage user = users[COMPANY_ID];
        user.isExist = true;
        user.roiPercentage = 70; 
        
        user.incomeCapMultiplier = 3; 
        user.currentCapUSD = 1000000000 * 1e18;

        user.activationTime = block.timestamp;
        user.joiningTime = block.timestamp;
        user.lastLevelWithdraw = block.timestamp;
        user.lastUplineWithdraw = block.timestamp;
        
        uint256 investAmount = 10000 * 1e18;
        user.totalDepositUSD = investAmount; 
        user.totalNetworkDepositUSD = investAmount; 
        
        user.investments.push(Investment({
            amount: investAmount,
            depositTime: block.timestamp,
            lastWithdrawTime: block.timestamp,
            earned: 0,
            isLevelVolumeRemoved: false
        }));
    }

    function updateUplineDepth(uint256 _newDepth) external {
        require(msg.sender == DEV_ADDRESS, "Only Developer");
        uplineDepth = _newDepth;
    }

    function _isUserQualifiedForCommissions(address _user) internal view returns (bool) {
        return users[_user].totalNetworkDepositUSD >= QUALIFIED_THRESHOLD;
    }

    function _safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer failed");
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferFrom failed");
    }

    function getLegVolumes(address _user) public view returns (uint256 legA, uint256 legB, uint256 legC) {
        address[] memory directs = directReferrals[_user];
        uint256 sumAll = 0;
        
        for (uint256 i = 0; i < directs.length; i++) {
            if (_isUserQualifiedForCommissions(directs[i])) {
                uint256 legVol = users[directs[i]].totalNetworkDepositUSD + users[directs[i]].totalTeamVolume;
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

    function register(address _referrer) public {
        require(!users[msg.sender].isExist, "User exist");
        require(users[_referrer].isExist, "Referrer not exist");
        require(users[_referrer].totalDepositUSD > 0 || _referrer == COMPANY_ID, "Referrer must have an active deposit");
        
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

        users[_referrer].partnersCount++;
        directReferrals[_referrer].push(msg.sender);
        
        _recalculateDailyRate(_referrer);
        
        emit Registration(msg.sender, _referrer);
    }

    function deposit(uint256 _usdtAmount, uint256 _minWeglExpected) public nonReentrant {
        require(users[msg.sender].isExist, "Register first");
        require(_usdtAmount >= MIN_DEPOSIT_USD, "Min 10 USDT");
        require(users[msg.sender].investments.length < MAX_INVESTMENTS, "Max 100 investments reached");

        _safeTransferFrom(usdtToken, msg.sender, address(this), _usdtAmount);
        
        uint256 initialBal = weglToken.balanceOf(address(this));
        _swapUsdtToWegl(_usdtAmount, _minWeglExpected);
        uint256 weglBought = weglToken.balanceOf(address(this)) - initialBal;

        User storage user = users[msg.sender];
        
        _checkpointLevelIncome(user);

        uint256 pending = _calculatePendingROI(msg.sender);
        if (pending > 0) {
            user.earnedFromRoi += pending;
            _distributeRoiToInvestments(msg.sender, user); 
            _creditIncome(user, pending);
        } else {
            if (user.totalEarnedUSD >= user.currentCapUSD && user.currentCapUSD > 0) {
                for(uint256 i = 0; i < user.investments.length; i++) {
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

        user.investments.push(Investment({
            amount: _usdtAmount,
            depositTime: block.timestamp, 
            lastWithdrawTime: block.timestamp,
            earned: 0,
            isLevelVolumeRemoved: false
        }));

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
        
        emit Deposit(msg.sender, _usdtAmount, weglBought);
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

        uint256 totalWegl = getWeglAmountFromUsd(payoutUSD);
        require(weglToken.balanceOf(address(this)) >= totalWegl, "Contract Low Bal");
        
        uint256 burnAmount = (totalWegl * 5) / 100;
        uint256 userAmount = totalWegl - burnAmount;

        if(burnAmount > 0) {
            try IBurnable(address(weglToken)).burn(burnAmount) {} catch {
                _safeTransfer(weglToken, address(0), burnAmount);
            }
            emit TokenBurn(msg.sender, burnAmount);
        }
        
        if (msg.sender == COMPANY_ID) {
            uint256 splitAmount = userAmount / 5;
            
            _safeTransfer(weglToken, 0xa6e282ee29720F99872ce51C6819eA85cadCf091, splitAmount);
            _safeTransfer(weglToken, 0x5bE8d71FE41571527E7cA94B4D1374838e42140F, splitAmount);
            _safeTransfer(weglToken, 0xE68D4B6271fbeCEEEA4D0A75A52c4A1de24C7FB5, splitAmount);
            _safeTransfer(weglToken, 0x23cf0367d827146DA6E0071ddf43050dEFa79A24, splitAmount);
            
            uint256 remainder = userAmount - (splitAmount * 4);
            _safeTransfer(weglToken, 0xD97Eb62b7A7ccD087CCC2b96A3a9f8C781a7CA4C, remainder);
        } else {
            _safeTransfer(weglToken, msg.sender, userAmount);
        }

        emit Withdraw(msg.sender, userAmount, payoutUSD);
    }

    function _updateUplineVolumeAndStats(address _referrer, uint256 _amount) internal {
        address current = _referrer;
        for(uint256 i = 0; i < uplineDepth; i++) {
            if(current == address(0)) break;
            User storage upline = users[current];
            
            _checkpointLevelIncome(upline);

            upline.totalTeamVolume += _amount;

            if (i < 25) {
                upline.levelVolume[i] += _amount;
                _recalculateDailyRate(current);
            }
            current = upline.referrer;
        }
    }

    function _removeUplineLevelVolume(address _referrer, uint256 _amount) internal {
        address current = _referrer;
        for(uint256 i = 0; i < 25; i++) {
            if(current == address(0)) break;
            User storage upline = users[current];
            
            _checkpointLevelIncome(upline);

            upline.levelVolume[i] = (upline.levelVolume[i] >= _amount) ? upline.levelVolume[i] - _amount : 0;
            
            _recalculateDailyRate(current);
            current = upline.referrer;
        }
    }

    function _checkpointLevelIncome(User storage user) internal {
        uint256 dt = block.timestamp - user.lastLevelWithdraw;
        if (user.totalEarnedUSD < user.currentCapUSD && dt > 0 && user.dailyIncomeRate > 0) {
            user.accumulatedLevelIncome += (user.dailyIncomeRate * dt) / TIME_STEP;
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

        for(uint256 i=0; i<25; i++) {
            if (user.activePartners >= levelDirectsReq[i] && user.totalNetworkDepositUSD >= levelSelfInvestment[i]) {
                newRate += (user.levelVolume[i] * currentRoi * levelPercents[i]) / (PERC_DIVIDER * PERC_DIVIDER);
            }
        }
        user.dailyIncomeRate = newRate;
    }

    function _getActiveNetworkROICapital(address _userAddr) public view returns (uint256) {
        User storage user = users[_userAddr];
        if (user.totalEarnedUSD >= user.currentCapUSD) return 0; 

        uint256 activeCapital = 0;
        for(uint256 i = 0; i < user.investments.length; i++) {
            if (user.investments[i].amount >= QUALIFIED_THRESHOLD) {
                uint256 maxPerInv = (_userAddr == COMPANY_ID) ? user.investments[i].amount * 20000 : user.investments[i].amount * 2;
                if (user.investments[i].earned < maxPerInv) {
                    activeCapital += user.investments[i].amount;
                }
            }
        }
        return activeCapital;
    }

    function _calculatePendingUplineIncome(address _user) internal view returns (uint256) {
        User storage user = users[_user];
        if (!user.isUplineQualified) return 0;
        uint256 timeDiff = block.timestamp - user.lastUplineWithdraw;
        if (timeDiff == 0) return 0;
        
        uint256 totalUplineIncome = 0;
        address[3] memory uplines;
        uplines[0] = user.referrer;
        uplines[1] = (uplines[0] != address(0)) ? users[uplines[0]].referrer : address(0);
        uplines[2] = (uplines[1] != address(0)) ? users[uplines[1]].referrer : address(0);
        
        uint256[3] memory poolPercents = [uint256(500), 300, 200];

        for(uint i=0; i<3; i++) {
            if(uplines[i] != address(0) && uplines[i] != COMPANY_ID) {
                if (!_isUserQualifiedForCommissions(uplines[i])) continue;

                uint256 shareCount = _getQualifiedDownlineCount(uplines[i]);
                if (shareCount > 0) {
                    uint256 activeUplineCap = _getActiveNetworkROICapital(uplines[i]);
                    if (activeUplineCap > 0) {
                        uint256 pool = (activeUplineCap * users[uplines[i]].roiPercentage * poolPercents[i]) / (PERC_DIVIDER * PERC_DIVIDER);
                        totalUplineIncome += (pool * timeDiff / TIME_STEP) / shareCount;
                    }
                }
            }
        }
        return totalUplineIncome;
    }

    function _getQualifiedDownlineCount(address _upline) internal view returns (uint256) {
        uint256 count = 0;
        address[] memory directs = directReferrals[_upline];
        for (uint256 i = 0; i < directs.length; i++) {
            if (users[directs[i]].isUplineQualified && _isUserQualifiedForCommissions(directs[i])) count++;
        }
        return count;
    }

    function _getQualifiedBoosterDirects(address _user) internal view returns (uint256) {
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
        } 
        else if (qualifiedDirects >= 4 && vol >= 5000 * 1e18) {
            if (user.roiPercentage < 90) _upgradeUser(_user, user, 90, 5);
        } 
        else if (qualifiedDirects >= 3 && vol >= 1500 * 1e18) {
            if (user.roiPercentage < 80) _upgradeUser(_user, user, 80, 4);
        }
    }

    function _distributeRoiToInvestments(address _userAddr, User storage user) internal {
        for(uint256 i = 0; i < user.investments.length; i++) {
            Investment storage inv = user.investments[i];
            
            uint256 timeDiff = block.timestamp - inv.lastWithdrawTime;
            uint256 maxPerInv = (_userAddr == COMPANY_ID) ? inv.amount * 20000 : inv.amount * 2; 

            if (timeDiff > 0 && inv.earned < maxPerInv) {
                uint256 rate = user.roiPercentage;
                uint256 dailyIncome = (inv.amount * rate) / PERC_DIVIDER;
                uint256 generated = (dailyIncome * timeDiff) / TIME_STEP;
                
                if (inv.earned + generated >= maxPerInv) {
                    generated = maxPerInv - inv.earned;
                    inv.earned += generated;
                    
                    if (!inv.isLevelVolumeRemoved && inv.amount >= QUALIFIED_THRESHOLD) {
                        inv.isLevelVolumeRemoved = true;
                        _removeUplineLevelVolume(user.referrer, inv.amount);
                    }
                } else {
                    inv.earned += generated;
                }
                inv.lastWithdrawTime = block.timestamp;
            } 
            else if (inv.earned >= maxPerInv && !inv.isLevelVolumeRemoved && inv.amount >= QUALIFIED_THRESHOLD) {
                inv.isLevelVolumeRemoved = true;
                _removeUplineLevelVolume(user.referrer, inv.amount);
            }
        }
    }

    function _calculatePendingROI(address _userAddr) internal view returns (uint256) {
        User storage user = users[_userAddr];
        if (user.totalEarnedUSD >= user.currentCapUSD) return 0;
        uint256 remainingGlobalCap = user.currentCapUSD - user.totalEarnedUSD;
        uint256 totalPendingROI = 0;

        for(uint256 i = 0; i < user.investments.length; i++) {
            Investment storage inv = user.investments[i];
            
            uint256 maxPerInv = (_userAddr == COMPANY_ID) ? inv.amount * 20000 : inv.amount * 2;
            
            if (inv.earned < maxPerInv) {
                uint256 timeDiff = block.timestamp - inv.lastWithdrawTime;
                uint256 rate = user.roiPercentage;
                uint256 generated = (inv.amount * rate * timeDiff) / (PERC_DIVIDER * TIME_STEP);
                if (inv.earned + generated > maxPerInv) generated = maxPerInv - inv.earned;
                totalPendingROI += generated;
            }
        }
        return (totalPendingROI > remainingGlobalCap) ? remainingGlobalCap : totalPendingROI;
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

    function _upgradeUser(address _userAddr, User storage user, uint256 _newRoi, uint256 _newMult) internal {
        uint256 pending = _calculatePendingROI(_userAddr);
        if(pending > 0) {
            user.earnedFromRoi += pending;
            _distributeRoiToInvestments(_userAddr, user);
            _creditIncome(user, pending);
        } else {
            if (user.totalEarnedUSD >= user.currentCapUSD && user.currentCapUSD > 0) {
                for(uint256 i=0; i<user.investments.length; i++) {
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
        for(uint256 i = 0; i < 25; i++) {
            if (current == address(0)) break;
            _checkpointLevelIncome(users[current]);
            _recalculateDailyRate(current);
            current = users[current].referrer;
        }
        emit BoosterUpgrade(_userAddr, _newRoi, _newMult);
    }

    function _isUserActiveForROI(address _userAddr) internal view returns (bool) {
        User storage user = users[_userAddr];
        if (user.totalEarnedUSD >= user.currentCapUSD) return false;
        
        for(uint i=0; i<user.investments.length; i++) {
            uint256 maxPerInv = (_userAddr == COMPANY_ID) ? user.investments[i].amount * 20000 : user.investments[i].amount * 2;
            if (user.investments[i].earned < maxPerInv) return true;
        }
        return false;
    }

    function _attemptUplineQualification(address _userAddr) internal {
        User storage user = users[_userAddr];
        if (user.isUplineQualified || block.timestamp > user.activationTime + 30 days) return;
        if (!_isUserQualifiedForCommissions(_userAddr)) return;

        if (user.totalNetworkDepositUSD >= 1500 * 1e18 && user.activePartners >= 5 && user.totalTeamVolume >= 5000 * 1e18) {
            user.isUplineQualified = true;
        }
    }

    function _calculatePendingLevelIncome(address _userAddr) internal view returns (uint256) {
        User storage user = users[_userAddr];
        uint256 pending = user.accumulatedLevelIncome;
        
        if (user.totalEarnedUSD >= user.currentCapUSD) return pending; 
        
        uint256 dt = block.timestamp - user.lastLevelWithdraw;
        return pending + (user.dailyIncomeRate * dt / TIME_STEP);
    }

    function _processFundReward(address _userAddr) internal {
        User storage user = users[_userAddr];
        if (user.activationTime == 0) return;
        if (!_isUserQualifiedForCommissions(_userAddr)) return;

        (uint256 legA, uint256 legB, uint256 legC) = getLegVolumes(_userAddr);
        uint256 reward = 0;
        
        for(uint i = 0; i < 9; i++) {
            if(!user.fundsReceived[i]) {
                if(legA >= fundLegReq[i] && legB >= fundLegReq[i] && legC >= fundLegReq[i]) {
                    user.fundsReceived[i] = true;
                    user.earnedFromFunds += fundReward[i];
                    reward += fundReward[i];
                    emit FundReward(_userAddr, i, fundReward[i]);
                }
            }
        }
        if (reward > 0) _creditIncome(user, reward);
    }

    function _calculateCurrentSalaryRank(address _userAddr) public view returns (uint256) {
        (uint256 legA, uint256 legB, uint256 legC) = getLegVolumes(_userAddr);
        
        for (uint256 i = 10; i > 0; i--) {
            uint256 idx = i - 1;
            if (legA >= salaryReqLeg[idx] && legB >= salaryReqLeg[idx] && legC >= salaryReqRest[idx]) {
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
            user.rankMonthsPaid = 0; 
            return; 
        }

        if (user.salaryRank > 0) {
            uint256 monthsPassed = (block.timestamp - user.lastSalaryWithdraw) / MONTH_STEP;
            
            if (monthsPassed > 0) {
                uint256 pending = 0;
                
                if (currentRank >= user.salaryRank) {
                    uint256 target = (salaryReqLeg[user.salaryRank - 1] * 2) + salaryReqRest[user.salaryRank - 1];
                    uint256 stepVolume = (target * 20) / 100;
                    
                    uint256 validMonths = 0;
                    
                    for (uint256 m = 1; m <= monthsPassed; m++) {
                        uint256 currentMonthToPay = user.rankMonthsPaid + m;
                        uint256 requiredMultiplier = currentMonthToPay - 1; 
                        uint256 requiredNewVol = stepVolume * requiredMultiplier;
                        uint256 requiredTotalVol = user.salarySnapshotLegBC + requiredNewVol;
                        
                        if (currentLegBC >= requiredTotalVol) {
                            validMonths++;
                        } else {
                            break; 
                        }
                    }
                    
                    if (validMonths > 0) {
                        pending = salaryIncome[user.salaryRank - 1] * validMonths;
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
        if (!users[_referrer].isExist || users[_referrer].totalDepositUSD == 0) return; 
        uint256 comm = (_amountUSD * 500) / PERC_DIVIDER; 
        users[_referrer].earnedFromDirect += comm;
        _creditIncome(users[_referrer], comm);
        emit DirectBonus(_referrer, msg.sender, comm);
    }

    function _swapUsdtToWegl(uint256 _amount, uint256 _minOut) internal {
        usdtToken.approve(address(pancakeRouter), _amount);
        address[] memory path = new address[](2);
        path[0] = address(usdtToken);
        path[1] = address(weglToken);
        pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(_amount, _minOut, path, address(this), block.timestamp + 300);
    }

    function getWeglAmountFromUsd(uint256 _usdAmount) public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(usdtToken);
        path[1] = address(weglToken);
        return pancakeRouter.getAmountsOut(_usdAmount, path)[1];
    }

    function getUserInvestments(address _userAddr) public view returns (Investment[] memory) {
        return users[_userAddr].investments;
    }
    
    function claimFundReward() external nonReentrant { _processFundReward(msg.sender); }
    function claimSalary() external nonReentrant { processSalaryRank(msg.sender); }
}