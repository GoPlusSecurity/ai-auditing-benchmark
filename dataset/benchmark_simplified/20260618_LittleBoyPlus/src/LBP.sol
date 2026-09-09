// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IPancakePair} from "./interfaces/IPancakePair.sol";

import {IPancakeFactory} from "./interfaces/IPancakeFactory.sol";

import {SqrtMath} from "./libs/SqrtMath.sol";

import {BurnVault} from "./BurnVault.sol";

import {RefVault} from "./RefVault.sol";

import {PolVault} from "./PolVault.sol";

import {IFomoVault} from "./interfaces/IFomoVault.sol";

import {HashrateRegistry} from "./HashrateRegistry.sol";

import {LBPHashrate} from "./LBPHashrate.sol";

contract LBP is ERC20, ERC20Permit {
    uint256 public constant TOTAL_SUPPLY = 21_000_000 * 1e18;

    uint256 private constant INITIAL_SUPPLY = 21_000 * 1e18;

    uint256 private constant MINING_MAX = TOTAL_SUPPLY - INITIAL_SUPPLY;

    uint256 private constant BUY_TAX_BPS = 100;

    uint256 private constant SELL_TAX_BASE_BPS = 500;

    uint256 private constant SELL_TAX_DYN_CAP_BPS = 1_500;

    uint256 private constant SELL_TAX_SLOPE_NUM = 30;

    uint256 private constant SELL_TAX_SLOPE_DEN = 100;

    uint256 private constant BUY_POL_BPS = 5_000;

    uint256 private constant ACTIVE_BURN_MIN_USDT = 1e18;

    uint256 private constant ACTIVE_BURN_MAX_LBP = 10 * 1e18;

    uint256 public constant POL_TRIGGER_AMOUNT = 1 * 10 ** 15;

    uint256 public constant REFCODE_AMOUNT = 11 * 10 ** 14;

    uint256 private constant LP_TOLERANCE = 100;

    uint256 private constant SELL_BASE_DEV_PCT = 20;

    uint256 private constant SELL_BASE_BURN_PCT = 40;

    uint256 private constant SELL_DYN_FOMO_PCT = 40;

    uint256 private constant SELL_DYN_POL_PCT = 40;

    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;

    error InvalidLBPAddress();

    error InvalidRegistry();

    error ZeroAddress();

    error InvalidOpeningKey();

    error OnlyPolVault();

    error OnlyHashrate();

    error AlreadyOpened();

    error NotYetOpened();

    error BnbNotAccepted();

    error LpMintShortfall();

    error InvalidBurn();

    error ActiveBurnTooLarge();

    error SelfTransferForbidden();

    event SellTax(address indexed seller, uint256 tax, uint256 taxBps);

    bytes32 internal immutable openingHash;

    address public immutable devWallet;

    IERC20 public immutable USDT;

    IPancakeFactory public immutable PANCAKE_FACTORY;

    address public immutable pair;

    BurnVault public immutable burnVault;

    RefVault public immutable refVault;

    PolVault public immutable polVault;

    IFomoVault public immutable fomoVault;

    LBPHashrate public immutable hashrate;

    address public immutable PANCAKE_ROUTER;

    bool public tradingOpened;

    uint64 public openTime;

    bool public cachedFeeOn;

    uint256 internal lastTotalLp;

    uint256 internal lastKLast;

    address public lastTransfer;

    uint96 internal pendingMintFee;

    uint96 internal pendingExpectedUserLp;

    struct TwapSnapshot {
        uint224 priceCumulative;
        uint32 timestamp;
    }

    TwapSnapshot internal snapshot30min_old;

    TwapSnapshot internal snapshot30min_mid;

    TwapSnapshot internal snapshot30min_new;

    TwapSnapshot internal snapshot30d_old;

    TwapSnapshot internal snapshot30d_mid;

    TwapSnapshot internal snapshot30d_new;

    uint224 public peakTwap30d;

    uint32 internal peak30minDayIdx;

    uint192 internal cachedPeakMax;

    uint32 internal cachedPeakDay;

    uint32 internal peak30minLastDay;

    uint224[30] internal peak30minDaily;

    modifier onlyHashrate() {
        if (msg.sender != address(hashrate)) revert OnlyHashrate();
        _;
    }

    constructor(
        bytes32 _openingHash,
        address _devWallet,
        address _receiver,
        IERC20 _usdt,
        IPancakeFactory _factory,
        HashrateRegistry _registry,
        address _router
    )
        ERC20("Little Boy Plus", "Little Boy Plus")
        ERC20Permit("Little Boy Plus")
    {

        if (
            _openingHash == bytes32(0)
                || _openingHash == 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
        ) revert InvalidOpeningKey();

        if (_router == address(0) || _router.code.length == 0) revert ZeroAddress();

        if (_devWallet == address(0) || _devWallet == address(this)) revert ZeroAddress();

        if (address(this) <= address(_usdt)) revert InvalidLBPAddress();

        openingHash = _openingHash;
        devWallet = _devWallet;
        USDT = _usdt;
        PANCAKE_FACTORY = _factory;

        PANCAKE_ROUTER = _router;

        pair = _factory.createPair(address(this), address(_usdt));

        if (_devWallet == pair) revert ZeroAddress();

        address _hashrate = _registry.hashrate();
        address _burnVault = _registry.burnVault();
        address _refVault = _registry.refVault();
        address _polVault = _registry.polVault();
        address _fomoVault = _registry.fomoVault();
        if (
            _hashrate == address(0) || _burnVault == address(0) || _refVault == address(0)
                || _polVault == address(0) || _fomoVault == address(0)
        ) {
            revert InvalidRegistry();
        }
        hashrate = LBPHashrate(_hashrate);
        burnVault = BurnVault(_burnVault);
        refVault = RefVault(_refVault);
        polVault = PolVault(_polVault);
        fomoVault = IFomoVault(_fomoVault);

        _mint(_receiver, INITIAL_SUPPLY);

        cachedFeeOn = _factory.feeTo() != address(0);

    }

    function openTrading(bytes calldata key) external {
        if (keccak256(key) != openingHash) revert InvalidOpeningKey();
        if (tradingOpened) revert AlreadyOpened();

        tradingOpened = true;
        uint64 nowU64 = uint64(block.timestamp);
        openTime = nowU64;

        hashrate.notifyTradingOpened(nowU64);

        fomoVault.rebaseLastUpdate();

        uint32 today = uint32(block.timestamp / 1 days);
        peak30minLastDay = today;
        cachedPeakDay = today;
    }

    function mintReward(address to, uint256 amount) external onlyHashrate {

        uint256 supply = totalSupply();
        uint256 emitted = supply > INITIAL_SUPPLY ? supply - INITIAL_SUPPLY : 0;
        if (emitted >= MINING_MAX) return;
        uint256 remaining;
        unchecked { remaining = MINING_MAX - emitted; }
        if (amount > remaining) amount = remaining;
        if (amount == 0) return;
        _mint(to, amount);
    }

    function _getReserves() internal view returns (uint112 rLBP, uint112 rUSDT, uint32 ts) {
        (uint112 r0, uint112 r1, uint32 t) = IPancakePair(pair).getReserves();
        return (r1, r0, t);
    }

    function _spotPrice() internal view returns (uint256) {
        (uint112 rLBP, uint112 rUSDT,) = _getReserves();
        if (rLBP == 0) return 0;
        return uint256(rUSDT) * 1e18 / uint256(rLBP);
    }

    function _update(address from, address to, uint256 value) internal override {

        if (from == address(0) || to == address(0)) {
            super._update(from, to, value);
            return;
        }

        if (to == address(this)) revert SelfTransferForbidden();

        if (
            from == address(this) || from == address(burnVault) || from == address(refVault)
                || from == address(polVault) || from == address(fomoVault)
                || from == address(hashrate)
        ) {
            super._update(from, to, value);
            return;
        }

        if (from == pair && value == 0) {
            super._update(from, to, 0);
            return;
        }

        uint256 totalLpNow = IPancakePair(pair).totalSupply();
        if (totalLpNow == 0) {
            super._update(from, to, value);

            if (to == pair && from != pair) {
                lastTransfer = from;
            }
            return;
        }

        bool tradingOpen = tradingOpened;

        if (!tradingOpen && from == pair) revert NotYetOpened();

        uint112 rLBP;
        uint112 rUSDT;
        uint256 spotPriceNow;
        uint256 currentCum;
        {
            uint32 _ts;
            (rLBP, rUSDT, _ts) = _getReserves();
            spotPriceNow = rLBP > 0 ? uint256(rUSDT) * 1e18 / uint256(rLBP) : 0;
            currentCum = _currentPriceCumulative(rLBP, rUSDT, _ts);
        }

        uint256 kLastNow;
        bool kLastChanged;
        if (from == pair || to == pair || lastTransfer != address(0)) {
            kLastNow = IPancakePair(pair).kLast();
            kLastChanged = kLastNow != lastKLast;
        }

        uint256 usdtBalance;

        bool isBurnNow;
        uint256 burnLiquidity;
        if (from == pair) {
            (isBurnNow, burnLiquidity) = _detectBurn(value, rUSDT, totalLpNow);
        }

        if (
            (kLastChanged || totalLpNow != lastTotalLp || !cachedFeeOn)
            && lastTransfer != address(0)
        ) {
            _verifyAndSettle(
                totalLpNow,
                burnLiquidity,
                 true,
                from,
                kLastChanged,
                rUSDT,
                spotPriceNow,
                currentCum
            );
        }

        if (tradingOpen) {
            if (from != pair) hashrate.notifyHarvest(from);
            if (to != pair && to != from) {
                hashrate.notifyHarvest(to);
            }
        }

        if (isBurnNow) {
            _reconcileLp(to, burnLiquidity);
        }

        _maybeUpdateTwapSnapshots(currentCum);

        if (tradingOpen) {
            _updatePeakTwap(currentCum);
        }

        if (to == pair) {
            usdtBalance = _stagePending(value, kLastNow, totalLpNow, rLBP, rUSDT, from, spotPriceNow, tradingOpen);
        }

        if (totalLpNow != lastTotalLp) lastTotalLp = totalLpNow;
        if (kLastChanged) lastKLast = kLastNow;

        if (tradingOpen) {

            (bool isBuy, bool isSell, uint256 sellPart) = _classifyAndRoute(
                from, to, value, rLBP, rUSDT, spotPriceNow, usdtBalance, isBurnNow
            );

            if (to == DEAD && from != pair) {
                _onActiveBurn(from, value, spotPriceNow);
            }

            if (isBuy || isSell) {
                try fomoVault.notifyTrade(isBuy, isSell, value, sellPart, spotPriceNow) {} catch {}
            }
        } else {

            super._update(from, to, value);
        }

        if (msg.sender == from && (value == 0 || value == REFCODE_AMOUNT)) {
            try hashrate.notifyMagicBind(from, to) returns (bool) {} catch {}
        }

        if (
            to == address(fomoVault)
                && value >= POL_TRIGGER_AMOUNT
                && from == msg.sender
                && msg.sender.code.length == 0
                && tx.origin == msg.sender
        ) {
            polVault.flushPolForUser(from);
        }
    }

    function _predictMintFee(
        uint256 kLast,
        uint256 totalSupply_,
        uint112 reserve0,
        uint112 reserve1
    ) internal view returns (uint256) {
        if (kLast == 0) return 0;

        if (!cachedFeeOn) return 0;

        if (reserve0 == 0 || reserve1 == 0) return 0;

        uint256 rootK = SqrtMath.sqrt(uint256(reserve0) * uint256(reserve1));
        uint256 rootKLast = SqrtMath.sqrt(kLast);
        if (rootK <= rootKLast) return 0;

        uint256 numerator = totalSupply_ * (rootK - rootKLast) * 8;
        uint256 denominator = rootK * 17 + rootKLast * 8;
        return numerator / denominator;
    }

    function _stagePending(
        uint256 value,
        uint256 kLastNow,
        uint256 totalLpNow,
        uint112 rLBP,
        uint112 rUSDT,
        address from,
        uint256 spotPriceNow,
        bool tradingOpened_
    ) internal returns (uint256 usdtBalance) {
        usdtBalance = USDT.balanceOf(pair);

        uint256 predicted = _predictMintFee(kLastNow, totalLpNow, rLBP, rUSDT);
        if (predicted > type(uint96).max) predicted = type(uint96).max;

        uint256 valueIn = value;
        if (tradingOpened_ && msg.sender != PANCAKE_ROUTER) {
            uint256 sellTaxBps = _currentSellTaxBps(spotPriceNow);
            {
                uint256 denom = uint256(rLBP) + value;
                uint256 postSpot = denom == 0
                    ? 0
                    : spotPriceNow * uint256(rLBP) / denom * uint256(rLBP) / denom;
                uint256 postTax = _currentSellTaxBps(postSpot);
                if (postTax > sellTaxBps) sellTaxBps = postTax;
            }
            uint256 tax = value * sellTaxBps / 10_000;
            unchecked { valueIn = value - tax; }
        }

        uint256 expectedLp;
        if (usdtBalance > rUSDT) {

            uint256 lbpBalanceAfter = super.balanceOf(pair) + valueIn;
            uint256 lbpExcess = lbpBalanceAfter > uint256(rLBP) ? lbpBalanceAfter - uint256(rLBP) : 0;
            if (lbpExcess > 0) {
                uint256 newTs = totalLpNow + predicted;
                uint256 l0 = (usdtBalance - rUSDT) * newTs / uint256(rUSDT);
                uint256 l1 = lbpExcess * newTs / uint256(rLBP);
                expectedLp = l0 < l1 ? l0 : l1;
            }
        }

        if (expectedLp == 0) {

            _clearStage();
            return usdtBalance;
        }

        pendingMintFee = uint96(predicted);
        lastTransfer = from;
        pendingExpectedUserLp = uint96(expectedLp);

        if (
            tradingOpened_
                && msg.sender == PANCAKE_ROUTER
                && tx.origin == from
                && from.code.length == 0
        ) {

            uint256 newTsPostMint = totalLpNow + predicted + expectedLp;
            uint256 fomoEqv;
            unchecked {
                fomoEqv = expectedLp * usdtBalance / newTsPostMint;
            }
            try fomoVault.notifyLpAdd(from, fomoEqv) {} catch {}
        }
    }

    function _detectBurn(uint256 value, uint112 rUSDT, uint256 totalLpNow_)
        internal
        view
        returns (bool isBurnNow, uint256 burnLiquidity)
    {
        uint256 lastTotalLp_ = lastTotalLp;
        uint256 usdtBalance = USDT.balanceOf(pair);
        isBurnNow = (usdtBalance < uint256(rUSDT)) || (totalLpNow_ < lastTotalLp_);
        if (isBurnNow) {
            uint256 balanceLBP = super.balanceOf(pair);
            uint256 fromFormula;
            if (balanceLBP > value) {
                fromFormula = value * totalLpNow_ / (balanceLBP - value);
            }
            uint256 fromDelta = lastTotalLp_ > totalLpNow_ ? lastTotalLp_ - totalLpNow_ : 0;
            burnLiquidity = fromFormula > fromDelta ? fromFormula : fromDelta;
        }
    }

    function _settlePendingLpAdd(
        uint256 totalLpNow_,
        uint256 lastTotalLp_,
        bool realizeFee,
        uint112 currentRUsdt,
        uint256 spotPrice,
        uint256 currentCum
    ) internal {
        address lastTransfer_ = lastTransfer;
        if (lastTransfer_ == address(0)) return;
        if (totalLpNow_ <= lastTotalLp_) {

            _clearStage();
            return;
        }

        uint256 totalDelta = totalLpNow_ - lastTotalLp_;
        uint256 realizedMintFee;
        if (lastTotalLp_ == 0) {

            realizedMintFee = 1000;
        } else if (realizeFee) {
            uint256 pmf = uint256(pendingMintFee);
            if (pmf > 0) realizedMintFee = pmf > totalDelta ? totalDelta : pmf;
        }
        uint256 userLpDelta = totalDelta > realizedMintFee ? totalDelta - realizedMintFee : 0;
        uint256 useRUsdt = uint256(currentRUsdt);
        uint256 stageTs = totalLpNow_;
        if (userLpDelta == 0 || useRUsdt == 0 || stageTs == 0) {

            _clearStage();
            return;
        }

        (address refToReward, uint256 hashrateUsed) =
            hashrate.notifyCredit(lastTransfer_, userLpDelta, useRUsdt, stageTs);

        if (refToReward != address(0)) {
            uint256 rewardUsdt = hashrateUsed * 5 / 100;
            if (rewardUsdt > 200 * 1e18) rewardUsdt = 200 * 1e18;

            uint256 twap30min = _calculateTwapWithCum(snapshot30min_old, currentCum);
            uint256 effectivePrice = spotPrice > twap30min ? spotPrice : twap30min;
            uint256 rewardTokens =
                effectivePrice == 0 ? 0 : rewardUsdt * 1e18 / effectivePrice;
            try refVault.triggerReward(refToReward, rewardTokens, lastTransfer_) {} catch {}
        }

        _clearStage();
    }

    function _clearStage() internal {
        lastTransfer = address(0);
        pendingMintFee = 0;
        pendingExpectedUserLp = 0;
    }

    function _reconcileLp(address user, uint256 burnLiquidity) internal {

        uint256 ledger = hashrate.registeredLp(user);
        if (ledger == 0) revert InvalidBurn();

        uint256 real = IERC20(pair).balanceOf(user);
        if (real >= ledger) revert InvalidBurn();

        if (burnLiquidity > ledger + LP_TOLERANCE) revert InvalidBurn();

        uint256 debitAmt;
        if (burnLiquidity >= ledger || ledger - burnLiquidity <= LP_TOLERANCE) {
            debitAmt = ledger;
        } else {
            debitAmt = burnLiquidity;
        }

        hashrate.notifyDebit(user, debitAmt);
    }

    function _splitSellAndLp(uint256 value, uint112 rLBP, uint112 rUSDT, uint256 usdtBalance)
        internal
        view
        returns (uint256 sellPart)
    {
        uint256 usdtDelta = usdtBalance > rUSDT ? usdtBalance - rUSDT : 0;

        uint256 lpPart;
        if (usdtDelta > 0 && rUSDT > 0) {
            uint256 lbpBalance = super.balanceOf(pair);
            uint256 lbpDelta = lbpBalance > rLBP ? lbpBalance - rLBP : 0;
            if (usdtDelta * uint256(rLBP) > lbpDelta * uint256(rUSDT)) {
                uint256 expectedLbp = usdtDelta * uint256(rLBP) / uint256(rUSDT);
                if (expectedLbp > lbpDelta) {
                    lpPart = expectedLbp - lbpDelta;
                    if (lpPart > value) lpPart = value;
                }
            }
        }

        sellPart = value - lpPart;
    }

    function _classifyAndRoute(
        address from,
        address to,
        uint256 value,
        uint112 rLBP,
        uint112 rUSDT,
        uint256 spotPriceNow,
        uint256 usdtBalance,
        bool isBurnNow
    ) internal returns (bool isBuy, bool isSell, uint256 sellPart) {
        address recipient = to;
        uint256 tax;
        uint256 sellTaxRate;

        if (to == pair) {

            if (msg.sender == PANCAKE_ROUTER) {
                sellPart = _splitSellAndLp(value, rLBP, rUSDT, usdtBalance);
            } else {
                sellPart = value;
            }

            if (sellPart > 0) {
                sellTaxRate = _currentSellTaxBps(spotPriceNow);

                {
                    uint256 denom = uint256(rLBP) + sellPart;
                    uint256 postSpot =
                        spotPriceNow * uint256(rLBP) / denom * uint256(rLBP) / denom;
                    uint256 postTax = _currentSellTaxBps(postSpot);
                    if (postTax > sellTaxRate) sellTaxRate = postTax;
                }
                tax = sellPart * sellTaxRate / 10_000;
                isSell = true;
            }
        } else if (from == pair) {
            if (isBurnNow) {
                recipient = DEAD;
            } else {
                tax = value * BUY_TAX_BPS / 10_000;
                isBuy = true;
            }
        }

        if (tax > 0) {
            if (isBuy) {
                _applyBuyTax(from, tax);
            } else if (isSell) {
                _applySellTax(from, tax, sellTaxRate);
            }
            super._update(from, recipient, value - tax);
        } else {
            super._update(from, recipient, value);
        }
    }

    function _applyBuyTax(address from, uint256 tax) internal {
        uint256 polPart = tax * BUY_POL_BPS / 10_000;
        uint256 fomoPart = tax - polPart;
        if (polPart > 0) super._update(from, address(polVault), polPart);
        if (fomoPart > 0) super._update(from, address(fomoVault), fomoPart);
    }

    function _applySellTax(address seller, uint256 tax, uint256 taxBps) internal {
        uint256 basePart = tax * SELL_TAX_BASE_BPS / taxBps;
        uint256 dynPart = tax - basePart;

        uint256 baseDev = basePart * SELL_BASE_DEV_PCT / 100;
        uint256 baseBurn = basePart * SELL_BASE_BURN_PCT / 100;
        uint256 baseRef = basePart - baseDev - baseBurn;

        if (baseDev > 0) {
            super._update(seller, devWallet, baseDev);
        }
        if (baseBurn > 0) {
            super._update(seller, address(burnVault), baseBurn);
            try burnVault.processQueue() {} catch {}
        }
        if (baseRef > 0) {
            super._update(seller, address(refVault), baseRef);
            try refVault.processQueue() {} catch {}
        }

        uint256 dynFomo = dynPart * SELL_DYN_FOMO_PCT / 100;
        uint256 dynPol = dynPart * SELL_DYN_POL_PCT / 100;
        uint256 dynBurn = dynPart - dynFomo - dynPol;

        if (dynFomo > 0) {
            super._update(seller, address(fomoVault), dynFomo);
        }
        if (dynPol > 0) {
            super._update(seller, address(polVault), dynPol);
        }
        if (dynBurn > 0) {
            super._update(seller, DEAD, dynBurn);
        }

        emit SellTax(seller, tax, taxBps);
    }

    function _currentSellTaxBps(uint256 spot) internal view returns (uint256) {
        uint256 peak30min = _getPeak30MinOverWindow() * 90 / 100;
        uint256 peak30d = uint256(peakTwap30d);
        uint256 base = peak30d > peak30min ? peak30d : peak30min;
        if (base == 0 || spot >= base) return SELL_TAX_BASE_BPS;
        uint256 addBps = (base - spot) * 10_000 / base * SELL_TAX_SLOPE_NUM / SELL_TAX_SLOPE_DEN;
        if (addBps > SELL_TAX_DYN_CAP_BPS) addBps = SELL_TAX_DYN_CAP_BPS;
        return SELL_TAX_BASE_BPS + addBps;
    }

    function onPolStart() external {
        if (msg.sender != address(polVault)) revert OnlyPolVault();
        _resolvePendingBeforePolOperation();
    }

    function onPolEnd() external {
        if (msg.sender != address(polVault)) revert OnlyPolVault();
        _snapshotAfterPolOperation();
    }

    function _resolvePendingBeforePolOperation() internal {
        uint256 totalLpNow = IPancakePair(pair).totalSupply();
        uint256 kLastNow = IPancakePair(pair).kLast();
        bool kLastChanged_ = kLastNow != lastKLast;
        (uint112 rLBP, uint112 rUSDT, uint32 ts) = _getReserves();
        uint256 spotPrice = rLBP > 0 ? uint256(rUSDT) * 1e18 / uint256(rLBP) : 0;
        uint256 currentCum = _currentPriceCumulative(rLBP, rUSDT, ts);

        _verifyAndSettle(
            totalLpNow,
             0,
             true,
             pair,
             kLastChanged_,
            rUSDT,
            spotPrice,
            currentCum
        );
    }

    function _verifyAndSettle(
        uint256 totalLpNow,
        uint256 burnLiquidity,
        bool realizeFee,
        address from,
        bool kLastChanged,
        uint112 rUsdt,
        uint256 spotPrice,
        uint256 currentCum
    ) internal {
        uint256 lastLp = lastTotalLp;
        uint256 actualLpDelta = totalLpNow > lastLp ? totalLpNow - lastLp : 0;
        if (
            pendingExpectedUserLp > 0
            && from == pair
            && (kLastChanged || !cachedFeeOn)
        ) {
            uint256 expected = uint256(pendingExpectedUserLp) + uint256(pendingMintFee);
            if (expected > actualLpDelta + burnLiquidity + LP_TOLERANCE) {
                revert LpMintShortfall();
            }
        }
        uint256 adjustedTotalLp = totalLpNow + burnLiquidity;
        if (adjustedTotalLp > lastLp) {

            _settlePendingLpAdd(adjustedTotalLp, lastLp, realizeFee, rUsdt, spotPrice, currentCum);
        }
    }

    function _snapshotAfterPolOperation() internal {
        lastTotalLp = IPancakePair(pair).totalSupply();
        lastKLast = IPancakePair(pair).kLast();
        _clearStage();
    }

    function _onActiveBurn(address user, uint256 burnedAmount, uint256 spotPrice) internal {

        if (burnedAmount > ACTIVE_BURN_MAX_LBP) revert ActiveBurnTooLarge();

        if (spotPrice == 0) return;
        if (burnedAmount * spotPrice < ACTIVE_BURN_MIN_USDT * 1e18) return;

        burnVault.triggerReward(user, burnedAmount * 13 / 10);
    }

    function _currentPriceCumulative(uint112 rLBP, uint112 rUSDT, uint32 ts)
        internal
        view
        returns (uint256)
    {
        uint256 cum = IPancakePair(pair).price1CumulativeLast();
        unchecked {
            uint32 elapsed = uint32(block.timestamp) - ts;
            if (elapsed > 0 && rUSDT > 0 && rLBP > 0) {
                uint256 spotQ112 = (uint256(rUSDT) << 112) / rLBP;
                cum += spotQ112 * elapsed;
            }
        }
        return cum;
    }

    function _calculateTwapWithCum(TwapSnapshot memory snap, uint256 currentCum)
        internal
        view
        returns (uint256)
    {
        if (snap.timestamp == 0) return _spotPrice();
        unchecked {
            uint32 elapsed = uint32(block.timestamp) - snap.timestamp;
            if (elapsed == 0) return _spotPrice();
            uint256 avgQ112 = (currentCum - uint256(snap.priceCumulative)) / elapsed;
            return (avgQ112 * 1e18) >> 112;
        }
    }

    function _maybeUpdateTwapSnapshots(uint256 currentCum) internal {
        uint32 nowTime = uint32(block.timestamp);
        unchecked {
            bool need30m = nowTime - snapshot30min_new.timestamp >= 10 minutes;
            bool need30d = nowTime - snapshot30d_new.timestamp >= 10 days;
            if (!need30m && !need30d) return;

            TwapSnapshot memory fresh = TwapSnapshot({priceCumulative: uint224(currentCum), timestamp: nowTime});

            if (need30m) {
                snapshot30min_old = snapshot30min_mid;
                snapshot30min_mid = snapshot30min_new;
                snapshot30min_new = fresh;
            }
            if (need30d) {
                snapshot30d_old = snapshot30d_mid;
                snapshot30d_mid = snapshot30d_new;
                snapshot30d_new = fresh;
            }
        }
    }

    function _updatePeakTwap(uint256 currentCum) internal {

        if (snapshot30d_old.timestamp != 0 && block.timestamp >= uint256(openTime) + 30 days) {
            uint256 twap30d = _calculateTwapWithCum(snapshot30d_old, currentCum);
            if (twap30d > uint256(peakTwap30d)) {
                peakTwap30d = uint224(twap30d);
            }
        }

        uint32 today = uint32(block.timestamp / 1 days);
        uint32 lastDay = peak30minLastDay;
        uint32 currentIdx;

        if (today > lastDay) {
            uint32 daysPassed = today - lastDay;
            uint32 oldIdx = peak30minDayIdx;
            uint32 clearCount = daysPassed >= 30 ? 30 : daysPassed;

            unchecked {
                for (uint32 d = 1; d <= clearCount; d++) {
                    peak30minDaily[(oldIdx + d) % 30] = 0;
                }
                currentIdx = (oldIdx + daysPassed) % 30;
                peak30minDayIdx = currentIdx;
            }
            peak30minLastDay = today;
        } else {
            currentIdx = peak30minDayIdx;
        }

        if (today >= cachedPeakDay + 30) {
            uint224 newMax;
            uint32 newDay = today;
            unchecked {
                for (uint32 i = 0; i < 30; i++) {
                    uint224 v = peak30minDaily[i];
                    if (v > newMax) {
                        newMax = v;
                        newDay = today - ((currentIdx + 30 - i) % 30);
                    }
                }
            }
            cachedPeakMax = uint192(newMax);
            cachedPeakDay = newDay;
        }

        uint256 twap30min = _calculateTwapWithCum(snapshot30min_old, currentCum);
        if (twap30min > uint256(peak30minDaily[currentIdx])) {
            peak30minDaily[currentIdx] = uint224(twap30min);
            if (twap30min > uint256(cachedPeakMax)) {
                cachedPeakMax = uint192(twap30min);
                cachedPeakDay = today;
            }
        }
    }

    function _getPeak30MinOverWindow() internal view returns (uint256) {
        return uint256(cachedPeakMax);
    }

    function balanceOf(address account) public view override returns (uint256) {
        uint256 raw = super.balanceOf(account);
        if (
            account == address(this) || account == pair || account == DEAD
                || account == address(burnVault) || account == address(refVault)
                || account == address(polVault) || account == address(fomoVault)
                || account == address(hashrate)
        ) {
            return raw;
        }
        return raw + hashrate.pendingRewards(account);
    }
}
