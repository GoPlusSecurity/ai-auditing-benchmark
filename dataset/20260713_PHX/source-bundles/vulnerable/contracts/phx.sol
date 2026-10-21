// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IPancakeFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IPancakeRouter {
    function factory() external view returns (address);
    function WETH() external view returns (address);
}

interface IPancakePair {
    function token0() external view returns (address);
    function token1() external view returns (address);

    function getReserves() external view returns (
        uint112 reserve0,
        uint112 reserve1,
        uint32 blockTimestampLast
    );

    function sync() external;
}

interface AggregatorV3Interface {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );

    function decimals() external view returns (uint8);
}

contract PHX is ERC20, Ownable {
    uint256 public constant TOTAL_SUPPLY = 10_000_000 * 1e18;
    uint256 public constant DENOMINATOR = 10_000;
    uint256 public constant PAIR_RELEASE_RATE_PRECISION = 1_000_000;
    uint256 public maxPairReleasesPerDay = 24;

    uint256 private constant RELEASE_RATE_LE_1M = 1_000;
    uint256 private constant RELEASE_RATE_1M_3M = 875;
    uint256 private constant RELEASE_RATE_3M_10M = 750;
    uint256 private constant RELEASE_RATE_GT_10M = 625;

    uint256 private constant USD_THRESHOLD_1M = 1_000_000e18;
    uint256 private constant USD_THRESHOLD_3M = 3_000_000e18;
    uint256 private constant USD_THRESHOLD_10M = 10_000_000e18;

    uint256 public sellPairBurnRate = 5000;

    uint256 public pairBurnMultiplier = 10_000;
    uint256 public constant MULTIPLIER_DENOMINATOR = 10_000;

    address public router;
    address public wbnb;
    address public pair;

    AggregatorV3Interface public priceFeed;

    address public operationWallet;
    address public lpWallet;
    address public foundationWallet;

    address public lpPhxOperator;
    address public miningContract;

    bool public buyWhitelistEnabled = false;
    bool private inFee;

    uint256 private releaseDay;
    uint256 private releaseCountToday;

    mapping(address => bool) public isBuyWhitelist;
    mapping(address => bool) public isBuySellFeeExempt;
    mapping(address => bool) public isTransferFeeExempt;
    mapping(address => bool) public isAMMPair;
    mapping(address => bool) public isMinter;

    uint256 public buyOperationFee = 600;
    uint256 public buyLpFee = 200;
    uint256 public buyFoundationFee = 200;

    uint256 public sellOperationFee = 900;
    uint256 public sellLpFee = 300;
    uint256 public sellFoundationFee = 300;
    uint256 public sellBurnFee = 1500;
    event SellBurnFeeUpdated(uint256 fee);

    uint256 public transferOperationFee = 1500;
    uint256 public transferBurnFee = 1000;
    uint256 public transferFoundationFee = 500;

    event PairCreated(address pair);
    event PairSet(address pair, bool status);

    event PairPhxBurnedFromLp(
        address indexed caller,
        uint256 amount,
        uint256 poolBnbValueUsd,
        uint256 releaseRatePpm
    );

    event MiningContractUpdated(address indexed miningContract);
    event LpPhxOperatorUpdated(address indexed operator);
    event PriceFeedUpdated(address indexed priceFeed);
    event MinterUpdated(address indexed account, bool status);
    event Minted(address indexed minter, address indexed to, uint256 amount);

    event SellPairBurnRateUpdated(uint256 rate);
    event SellPairBurned(address indexed caller, uint256 amount);
    event PairBurnMultiplierUpdated(uint256 multiplier);
    event MaxPairReleasesPerDayUpdated(uint256 maxReleasesPerDay);

    modifier onlyMinter() {
        require(isMinter[msg.sender], "not minter");
        _;
    }

    constructor(
        address _router,
        address _operationWallet,
        address _lpWallet,
        address _foundationWallet,
        address _owner,
        address _priceFeed
    ) ERC20("PHX", "PHX") Ownable(_owner) {
        require(_router != address(0), "router zero");
        require(_operationWallet != address(0), "operation zero");
        require(_lpWallet != address(0), "lp zero");
        require(_foundationWallet != address(0), "foundation zero");
        require(_owner != address(0), "owner zero");
        require(_priceFeed != address(0), "price feed zero");

        router = _router;
        operationWallet = _operationWallet;
        lpWallet = _lpWallet;
        foundationWallet = _foundationWallet;
        lpPhxOperator = _owner;
        priceFeed = AggregatorV3Interface(_priceFeed);

        wbnb = IPancakeRouter(_router).WETH();
        address factory = IPancakeRouter(_router).factory();

        pair = IPancakeFactory(factory).createPair(address(this), wbnb);
        isAMMPair[pair] = true;

        _setFeeWalletExempt(_owner);
        _setFeeWalletExempt(_operationWallet);
        _setFeeWalletExempt(_lpWallet);
        _setFeeWalletExempt(_foundationWallet);

        isBuyWhitelist[_owner] = true;
        isMinter[_owner] = true;

        _mint(_owner, TOTAL_SUPPLY);

        emit PairCreated(pair);
    }

    function _setFeeWalletExempt(address account) internal {
        isBuySellFeeExempt[account] = true;
        isTransferFeeExempt[account] = true;
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (from == address(0) || to == address(0)) {
            super._update(from, to, amount);
            return;
        }

        if (inFee) {
            super._update(from, to, amount);
            return;
        }

        bool isBuy = isAMMPair[from];
        bool isSell = isAMMPair[to];
        bool isTransfer = !isBuy && !isSell;

        if (isBuy && buyWhitelistEnabled) {
            require(isBuyWhitelist[to], "not in buy whitelist");
        }

        if (isBuy || isSell) {
            if (isBuySellFeeExempt[from] || isBuySellFeeExempt[to]) {
                super._update(from, to, amount);
                return;
            }
        }

        if (isTransfer) {
            if (isTransferFeeExempt[from] || isTransferFeeExempt[to]) {
                super._update(from, to, amount);
                return;
            }
        }

        if (isBuy) {
            _takeBuyFee(from, to, amount);
        } else if (isSell) {
            _takeSellFee(from, to, amount);
        } else {
            _takeTransferFee(from, to, amount);
        }
    }

    function _takeBuyFee(address from, address to, uint256 amount) internal {
        uint256 opFee = amount * buyOperationFee / DENOMINATOR;
        uint256 lpFee = amount * buyLpFee / DENOMINATOR;
        uint256 fundFee = amount * buyFoundationFee / DENOMINATOR;
        uint256 receiveAmount = amount - opFee - lpFee - fundFee;

        inFee = true;
        super._update(from, operationWallet, opFee);
        super._update(from, lpWallet, lpFee);
        super._update(from, foundationWallet, fundFee);
        super._update(from, to, receiveAmount);
        inFee = false;
    }

    function _takeSellFee(address from, address to, uint256 amount) internal {
        uint256 opFee = amount * sellOperationFee / DENOMINATOR;
        uint256 lpFee = amount * sellLpFee / DENOMINATOR;
        uint256 fundFee = amount * sellFoundationFee / DENOMINATOR;
        uint256 burnFee = amount * sellBurnFee / DENOMINATOR;
        uint256 receiveAmount = amount - opFee - lpFee - fundFee - burnFee;

        uint256 pairBurnAmount = amount * sellPairBurnRate / DENOMINATOR;
        inFee = true;

        if (pairBurnAmount > 0) {
            uint256 pairBalance = balanceOf(pair);
            if (pairBurnAmount > pairBalance) {
                pairBurnAmount = pairBalance;
            }

            if (pairBurnAmount > 0) {
                _burn(pair, pairBurnAmount);
                IPancakePair(pair).sync();
                emit SellPairBurned(from, pairBurnAmount);
            }
        }

        super._update(from, operationWallet, opFee);
        super._update(from, lpWallet, lpFee);
        super._update(from, foundationWallet, fundFee);
        if (burnFee > 0) {
            _burn(from, burnFee);
        }
        super._update(from, to, receiveAmount);
        inFee = false;
    }

    function _takeTransferFee(address from, address to, uint256 amount) internal {
        uint256 opFee = amount * transferOperationFee / DENOMINATOR;
        uint256 burnFee = amount * transferBurnFee / DENOMINATOR;
        uint256 fundFee = amount * transferFoundationFee / DENOMINATOR;
        uint256 receiveAmount = amount - opFee - burnFee - fundFee;

        inFee = true;
        super._update(from, operationWallet, opFee);
        _burn(from, burnFee);
        super._update(from, foundationWallet, fundFee);
        super._update(from, to, receiveAmount);
        inFee = false;
    }

    function mint(address to, uint256 amount) external onlyMinter {
        require(to != address(0), "mint to zero");
        require(amount > 0, "amount zero");

        _mint(to, amount);

        emit Minted(msg.sender, to, amount);
    }

    function burnPairPhx() external {
        require(msg.sender == lpPhxOperator, "not lp phx operator");
        require(pair != address(0), "pair not set");

        uint256 today = block.timestamp / 1 days;
        if (today != releaseDay) {
            releaseDay = today;
            releaseCountToday = 0;
        }

        require(releaseCountToday < maxPairReleasesPerDay, "daily release limit");

        uint256 poolPhx = balanceOf(pair);
        require(poolPhx > 0, "empty pool phx");

        uint256 poolBnbValueUsd = _getPairBnbValueUsd();
        uint256 releaseRatePpm = _releaseRatePpm(poolBnbValueUsd);
        uint256 baseAmount = poolPhx * releaseRatePpm / PAIR_RELEASE_RATE_PRECISION;
        uint256 amount = baseAmount * pairBurnMultiplier / MULTIPLIER_DENOMINATOR;

        require(amount > 0, "burn amount zero");
        if (amount > poolPhx) {
            amount = poolPhx;
        }
        releaseCountToday += 1;

        _burn(pair, amount);

        IPancakePair(pair).sync();

        emit PairPhxBurnedFromLp(
            msg.sender,
            amount,
            poolBnbValueUsd,
            releaseRatePpm
        );
    }

    function getPairBnbValueUsd() public view returns (uint256) {
        require(pair != address(0), "pair not set");
        uint256 wbnbReserve = _getPairWbnbReserve();
        return _wbnbToUsd(wbnbReserve);
    }

    function previewPairPhxRelease() public view returns (
        uint256 amount,
        uint256 poolBnbValueUsd,
        uint256 releaseRatePpm
    ) {
        require(pair != address(0), "pair not set");

        uint256 poolPhx = balanceOf(pair);
        poolBnbValueUsd = _getPairBnbValueUsd();
        releaseRatePpm = _releaseRatePpm(poolBnbValueUsd);
        amount = poolPhx * releaseRatePpm / PAIR_RELEASE_RATE_PRECISION;
    }

    function getPairPhxReleaseStatus() external view returns (
        uint256 todayReleaseCount,
        uint256 releasesRemainingToday,
        uint256 poolBnbValueUsd,
        uint256 nextReleaseAmount,
        uint256 releaseRatePpm
    ) {
        uint256 today = block.timestamp / 1 days;

        todayReleaseCount = today == releaseDay ? releaseCountToday : 0;

        releasesRemainingToday =
            todayReleaseCount >= maxPairReleasesPerDay
                ? 0
                : maxPairReleasesPerDay - todayReleaseCount;

        poolBnbValueUsd = getPairBnbValueUsd();
        releaseRatePpm = _releaseRatePpm(poolBnbValueUsd);
        nextReleaseAmount = balanceOf(pair) * releaseRatePpm / PAIR_RELEASE_RATE_PRECISION;
    }

    function _releaseRatePpm(uint256 poolBnbValueUsd) internal pure returns (uint256) {
        if (poolBnbValueUsd <= USD_THRESHOLD_1M) {
            return RELEASE_RATE_LE_1M;
        }

        if (poolBnbValueUsd <= USD_THRESHOLD_3M) {
            return RELEASE_RATE_1M_3M;
        }

        if (poolBnbValueUsd <= USD_THRESHOLD_10M) {
            return RELEASE_RATE_3M_10M;
        }

        return RELEASE_RATE_GT_10M;
    }

    function _getPairWbnbReserve() internal view returns (uint256) {
        IPancakePair lp = IPancakePair(pair);
        (uint112 reserve0, uint112 reserve1, ) = lp.getReserves();

        if (lp.token0() == wbnb) {
            return uint256(reserve0);
        }

        return uint256(reserve1);
    }

    function _getPairBnbValueUsd() internal view returns (uint256) {
        return _wbnbToUsd(_getPairWbnbReserve());
    }

    function _wbnbToUsd(uint256 wbnbAmount) internal view returns (uint256) {
        require(address(priceFeed) != address(0), "price feed not set");

        (
            uint80 roundId,
            int256 price,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();

        require(price > 0, "invalid price");
        require(updatedAt > 0, "stale price");
        require(answeredInRound >= roundId, "incomplete round");
        require(block.timestamp - updatedAt <= 1 hours, "price too old");

        uint8 dec = priceFeed.decimals();

        return (wbnbAmount * uint256(price)) / (10 ** dec);
    }

    function setPriceFeed(address feed) external onlyOwner {
        require(feed != address(0), "price feed zero");

        priceFeed = AggregatorV3Interface(feed);

        emit PriceFeedUpdated(feed);
    }

    function setMiningContract(address account) external onlyOwner {
        require(account != address(0), "zero address");

        miningContract = account;
        _setFeeWalletExempt(account);

        emit MiningContractUpdated(account);
    }

    function setLpPhxOperator(address account) external onlyOwner {
        require(account != address(0), "zero address");

        lpPhxOperator = account;

        emit LpPhxOperatorUpdated(account);
    }

    function setMinter(address account, bool status) external onlyOwner {
        require(account != address(0), "zero address");

        isMinter[account] = status;

        emit MinterUpdated(account, status);
    }

    function setBuyWhitelistEnabled(bool status) external onlyOwner {
        buyWhitelistEnabled = status;
    }

    function setBuyWhitelist(address account, bool status) external onlyOwner {
        isBuyWhitelist[account] = status;
    }

    function setBuyWhitelistBatch(address[] calldata accounts, bool status) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            isBuyWhitelist[accounts[i]] = status;
        }
    }

    function setBuySellFeeExempt(address account, bool status) external onlyOwner {
        isBuySellFeeExempt[account] = status;
    }

    function setTransferFeeExempt(address account, bool status) external onlyOwner {
        isTransferFeeExempt[account] = status;
    }

    function setAMMPair(address account, bool status) external onlyOwner {
        isAMMPair[account] = status;

        emit PairSet(account, status);
    }

    function setWallets(
        address _operationWallet,
        address _lpWallet,
        address _foundationWallet
    ) external onlyOwner {
        require(_operationWallet != address(0), "operation zero");
        require(_lpWallet != address(0), "lp zero");
        require(_foundationWallet != address(0), "foundation zero");

        operationWallet = _operationWallet;
        lpWallet = _lpWallet;
        foundationWallet = _foundationWallet;

        _setFeeWalletExempt(_operationWallet);
        _setFeeWalletExempt(_lpWallet);
        _setFeeWalletExempt(_foundationWallet);
    }

    function setSellPairBurnRate(uint256 rate) external onlyOwner {
        require(rate <= DENOMINATOR, "rate too high");
        sellPairBurnRate = rate;
        emit SellPairBurnRateUpdated(rate);
    }

    function setPairBurnMultiplier(uint256 multiplier) external onlyOwner {
        require(multiplier > 0, "multiplier zero");
        require(multiplier <= 100_000, "multiplier too high");
        pairBurnMultiplier = multiplier;
        emit PairBurnMultiplierUpdated(multiplier);
    }

    function setMaxPairReleasesPer(uint256 maxReleasesPerDay) external onlyOwner {
        require(maxReleasesPerDay > 0, "max releases zero");
        maxPairReleasesPerDay = maxReleasesPerDay;
        emit MaxPairReleasesPerDayUpdated(maxReleasesPerDay);
    }

    function setSellBurnFee(uint256 fee) external onlyOwner {
        require(
            sellOperationFee + sellLpFee + sellFoundationFee + fee <= DENOMINATOR,
            "total sell fee too high"
        );
        sellBurnFee = fee;
        emit SellBurnFeeUpdated(fee);
    }
}
