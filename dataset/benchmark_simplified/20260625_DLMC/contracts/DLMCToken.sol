// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DLMCToken is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 constant PRE_MINED_LP = 500_000 * 10 ** 18;

    uint256 constant DIVIDENT_PER_DAY = 1 days;

    address public DEVELOPERADDRESS;

    address public DEVELOPERADDRESS1;

    address public DEVELOPERADDRESS2;

    address public DEVELOPERADDRESS3;

    uint256 constant MIN_INVESTMENT_FOR_INCOME = 100 * 10 ** 18;

    uint256 constant DAILY_DIVIDEND_RATE = 1;

    uint256 constant CAP_SMALL_INVESTOR = 250;

    uint256 constant CAP_LARGE_INVESTOR = 500;

    uint256[15] public REFERRAL_LEVEL_PERCENTS = [
        10,
        9,
        8,
        7,
        6,
        5,
        4,
        4,
        4,
        3,
        3,
        3,
        3,
        3,
        3
    ];

    uint256[15] public REFERRAL_SELF_BUSINESS = [
        100 * 1e18,
        200 * 1e18,
        300 * 1e18,
        400 * 1e18,
        500 * 1e18,
        700 * 1e18,
        900 * 1e18,
        1100 * 1e18,
        1300 * 1e18,
        1500 * 1e18,
        1800 * 1e18,
        2100 * 1e18,
        2400 * 1e18,
        2700 * 1e18,
        3000 * 1e18
    ];

    uint256 constant MAX_REFERRAL_LEVELS = 15;

    uint256[15] public MATCHING_SELF_INVEST_REQUIREMENTS = [
        200 * 1e18,
        400 * 1e18,
        800 * 1e18,
        1600 * 1e18,
        3200 * 1e18,
        6400 * 1e18,
        12800 * 1e18,
        25600 * 1e18,
        51200 * 1e18,
        102400 * 1e18,
        102400 * 1e18,
        102400 * 1e18,
        102400 * 1e18,
        102400 * 1e18,
        102400 * 1e18
    ];

    uint256 constant MATCHING_BASE_VOLUME = 15_000 * 1e18;

    uint256 constant MATCHING_REWARD_PERCENT = 1;

    uint256 constant MATCHING_MAX_TIERS = 15;

    struct InvestmentTranche {
        uint256 amountUsdt18;
        uint256 startTime;
        uint256 lastClaimTime;
        bool isActive;
    }

    uint256 public totalUser = 1;

    struct AffiliateUser {
        uint256 mid;
        bool isRegistered;
        address referrer;
        uint256 totalInvested;

        uint256 totalPersonalDividends;
        uint256 totalReferralBonuses;
        uint256 totalLevelBonuses;
        uint256 totalMatchingRewards;
        uint256 totalMatchingVolumeClaimed;
        uint256 lastDividendClaim;
        uint256 registrationTime;
        mapping(uint256 => address) downline;
        InvestmentTranche[] tranches;
        uint256 totalDirectInvested;
        uint256 totalTeamInvested;
    }

    struct VestedMatchingReward {
        uint256 sno;
        uint256 totalRewardUsdt18;
        uint256 dailyRewardUsdt18;
        uint256 claimedRewardUsdt18;
        uint256 startTime;
        uint256 lastClaimTime;
        bool isActive;
    }

    uint256 constant VESTING_DURATION_DAYS = 200;

    uint256 constant VESTING_DAILY_PERCENT = 5;

    uint256 constant VESTING_CLAIM_PERIOD = 1 days;

    mapping(address => AffiliateUser) public affiliates;

    mapping(address => address[]) public directDownline;

    mapping(address => uint256) public userLastClaimedMatchingTier;

    mapping(address => VestedMatchingReward[]) public vestedMatchingRewards;

    mapping(address => mapping(uint256 => bool)) private _vestedRewardCompleted;

    mapping(address => uint256) public userSoldValueUsdt18;

    uint256 public livePrice;

    IERC20 public immutable quoteToken;

    uint8 public immutable quoteDecimals;

    uint256 constant BUY_PERCENT = 15;

    uint256 constant SELL_PERCENT = 10;

    uint256 public totalUSDTReceived;

    uint256 public totalUSDTWithdrawn;

    uint256 public totalLPTMintedForUsers;

    uint256 public constant MIN_PRICE = 1 * 1e17;

    uint256 public constant MAX_PRICE = 100000 * 1e18;

    uint256 constant LEADERSHIP_LEVELS = 3;

    uint256[3] public LEADERSHIP_PERCENTS = [10, 5, 5];

    uint256 constant LEADERSHIP_REQ_SELF_INVEST = 3000 * 1e18;

    uint256 constant LEADERSHIP_REQ_DIRECT_COUNT = 15;

    uint256 constant LEADERSHIP_REQ_TEAM_VOLUME = 10000 * 1e18;

    event PriceUpdated(uint256 newPrice, string direction);

    event TradeExecuted(
        address indexed user,
        string tradeType,
        uint256 amountQuote,
        uint256 amountTokens,
        uint256 feeBurned
    );

    event UserRegistered(
        address indexed user,
        address indexed referrer,
        uint256 initialInvestment
    );

    event InvestmentUpdated(address indexed user, uint256 newTotalInvested);

    event DividendClaimed(
        address indexed user,
        uint256 amountUsdtValue,
        uint256 lptAmount
    );

    event ReferralBonusReceived(
        address indexed user,
        address indexed fromDownline,
        uint256 amountUsdtValue,
        uint256 lptAmount
    );

    event LevelBonusReceived(
        address indexed recipient,
        address indexed claimer,
        uint256 level,
        uint256 amountUsdtValue,
        uint256 lptAmount
    );

    event MatchingDividentClaimed(
        address indexed user,
        uint256 amountUsdtValue,
        uint256 lptAmount
    );

    event MatchingRewardClaimed(
        address indexed user,
        uint256 rankAchieved,
        uint256 amountUsdtValue,
        uint256 lptAmount,
        uint256 matchingVolume
    );

    event RankUpgraded(
        address indexed user,
        uint256 newRank,
        uint256 rewardPercent
    );

    uint256 public constant DAO_MEMBER_FEE = 5000 * 1e18;

    uint256 constant MAX_DAO_MEMBERS = 250;

    uint256 constant DIRECT_DAO_REFERRAL_THRESHOLD = 10;

    struct DaoMemberData {
        address member;
        uint256 totaltoken;
        uint256 claimtoken;
        uint256 selltoken;
        uint256 lastSellTimestamp;
    }

    mapping(address => DaoMemberData) public daoMemberData;

    uint256 public totaldaotoken = 0;

    uint256 public daoUsdtBalance = 0;

    mapping(address => bool) public isDaoMember;

    mapping(address => uint256) public daoMemberSince;

    uint256 public totalDaoMembers;

    address[] public daoMemberAddresses;

    mapping(address => uint256) public daoTokenClaimed;

    event DaoMemberJoined(
        address indexed user,
        bool feeWaived,
        uint256 feePaid,
        uint256 timestamp
    );

    event DaoMembershipFeeReceived(address indexed from, uint256 amount);

    event DaoTokenClaimed(address indexed user, uint256 claimAmount);

    constructor(
        address _quoteTokenAddress,
        address _developeraddress,
        address _developeraddress1,
        address _developeraddress2,
        address _developeraddress3
    ) ERC20("DLMC Token", "DLMC") Ownable(msg.sender) {
        require(
            _quoteTokenAddress != address(0),
            "Invalid quote token address"
        );
        quoteToken = IERC20(_quoteTokenAddress);
        DEVELOPERADDRESS = _developeraddress;
        DEVELOPERADDRESS1 = _developeraddress1;
        DEVELOPERADDRESS2 = _developeraddress2;
        DEVELOPERADDRESS3 = _developeraddress3;
        try IERC20Metadata(_quoteTokenAddress).decimals() returns (uint8 d) {
            quoteDecimals = d;
        } catch {
            quoteDecimals = 6;
        }
        livePrice = 1 * 10 ** 17;

        _mint(address(this), PRE_MINED_LP);
        _autoRegisterOwner();
    }

    function _autoRegisterOwner() internal {
        AffiliateUser storage root = affiliates[owner()];
        root.mid = totalUser;
        root.isRegistered = true;
        root.referrer = address(0);
        root.registrationTime = block.timestamp;
        root.lastDividendClaim = block.timestamp;
        totalUser += 1;
        emit UserRegistered(owner(), address(0), 0);
    }

    function _addInvestmentTranche(
        address user,
        uint256 amountUsdt18,
        uint256 extradays
    ) internal {
        AffiliateUser storage a = affiliates[user];
        a.tranches.push(
            InvestmentTranche({
                amountUsdt18: amountUsdt18,
                startTime: block.timestamp,
                lastClaimTime: (block.timestamp + extradays),
                isActive: true
            })
        );
        a.totalInvested += amountUsdt18;
        emit InvestmentUpdated(user, a.totalInvested);
    }

    function _updateTeamBusinessUpline(
        address _buyer,
        uint256 _buyAmountUsdt18
    ) internal {
        if (_buyAmountUsdt18 == 0) return;
        AffiliateUser storage buyer = affiliates[_buyer];
        buyer.totalTeamInvested += _buyAmountUsdt18;
        address currentUpline = buyer.referrer;

        for (uint256 level = 1; level <= 150; level++) {
            if (currentUpline == address(0)) break;
            AffiliateUser storage upline = affiliates[currentUpline];
            if (upline.isRegistered) {
                if (level == 1) {
                    upline.totalDirectInvested += _buyAmountUsdt18;
                }
                upline.totalTeamInvested += _buyAmountUsdt18;
            }
            currentUpline = upline.referrer;
        }
    }

    function registerAffiliate(address _referrer) external nonReentrant {
        require(!affiliates[msg.sender].isRegistered, "Already registered");
        require(
            _referrer != address(0) && _referrer != msg.sender,
            "Invalid referrer"
        );
        require(affiliates[_referrer].isRegistered, "Referrer not registered");

        AffiliateUser storage user = affiliates[msg.sender];
        user.mid = totalUser;
        user.isRegistered = true;
        user.referrer = _referrer;
        user.registrationTime = block.timestamp;
        user.lastDividendClaim = block.timestamp;
        directDownline[_referrer].push(msg.sender);
        totalUser++;
        emit UserRegistered(msg.sender, _referrer, 0);
    }

    function buy(uint256 amountQuote) external nonReentrant {
        require(
            affiliates[msg.sender].isRegistered,
            "Must be registered to buy"
        );
        require(amountQuote > 0, "Buy amount must be > 0");
        uint256 normalizedQuote = _normalizeTo18(amountQuote, quoteDecimals);

        uint256 currentTotalInvested = affiliates[msg.sender].totalInvested;

        if (currentTotalInvested >= MIN_INVESTMENT_FOR_INCOME) {
            require(
                normalizedQuote % MIN_INVESTMENT_FOR_INCOME == 0,
                "Investment must be a multiple of 100 USDT"
            );
        }

        quoteToken.safeTransferFrom(msg.sender, address(this), amountQuote);
        totalUSDTReceived += normalizedQuote;

        uint256 buyAmount = normalizedQuote -
            ((normalizedQuote * BUY_PERCENT) / 100);
        uint256 tokensToUser = (buyAmount * 10 ** 18) / livePrice;
        require(tokensToUser > 0, "Amount too small");

        _mint(address(this), tokensToUser);
        totalLPTMintedForUsers += tokensToUser;

        _addInvestmentTranche(msg.sender, normalizedQuote, (1 days));
        _updateTeamBusinessUpline(msg.sender, normalizedQuote);

        uint256 devBonusLPT = _convertUsdtValueToLPT((buyAmount * 5) / 100);
        if (devBonusLPT > 0) {
            _transfer(
                address(this),
                DEVELOPERADDRESS,
                (devBonusLPT * 80) / 100
            );
            _transfer(
                address(this),
                DEVELOPERADDRESS1,
                (devBonusLPT * 10) / 100
            );
            _transfer(
                address(this),
                DEVELOPERADDRESS2,
                (devBonusLPT * 10) / 100
            );
        }

        address referrer = affiliates[msg.sender].referrer;
        if (
            referrer != address(0) &&
            affiliates[referrer].isRegistered &&
            affiliates[referrer].totalInvested >= MIN_INVESTMENT_FOR_INCOME
        ) {
            _distributeReferralBonusOnBuy(msg.sender, referrer, buyAmount);
        }

        _updatePrice();
        emit TradeExecuted(msg.sender, "BUY", amountQuote, tokensToUser, 0);
    }

    function sell(uint256 amountTokens) external nonReentrant {
        require(amountTokens > 0, "Sell amount must be > 0");
        require(
            balanceOf(msg.sender) >= amountTokens,
            "Insufficient token balance"
        );

        AffiliateUser storage a = affiliates[msg.sender];
        require(a.isRegistered, "Must be registered to sell");

        uint256 sellValueUsdt18 = (amountTokens * livePrice) / 1e18;
        require(sellValueUsdt18 > 0, "Sell value too small");

        uint256 maxSellValueUsdt18 = a.totalInvested * 4;
        uint256 alreadySoldUsdt18 = userSoldValueUsdt18[msg.sender];
        require(
            alreadySoldUsdt18 + sellValueUsdt18 <= maxSellValueUsdt18,
            "Exceeds 4x investment sell limit"
        );

        uint256 actualPayout = _denormalizeFrom18(
            sellValueUsdt18,
            quoteDecimals
        );
        require(actualPayout > 0, "USDT payout too small");

        uint256 contractUSDTBalance = quoteToken.balanceOf(address(this));
        if (contractUSDTBalance < actualPayout) {

            revert("Insufficient USDT liquidity in contract");
        }

        _burn(msg.sender, amountTokens);
        totalUSDTWithdrawn += sellValueUsdt18;
        userSoldValueUsdt18[msg.sender] = alreadySoldUsdt18 + sellValueUsdt18;
        quoteToken.safeTransfer(msg.sender, actualPayout);
        _updatePrice();

        emit TradeExecuted(
            msg.sender,
            "SELL",
            actualPayout,
            amountTokens,
            amountTokens
        );
    }

    function _convertUsdtValueToLPT(
        uint256 usdtValue18
    ) internal view returns (uint256) {
        require(livePrice > 0, "Price not set");
        return (usdtValue18 * 1e18) / livePrice;
    }

    function _convertLPTToUsdtValue(
        uint256 lptAmount
    ) internal view returns (uint256) {
        if (livePrice == 0) return 0;
        return (lptAmount * livePrice) / 1e18;
    }

    function _getCapForInvestment(
        uint256 investedAmount18
    ) internal pure returns (uint256) {
        return
            investedAmount18 < MIN_INVESTMENT_FOR_INCOME
                ? CAP_SMALL_INVESTOR
                : CAP_LARGE_INVESTOR;
    }

    function getTotalIncome(address user) public view returns (uint256) {
        AffiliateUser storage a = affiliates[user];
        return
            a.totalPersonalDividends +
            a.totalReferralBonuses +
            a.totalLevelBonuses +
            a.totalMatchingRewards;
    }

    function hasReachedIncomeCap(address user) public view returns (bool) {
        AffiliateUser storage a = affiliates[user];
        if (!a.isRegistered || a.totalInvested == 0) return true;

        uint256 totalIncomeUsdt18 = getTotalIncome(user);
        uint256 capPercent = _getCapForInvestment(a.totalInvested);
        uint256 maxIncomeUsdt18 = (a.totalInvested * capPercent) / 100;

        return totalIncomeUsdt18 >= maxIncomeUsdt18;
    }

    function getRemainingIncomeCapacity(
        address user
    ) public view returns (uint256) {
        AffiliateUser storage a = affiliates[user];
        if (!a.isRegistered || a.totalInvested == 0) return 0;

        uint256 totalIncomeUsdt18 = getTotalIncome(user);
        uint256 capPercent = _getCapForInvestment(a.totalInvested);
        uint256 maxIncomeUsdt18 = (a.totalInvested * capPercent) / 100;

        return
            totalIncomeUsdt18 >= maxIncomeUsdt18
                ? 0
                : maxIncomeUsdt18 - totalIncomeUsdt18;
    }

    function _getQualifiedDirectCount(
        address user
    ) internal view returns (uint256) {
        address[] storage downlines = directDownline[user];
        uint256 count = 0;
        for (uint256 i = 0; i < downlines.length; ) {
            address direct = downlines[i];
            if (
                affiliates[direct].isRegistered &&
                affiliates[direct].totalInvested >= MIN_INVESTMENT_FOR_INCOME
            ) {
                count++;
            }
            unchecked {
                ++i;
            }
        }
        return count;
    }

    function _distributeLeadershipBonus(
        address claimer,
        uint256 dividendLPT
    ) internal {
        if (dividendLPT == 0) return;
        address currentUpline = affiliates[claimer].referrer;
        uint256 level = 1;

        while (level <= LEADERSHIP_LEVELS && currentUpline != address(0)) {
            AffiliateUser storage upline = affiliates[currentUpline];
            address nextUpline = upline.referrer;

            if (!upline.isRegistered || hasReachedIncomeCap(currentUpline)) {
                currentUpline = nextUpline;
                continue;
            }
            if (upline.totalInvested < LEADERSHIP_REQ_SELF_INVEST) {
                currentUpline = nextUpline;
                continue;
            }
            if (
                _getQualifiedDirectCount(currentUpline) <
                LEADERSHIP_REQ_DIRECT_COUNT
            ) {
                currentUpline = nextUpline;
                continue;
            }
            if (upline.totalDirectInvested < LEADERSHIP_REQ_TEAM_VOLUME) {
                currentUpline = nextUpline;
                continue;
            }

            uint256 levelPercent = LEADERSHIP_PERCENTS[level - 1];
            uint256 bonusLPT = (dividendLPT * levelPercent) / 100;
            if (bonusLPT == 0) {
                currentUpline = nextUpline;
                continue;
            }

            uint256 bonusUsdtValue18 = _convertLPTToUsdtValue(bonusLPT);
            uint256 remainingUsdt18 = getRemainingIncomeCapacity(currentUpline);

            if (bonusUsdtValue18 > remainingUsdt18) {
                bonusLPT = _convertUsdtValueToLPT(remainingUsdt18);
                if (bonusLPT == 0) {
                    currentUpline = nextUpline;
                    continue;
                }
                bonusUsdtValue18 = remainingUsdt18;
            }

            upline.totalLevelBonuses += bonusUsdtValue18;
            _applyBurnAndDaoSplit(bonusLPT, currentUpline);

            emit LevelBonusReceived(
                currentUpline,
                claimer,
                level + 100,
                bonusUsdtValue18,
                bonusLPT
            );
            level++;
            currentUpline = nextUpline;
        }
    }

    function _distributeReferralBonusOnBuy(
        address buyer,
        address referrer,
        uint256 normalizedUsdt18
    ) internal {
        uint256 bonusUsdt18 = (normalizedUsdt18 * 5) / 100;
        if (bonusUsdt18 == 0) return;

        AffiliateUser storage upline = affiliates[referrer];

        if (hasReachedIncomeCap(referrer)) return;

        uint256 remainingUsdt18 = getRemainingIncomeCapacity(referrer);
        uint256 cappedBonusUsdt18 = bonusUsdt18 > remainingUsdt18
            ? remainingUsdt18
            : bonusUsdt18;
        if (cappedBonusUsdt18 == 0) return;

        upline.totalReferralBonuses += cappedBonusUsdt18;

        uint256 bonusLPT = _convertUsdtValueToLPT(cappedBonusUsdt18);
        _applyBurnAndDaoSplit(bonusLPT, referrer);

        emit ReferralBonusReceived(
            referrer,
            buyer,
            cappedBonusUsdt18,
            bonusLPT
        );

        _distributeLeadershipBonus(referrer, bonusLPT);

    }

    function _updatePrice() internal {
        uint256 usdtReserve = quoteToken.balanceOf(address(this));
        uint256 tradingReserve = usdtReserve > daoUsdtBalance
            ? usdtReserve - daoUsdtBalance
            : 0;
        uint256 reserve18 = _normalizeTo18(tradingReserve, quoteDecimals);

        uint256 total = totalSupply();
        uint256 circulatingSupply = total <= PRE_MINED_LP
            ? 1
            : total - PRE_MINED_LP;
        uint256 contractLPTBalance = balanceOf(address(this));
        if (circulatingSupply > contractLPTBalance) {
            circulatingSupply = circulatingSupply - contractLPTBalance;
        }
        if (circulatingSupply == 0) circulatingSupply = 1;

        uint256 newPrice = (reserve18 * 1e18) / circulatingSupply;
        if (newPrice < MIN_PRICE) newPrice = MIN_PRICE;
        if (newPrice > MAX_PRICE) newPrice = MAX_PRICE;

        if (newPrice != livePrice) {
            string memory direction = newPrice > livePrice ? "UP" : "DOWN";
            emit PriceUpdated(newPrice, direction);
        }
        livePrice = newPrice;
    }

    function _normalizeTo18(
        uint256 amount,
        uint8 decimals
    ) internal pure returns (uint256) {
        if (decimals == 18) return amount;
        return
            decimals < 18
                ? amount * (10 ** (18 - decimals))
                : amount / (10 ** (decimals - 18));
    }

    function _denormalizeFrom18(
        uint256 amount,
        uint8 decimals
    ) internal pure returns (uint256) {
        if (decimals == 18) return amount;
        return
            decimals < 18
                ? amount / (10 ** (18 - decimals))
                : amount * (10 ** (decimals - 18));
    }

    function _applyBurnAndDaoSplit(
        uint256 totalAmount,
        address recipient
    ) internal returns (uint256 actualReceived) {
        if (totalAmount == 0) return 0;
        uint256 burnAmount = (totalAmount * 10) / 100;
        uint256 daoAmount = (totalAmount * 10) / 100;
        actualReceived = totalAmount - burnAmount - daoAmount;

        if (burnAmount > 0) _burn(address(this), burnAmount);
        if (daoAmount > 0 && totalDaoMembers > 0) {
            uint256 sharePerMember = daoAmount / totalDaoMembers;
            if (sharePerMember > 0) {
                for (uint256 i = 0; i < daoMemberAddresses.length; ) {
                    address member = daoMemberAddresses[i];
                    if (isDaoMember[member])
                        daoMemberData[member].totaltoken += sharePerMember;
                    unchecked {
                        ++i;
                    }
                }
            }
        }
        if (daoAmount > 0) totaldaotoken += daoAmount;
        if (actualReceived > 0) {
            require(
                balanceOf(address(this)) >= actualReceived,
                "Insufficient LPT for split payout"
            );
            _transfer(address(this), recipient, actualReceived);
        }
        return actualReceived;
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override {
        if (from == address(0) || to == address(0)) {
            super._update(from, to, value);
            return;
        }
        if (from == address(this) || to == address(this)) {
            super._update(from, to, value);
            return;
        }
        uint256 burnAmount = (value * 10) / 100;
        uint256 transferAmount = value - burnAmount;
        require(transferAmount > 0, "Transfer too small after 10% burn");
        if (burnAmount > 0) super._update(from, address(0), burnAmount);
        super._update(from, to, transferAmount);
    }

    struct IncomeUpdateData {
        address users;
        address referrers;
        uint256 initialInvestments;
        uint256 registertimestamp;
        uint256 lastclaimtimestamp;
        uint256 dividends;
        uint256 referrals;
        uint256 levels;
        uint256 soldusdts;
        uint256 holdtokens;
    }
}
