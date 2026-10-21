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
        address _asset,
        address _registry,
        uint256 _maxAccOpenPnlDeltaPerToken,
        uint256 _maxDailyAccPnlDeltaPerToken,
        uint16 _maxSupplyIncreaseDailyP,
        uint16 _maxDiscountP,
        uint16 _maxDiscountThresholdP,
        uint16[2] memory _withdrawLockThresholdsP
    ) external initializer {
        if (
            _asset == address(0) || _registry == address(0) || _maxDailyAccPnlDeltaPerToken < MIN_DAILY_ACC_PNL_DELTA
                || _withdrawLockThresholdsP[1] <= _withdrawLockThresholdsP[0]
                || _maxSupplyIncreaseDailyP > MAX_SUPPLY_INCREASE_DAILY_P || _maxDiscountP > MAX_DISCOUNT_P
                || _maxDiscountThresholdP <= uint16(100) * PRECISION_2
        ) revert WrongParams();

        registry = IOstiumRegistry(_registry);

        __ERC20_init('ostiumLP', 'oLP');
        __ERC4626_init(IERC20Metadata(_asset));

        maxAccOpenPnlDeltaPerToken = _maxAccOpenPnlDeltaPerToken;
        maxDailyAccPnlDeltaPerToken = _maxDailyAccPnlDeltaPerToken;
        __DEPRECATED_withdrawLockThresholdsP = _withdrawLockThresholdsP;
        maxSupplyIncreaseDailyP = _maxSupplyIncreaseDailyP;
        __DEPRECATED_maxDiscountP = _maxDiscountP;
        __DEPRECATED_maxDiscountThresholdP = _maxDiscountThresholdP;

        currentEpoch = 1;
        shareToAssetsPrice = PRECISION_18;
        currentEpochStart = uint32(block.timestamp);
        __DEPRECATED_WITHDRAW_EPOCHS_LOCKS = [3, 2, 1];
    }

    function initializeV2() external reinitializer(2) {
        __DEPRECATED_totalLiability = 0;
        __DEPRECATED_totalDeposited = 0;
        __DEPRECATED_totalRewards = 0;
    }

    function initializeV3() external reinitializer(3) {
        // Set Settlement Interval
        maxSettlementInterval = 24 hours;

        // Migration script
        lastSettlementOpenPnl = __DEPRECATED_currentEpochPositiveOpenPnl.toInt256();

        // Obsolete variable
        __DEPRECATED_currentEpochPositiveOpenPnl = 0;
    }

    modifier onlyGov() {
        _onlyGov(_msgSender());
        _;
    }

    function _onlyGov(address a) private view {
        if (a != registry.gov()) revert NotGov(a);
    }

    modifier onlyCallbacks() {
        _onlyCallbacks(_msgSender());
        _;
    }

    function _onlyCallbacks(address a) private view {
        if (a != registry.getContractAddress('callbacks')) {
            revert NotCallbacks(a);
        }
    }

    modifier checks(uint256 assetsOrShares) {
        _checks(assetsOrShares);
        _;
    }

    function _checks(uint256 assetsOrShares) private view {
        if (assetsOrShares == 0) revert NullAmount();
        if (shareToAssetsPrice == 0) revert NullPrice();
    }

    function updateMaxAccOpenPnlDeltaPerToken(uint256 newValue) external onlyGov {
        maxAccOpenPnlDeltaPerToken = newValue;
        emit MaxAccOpenPnlDeltaPerTokenUpdated(newValue);
    }

    function updateMaxDailyAccPnlDeltaPerToken(uint256 newValue) external onlyGov {
        if (newValue < MIN_DAILY_ACC_PNL_DELTA) revert WrongParams();
        maxDailyAccPnlDeltaPerToken = newValue;
        emit MaxDailyAccPnlDeltaPerTokenUpdated(newValue);
    }

    function updateMaxSupplyIncreaseDailyP(uint256 newValue) external onlyGov {
        if (newValue > MAX_SUPPLY_INCREASE_DAILY_P) revert WrongParams();
        maxSupplyIncreaseDailyP = newValue.toUint16();
        emit MaxSupplyIncreaseDailyPUpdated(newValue);
    }

    function updateMaxSettlementInterval(uint32 newValue) external onlyGov {
        if (newValue < MIN_SETTLEMENT_LENGTH || newValue > MAX_SETTLEMENT_LENGTH) {
            revert WrongParams();
        }
        maxSettlementInterval = newValue;
        emit MaxSettlementIntervalUpdated(newValue);
    }

    function updateWithdrawSettlementDelay(uint32 newValue) external onlyGov {
        if (newValue > MAX_WITHDRAW_SETTLEMENT_DELAY) revert WrongParams();
        withdrawSettlementDelay = newValue;
        emit WithdrawSettlementDelayUpdated(newValue);
    }

    function updateSupplyCap(uint256 newValue) external onlyGov {
        supplyCap = newValue;
        emit SupplyCapUpdated(newValue);
    }

    function maxAccPnlPerToken() public view returns (uint256) {
        return accRewardsPerToken + PRECISION_18;
    }

    function collateralizationP() public view returns (uint256) {
        uint256 _maxAccPnlPerToken = maxAccPnlPerToken();
        return (
            accPnlPerTokenUsed > 0
                ? (_maxAccPnlPerToken - uint256(accPnlPerTokenUsed))
                : (_maxAccPnlPerToken + uint256(accPnlPerTokenUsed * (-1)))
        ) * 100 * PRECISION_2 / _maxAccPnlPerToken;
    }

    function tryUpdateCurrentMaxSupply() public {
        if (block.timestamp >= lastMaxSupplyUpdateTs + 24 hours) {
            currentMaxSupply =
                totalSupply() * (uint16(100) * PRECISION_2 + maxSupplyIncreaseDailyP) / (PRECISION_2 * uint16(100));
            lastMaxSupplyUpdateTs = uint32(block.timestamp);

            emit CurrentMaxSupplyUpdated(currentMaxSupply);
        }
    }

    function tryResetDailyAccPnlDelta() public {
        if (block.timestamp >= lastDailyAccPnlDeltaResetTs + 24 hours) {
            dailyAccPnlDeltaPerToken = 0;
            lastDailyAccPnlDeltaResetTs = uint32(block.timestamp);

            emit DailyAccPnlDeltaReset();
        }
    }

    /// @notice Fallback settlement - triggers if maxSettlementInterval has passed
    function tryNewSettlement() public {
        if (block.timestamp >= lastSettlementTs + maxSettlementInterval) {
            _settlement();
        }
    }

    /// @notice Internal settlement function that handles accounting and user deposits/withdrawals
    function _settlement() internal {
        // OpenPnL refresh + accPnlPerToken update (increments lastSettlementId internally)
        _updateAccPnlPerTokenUsed();

        // Execute user deposits/withdrawals
        _executeAsyncDepositWithdraw(lastSettlementId);

        emit SettlementExecuted(
            lastSettlementId, // uint32 settlementId
            lastSettlementTs, // uint32 settlementTs
            lastSettlementOpenPnl, // int256 settlementOpenPnl
            accPnlPerTokenUsed, // int256 accPnlPerTokenUsed
            accRewardsPerToken, // uint256 accRewardsPerToken
            shareToAssetsPrice, // uint256 shareToAssetsPrice
            totalClosedPnl, // int256 totalClosedPnl - relevant on a per settlement basis
            totalSupply(), // uint256 totalSupply — amount of outstanding OLP after settlement
            totalAssets(), // uint256 totalAssets - amount of USDC in vault after settlement
            0 // int256 bufferAssetsDelta — if buffer increases -> positive number; if buffer decreases -> negative number;
        );
    }

    /// @notice Force a settlement (governance only)
    function forceSettlement() external onlyGov {
        _settlement();
    }

    /// @notice Force reset of daily accumulated PnL delta (governance only)
    /// @dev Bypasses the 24-hour time check in tryResetDailyAccPnlDelta
    function forceResetDailyAccPnlDelta() external onlyGov {
        dailyAccPnlDeltaPerToken = 0;
        lastDailyAccPnlDeltaResetTs = uint32(block.timestamp);

        emit DailyAccPnlDeltaReset();
    }

    function updateShareToAssetsPrice() private {
        shareToAssetsPrice = maxAccPnlPerToken() - (accPnlPerTokenUsed > 0 ? uint256(accPnlPerTokenUsed) : uint256(0));

        emit ShareToAssetsPriceUpdated(shareToAssetsPrice);
    }

    function _assetIERC20() private view returns (IERC20) {
        return IERC20(asset());
    }

    function decimals() public pure override(ERC4626Upgradeable) returns (uint8) {
        return 6;
    }

    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view override returns (uint256 shares) {
        return assets.mulDiv(PRECISION_18, shareToAssetsPrice, rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view override returns (uint256 assets) {
        if (shares == type(uint256).max && shareToAssetsPrice >= PRECISION_18) {
            return shares;
        }
        return shares.mulDiv(shareToAssetsPrice, PRECISION_18, rounding);
    }

    // Limits
    function maxDeposit(address owner) public view override returns (uint256) {
        return _convertToAssets(maxMint(owner), Math.Rounding.Floor);
    }

    function maxMint(address) public view override returns (uint256) {
        return _maxMint(totalSupply());
    }

    /**
     * @dev Calculate max mintable shares for a given supply value
     * @param supply The supply value to use in the calculation
     * @return Maximum shares that can be minted
     */
    function _maxMint(uint256 supply) private view returns (uint256) {
        if (accPnlPerTokenUsed > 0) {
            // Undercollateralized: use currentMaxSupply
            return currentMaxSupply - Math.min(currentMaxSupply, supply);
        }
        // Overcollateralized: use governance-set supplyCap if set
        if (supplyCap > 0) {
            return supplyCap - Math.min(supplyCap, supply);
        }
        return type(uint256).max;
    }

    function maxWithdraw(address owner) public view override returns (uint256) {
        return _convertToAssets(maxRedeem(owner), Math.Rounding.Floor);
    }

    function maxRedeem(address owner) public view override returns (uint256) {
        return totalSupply() == 0 ? 0 : totalSupply() - 1;
    }

    // Action Functions - State Changing
    // Override ERC-4626: Disable direct deposit & withdraw flow
    /**
     * @notice Deposit function is disabled in favor of async system.
     * @dev This vault uses a request/claim pattern for depoists. Use `requestDeposit` instead
     */
    function deposit(uint256 assets, address receiver) public override returns (uint256) {
        revert FunctionDisabled();
    }

    /**
     * @notice Mint function is disabled in favor of async system.
     * @dev This vault uses a request/claim pattern for depoists. Use `requestDeposit` instead
     */
    function mint(uint256 shares, address receiver) public override returns (uint256) {
        revert FunctionDisabled();
    }

    /**
     * @notice Withdraw function is disabled in favor of async system.
     * @dev This vault uses a request/claim pattern for depoists. Use `requestWithdraw` instead.
     */
    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256) {
        revert FunctionDisabled();
    }

    /**
     * @notice Redeem function is disabled in favor of async system.
     * @dev This vault uses a request/claim pattern for depoists. Use `requestWithdraw` instead.
     */
    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256) {
        revert FunctionDisabled();
    }

    // Async Deposit & Withdraw Flow
    function requestDeposit(uint256 assets) external checks(assets) {
        uint32 settlementId = targetSettlementId(true);

        totalAssetsToDeposit[settlementId] += assets;
        pendingDepositRequest[msg.sender][settlementId] += assets;

        SafeERC20.safeTransferFrom(_assetIERC20(), msg.sender, address(this), assets);

        emit DepositRequestedV2(msg.sender, settlementId, assets);
    }

    function requestWithdraw(uint256 shares) external checks(shares) {
        uint32 settlementId = targetSettlementId(false);

        totalSharesToWithdraw[settlementId] += shares;
        pendingWithdrawRequest[msg.sender][settlementId] += shares;

        _transfer(msg.sender, address(this), shares);

        emit WithdrawRequestedV2(msg.sender, settlementId, shares);
    }

    function cancelRequestDeposit(uint32 settlementId, uint256 assets) external checks(assets) {
        require(getDepositStatus(msg.sender, settlementId) == RequestStatus.PENDING);
        require(pendingDepositRequest[msg.sender][settlementId] >= assets);

        totalAssetsToDeposit[settlementId] -= assets;
        pendingDepositRequest[msg.sender][settlementId] -= assets;
        SafeERC20.safeTransfer(_assetIERC20(), msg.sender, assets);

        emit RequestDepositCanceledV2(msg.sender, settlementId, assets);
    }

    function cancelRequestWithdraw(uint32 settlementId, uint256 shares) external checks(shares) {
        require(getWithdrawStatus(msg.sender, settlementId) == RequestStatus.PENDING);
        require(pendingWithdrawRequest[msg.sender][settlementId] >= shares);

        totalSharesToWithdraw[settlementId] -= shares;
        pendingWithdrawRequest[msg.sender][settlementId] -= shares;
        _transfer(address(this), msg.sender, shares);

        emit RequestWithdrawCanceledV2(msg.sender, settlementId, shares);
    }

    function claimDeposit(uint32 settlementId) external {
        if (getDepositStatus(msg.sender, settlementId) != RequestStatus.CLAIMABLE) {
            revert DepositNotClaimable(msg.sender, settlementId);
        }

        uint256 requestedAssets = pendingDepositRequest[msg.sender][settlementId];
        uint256 scale = settlementAllocationScaleP[settlementId];

        // Calculate allocated portion based on pro-rata scale
        uint256 allocatedAssets = requestedAssets * scale / PRECISION_18;

        uint256 shares = convertToSharesWithPrice(allocatedAssets, settlementShareToAssetsPrice[settlementId]);

        // Clear pending (handles both full and partial allocation)
        pendingDepositRequest[msg.sender][settlementId] = 0;

        // Transfer shares for allocated portion
        _transfer(address(this), msg.sender, shares);

        // Refund unallocated portion (if any)
        uint256 unallocatedAssets = requestedAssets - allocatedAssets;
        if (unallocatedAssets > 0) {
            SafeERC20.safeTransfer(_assetIERC20(), msg.sender, unallocatedAssets);
            emit DepositPartiallyRefunded(msg.sender, settlementId, unallocatedAssets);
        }

        emit DepositClaimedV2(msg.sender, settlementId, shares);
    }

    function claimWithdraw(uint32 settlementId) external {
        if (getWithdrawStatus(msg.sender, settlementId) != RequestStatus.CLAIMABLE) {
            revert WithdrawNotClaimable(msg.sender, settlementId);
        }

        uint256 assets = convertToAssetsWithPrice(
            pendingWithdrawRequest[msg.sender][settlementId], settlementShareToAssetsPrice[settlementId]
        );

        pendingWithdrawRequest[msg.sender][settlementId] = 0;
        SafeERC20.safeTransfer(_assetIERC20(), msg.sender, assets);

        emit WithdrawClaimedV2(msg.sender, settlementId, assets);
    }

    function reclaimDeposit(uint32 settlementId) external {
        if (getDepositStatus(msg.sender, settlementId) != RequestStatus.RECLAIMABLE) {
            revert DepositNotReclaimable(msg.sender, settlementId);
        }

        uint256 assets = pendingDepositRequest[msg.sender][settlementId];
        pendingDepositRequest[msg.sender][settlementId] = 0;

        SafeERC20.safeTransfer(_assetIERC20(), msg.sender, assets);

        emit DepositReclaimedV2(msg.sender, settlementId, assets);
    }

    function reclaimWithdraw(uint32 settlementId) external {
        if (getWithdrawStatus(msg.sender, settlementId) != RequestStatus.RECLAIMABLE) {
            revert WithdrawNotReclaimable(msg.sender, settlementId);
        }

        uint256 shares = pendingWithdrawRequest[msg.sender][settlementId];
        pendingWithdrawRequest[msg.sender][settlementId] = 0;

        _transfer(address(this), msg.sender, shares);

        emit WithdrawReclaimedV2(msg.sender, settlementId, shares);
    }

    // Public view functions
    function targetSettlementId(bool isDeposit) public view returns (uint32) {
        return isDeposit ? lastSettlementId + 1 : lastSettlementId + 1 + withdrawSettlementDelay;
    }

    function getDepositStatus(address owner, uint32 settlementId) public view returns (RequestStatus requestStatus) {
        if (pendingDepositRequest[owner][settlementId] == 0) return RequestStatus.NONE;
        if (settlementId > lastSettlementId) return RequestStatus.PENDING;
        if (totalAssetsToDeposit[settlementId] == 0) {
            return RequestStatus.RECLAIMABLE;
        } else {
            return RequestStatus.CLAIMABLE;
        }
    }

    function getWithdrawStatus(address owner, uint32 settlementId) public view returns (RequestStatus requestStatus) {
        if (pendingWithdrawRequest[owner][settlementId] == 0) return RequestStatus.NONE;
        if (settlementId > lastSettlementId) return RequestStatus.PENDING;
        if (totalSharesToWithdraw[settlementId] == 0) {
            return RequestStatus.RECLAIMABLE;
        } else {
            return RequestStatus.CLAIMABLE;
        }
    }

    function convertToSharesWithPrice(uint256 assets, uint256 _shareToAssetsPrice) public pure returns (uint256) {
        return assets.mulDiv(PRECISION_18, _shareToAssetsPrice, Math.Rounding.Floor);
    }

    function convertToAssetsWithPrice(uint256 shares, uint256 _shareToAssetsPrice) public pure returns (uint256) {
        if (shares == type(uint256).max && _shareToAssetsPrice >= PRECISION_18) {
            return shares;
        }
        return shares.mulDiv(_shareToAssetsPrice, PRECISION_18, Math.Rounding.Floor);
    }

    function _executeAsyncDepositWithdraw(uint32 settlementId) private {
        uint256 maxRedeemAmount = maxRedeem(address(0));

        // Process withdrawals first
        uint256 sharesToWithdraw = totalSharesToWithdraw[settlementId];
        if (sharesToWithdraw > maxRedeemAmount) {
            emit TotalSharesToWithdrawAboveMax(settlementId, sharesToWithdraw, maxRedeemAmount);
            totalSharesToWithdraw[settlementId] = 0;
            sharesToWithdraw = 0;
        }


        uint256 requestedDeposits = totalAssetsToDeposit[settlementId];
        if (requestedDeposits > 0) {
            // Withdrawals free up capacity, so we adjust the effective supply
            uint256 effectiveSupply = totalSupply() - sharesToWithdraw;
            uint256 maxDepositAmount = _convertToAssets(_maxMint(effectiveSupply), Math.Rounding.Floor);

            if (maxDepositAmount == 0) {
                // Vault cannot accept any deposits - all reclaimable
                emit TotalAssetsToDepositAboveMax(settlementId, requestedDeposits, maxDepositAmount);
                totalAssetsToDeposit[settlementId] = 0;
            } else if (requestedDeposits > maxDepositAmount) {
                // Pro-rata: cap at max, track allocation ratio
                settlementAllocationScaleP[settlementId] = maxDepositAmount * PRECISION_18 / requestedDeposits;
                totalAssetsToDeposit[settlementId] = maxDepositAmount;
                emit TotalAssetsToDepositCapped(settlementId, requestedDeposits, maxDepositAmount);
            } else {
                // Full allocation
                settlementAllocationScaleP[settlementId] = PRECISION_18;
            }
        }

        // Mint or burn the net Deposit & Withdraw shares
        int256 deltaShares =
            int256(convertToShares(totalAssetsToDeposit[settlementId])) - int256(totalSharesToWithdraw[settlementId]);
        if (deltaShares > 0) {
            scaleVariables(uint256(deltaShares), true);
            _mint(address(this), uint256(deltaShares));
        } else if (deltaShares < 0) {
            scaleVariables(uint256(-deltaShares), false);
            _burn(address(this), uint256(-deltaShares));
        }

        // Update conversion price for the settlement
        settlementShareToAssetsPrice[settlementId] = shareToAssetsPrice;

        emit AsyncDepositWithdrawExecuted(
            settlementId,
            deltaShares,
            totalAssetsToDeposit[settlementId],
            totalSharesToWithdraw[settlementId],
            shareToAssetsPrice
        );
    }

    function unlockDeposit(uint256 depositId, address receiver) external {
        IOstiumLockedDepositNft lockedDepositNft =
            IOstiumLockedDepositNft(registry.getContractAddress('lockedDepositNft'));
        LockedDeposit storage d = lockedDeposits[depositId];

        address sender = _msgSender();
        address owner = lockedDepositNft.ownerOf(depositId);

        if (
            owner != sender && lockedDepositNft.getApproved(depositId) != sender
                && !lockedDepositNft.isApprovedForAll(owner, sender)
        ) revert NotAllowed(sender);

        if (block.timestamp < d.atTimestamp + d.lockDuration) {
            revert DepositNotUnlocked(depositId);
        }

        int256 accPnlDelta = d.assetsDiscount.mulDiv(PRECISION_18, totalSupply(), Math.Rounding.Ceil).toInt256();

        accPnlPerToken += accPnlDelta;
        if (accPnlPerToken > maxAccPnlPerToken().toInt256()) {
            revert NotEnoughAssets();
        }

        lockedDepositNft.burn(depositId);

        accPnlPerTokenUsed += accPnlDelta;
        updateShareToAssetsPrice();

        totalLockedDiscounts -= d.assetsDiscount;

        _transfer(address(this), receiver, d.shares);

        emit DepositUnlocked(sender, receiver, owner, depositId, d);
    }

    // Change accPnlPerToken and accRewardsPerToken state
    function scaleVariables(uint256 shares, bool isDeposit) private {
        if (accPnlPerToken < 0) {
            uint256 supply = totalSupply();
            accPnlPerToken = accPnlPerToken * supply.toInt256()
                / (isDeposit ? (supply + shares).toInt256() : (supply - shares).toInt256());
            accPnlPerTokenUsed = accPnlPerToken;
        }
    }

    function distributeReward(uint256 assets) external {
        address sender = _msgSender();
        SafeERC20.safeTransferFrom(_assetIERC20(), sender, address(this), assets);

        accRewardsPerToken += assets * PRECISION_18 / totalSupply();
        updateShareToAssetsPrice();

        emit RewardDistributed(sender, assets, accRewardsPerToken);
    }

    function sendAssets(uint256 assets, address receiver) external onlyCallbacks {
        address sender = _msgSender();

        int256 accPnlDelta = assets.mulDiv(PRECISION_18, totalSupply(), Math.Rounding.Ceil).toInt256();

        accPnlPerToken += accPnlDelta;
        if (accPnlPerToken > maxAccPnlPerToken().toInt256()) {
            revert NotEnoughAssets();
        }

        tryResetDailyAccPnlDelta();
        dailyAccPnlDeltaPerToken += accPnlDelta;

        if (dailyAccPnlDeltaPerToken > maxDailyAccPnlDeltaPerToken.toInt256()) {
            revert MaxDailyPnlReached();
        }

        totalClosedPnl += assets.toInt256();

        tryNewSettlement();
        tryUpdateCurrentMaxSupply();

        SafeERC20.safeTransfer(_assetIERC20(), receiver, assets);

        emit AssetsSent(sender, receiver, assets);
    }

    function receiveAssets(uint256 assets, address user) external {
        address sender = _msgSender();
        SafeERC20.safeTransferFrom(_assetIERC20(), sender, address(this), assets);

        int256 accPnlDelta = (assets * PRECISION_18 / totalSupply()).toInt256();
        accPnlPerToken -= accPnlDelta;

        tryResetDailyAccPnlDelta();
        dailyAccPnlDeltaPerToken -= accPnlDelta;

        totalClosedPnl -= assets.toInt256();

        tryNewSettlement();
        tryUpdateCurrentMaxSupply();

        emit AssetsReceived(sender, user, assets);
    }

    function _updateAccPnlPerTokenUsed() internal {
        uint256 supply = totalSupply();

        int256 prevOpenPnl = lastSettlementOpenPnl;
        int256 newOpenPnl = IOstiumOpenPnl(registry.getContractAddress('openPnl')).getOpenPnlWithRollover();

        int256 deltaOpenPnl = _getOpenPnlDelta(prevOpenPnl, newOpenPnl, supply); // It VERY important that we recieve an event if max is used;

        // Only update accPnlPerToken if supply > 0 to avoid division by zero
        if (supply > 0) {
            accPnlPerToken += deltaOpenPnl * int32(PRECISION_6) / supply.toInt256();
        }

        accPnlPerTokenUsed = accPnlPerToken;
        updateShareToAssetsPrice();
        tryUpdateCurrentMaxSupply();

        ++lastSettlementId;
        lastSettlementTs = block.timestamp.toUint32();
        lastSettlementOpenPnl = prevOpenPnl + deltaOpenPnl;

        emit AccPnlPerTokenUsedUpdatedV2(
            lastSettlementId, prevOpenPnl, newOpenPnl, lastSettlementOpenPnl, accPnlPerTokenUsed
        );
    }

    function _getOpenPnlDelta(int256 prevOpenPnl, int256 newOpenPnl, uint256 supply) internal returns (int256) {
        uint256 vaultValue = uint256(maxAccPnlPerToken().toInt256() - accPnlPerToken) * supply / PRECISION_6;
        uint256 maxOpenPnlDeltaSupply = maxAccOpenPnlDeltaPerToken * supply / PRECISION_6;
        int256 maxDelta = (Math.min(vaultValue, maxOpenPnlDeltaSupply)).toInt256();

        int256 deltaOpenPnl = newOpenPnl - prevOpenPnl;

        if (deltaOpenPnl > maxDelta) {
            if (maxDelta == int256(vaultValue)) emit MaxOpenPnlDeltaUsed(0, deltaOpenPnl, maxDelta); // 0 -> vaultValue
            if (maxDelta == int256(maxOpenPnlDeltaSupply)) emit MaxOpenPnlDeltaUsed(1, deltaOpenPnl, maxDelta); // 1 -> maxOpenPnlDeltaSupply
            return maxDelta;
        }
        return deltaOpenPnl;
    }

    function getLockedDeposit(uint256 depositId) external view returns (LockedDeposit memory) {
        return lockedDeposits[depositId];
    }

    function tvl() external view returns (uint256) {
        return maxAccPnlPerToken() * totalSupply() / PRECISION_18;
    }

    function availableAssets() public view returns (uint256) {
        return uint256(int256(maxAccPnlPerToken()) - accPnlPerTokenUsed) * totalSupply() / PRECISION_18;
    }

    function currentBalance() external view returns (uint256) {
        return availableAssets();
    }

    function marketCap() external view returns (uint256) {
        return (totalSupply() * shareToAssetsPrice) / PRECISION_18;
    }
}
