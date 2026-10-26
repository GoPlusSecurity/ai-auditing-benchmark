// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { ReentrancyGuardTransient } from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import { RegistrarClientInitializable } from "../RegistrarClient.sol";
import { ValinityCapOfficer } from "../officer/ValinityCapOfficer.sol";
import { IWETH } from "../token/IWETH.sol";
import { ValinityToken } from "../token/ValinityToken.sol";
import { ValinityReserveTreasury } from "../treasury/ValinityReserveTreasury.sol";
import { ValinityAssetRegistry } from "../ValinityAssetRegistry.sol";

contract ValinityLoanOfficer is UUPSUpgradeable, AccessControl, ReentrancyGuardTransient, RegistrarClientInitializable {
    using SafeERC20 for IERC20;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Minimum VY that borrower must keep in their wallet (0.0000001)
    uint256 public constant VY_DUST = 100_000_000_000;

    uint8 internal constant DEFAULT_DECIMALS = 18;
    uint16 internal constant BPS_MULTIPLIER = 10_000; // for BPS
    uint256 internal constant WAD = 1e18;

    bytes32 internal constant VAR = keccak256("ValinityAssetRegistry");
    bytes32 internal constant VCO = keccak256("ValinityCapOfficer");
    bytes32 internal constant VRT = keccak256("ValinityReserveTreasury");
    bytes32 internal constant VAT = keccak256("ValinityAcquisitionTreasury");
    bytes32 internal constant VY = keccak256("ValinityToken");

    struct Loan {
        uint256 collateral; // VY deposited by borrower
        uint256 principal; // Asset loaned to borrower
        uint64 openedAt; // Timestamp when loan was opened
        uint64 interestAppliedAt; // Timestamp of the last time interest was applied/deducted
    }

    struct AssetView {
        uint256 ltv; // The asset’s current LTV (getLTV(asset))
        uint256 reserveBalance; // The VRT’s token balance
        uint256 totalLoaned; // Total amount loaned
    }

    struct LoanView {
        uint256 collateral;
        uint256 principal;
        uint64 openedAt;
        uint64 interestAppliedAt;
        uint256 ltv; // LTV based on principal/collateral
        uint256 accruedInterest; // Current accrued interest in VY
        uint256 netCollateral; // collateral - accruedInterest
    }

    // Used for input validation on loan forms
    struct LoanConstraintsView {
        uint256 maxCollateral;
        uint256 maxPrincipal;
    }

    // Used to display the result of opening/increasing/refinancing a loan
    struct NewLoanView {
        uint256 principal;
        uint256 ltv;
        uint256 fee;
        uint256 netAmount;
    }

    // Used to display the result of repaying a loan
    struct RepayView {
        uint256 collateralRatio;
        uint256 collateralReturned;
        uint256 principal;
    }

    struct MigrateLoanVars {
        address borrower;
        address asset;
        uint256 collateral;
        uint256 principal;
    }

    enum LoanEventType {
        Opened,
        Increased,
        Repaid,
        Migrated
    }

    uint256 public interestRatePerSecond;
    uint16 public processingFeePercentage; // basis points
    address public processingFeeRecipient;

    IWETH internal _weth;
    mapping(address => mapping(address => Loan)) internal _loans;
    mapping(address => uint256) internal _totalLoanedPerAsset;

    error ActiveLoanExists();
    error CollateralTooLow();
    error ETHNotAccepted();
    error InsufficientCollateralBalance();
    error InvalidAddress();
    error InvalidValue();
    error LoanNotFound();
    error MismatchedETHValue();
    error PaymentTooHigh();
    error PaymentTooLow();
    error PrincipalTooLow();
    error UnsupportedAsset();

    event InterestRatePerSecondUpdated(uint256 value);
    event MinimumPrincipalUpdated(uint256 value);
    event ProcessingFeePercentageUpdated(uint16 value);
    event ProcessingFeeRecipientUpdated(address recipient);

    event LoanEvent(
        LoanEventType indexed eventType,
        address indexed borrower,
        address indexed asset,
        int256 deltaCollateral,
        int256 deltaPrincipal,
        uint256 processingFeeAmount,
        uint256 interestFeeAmount,
        uint256 totalCollateral,
        uint256 totalPrincipal
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address registrarAddress, address adminAddress, address wethAddress) public initializer {
        __RegistrarClient_init(registrarAddress);

        if (adminAddress == address(0)) revert InvalidAddress();
        if (wethAddress == address(0)) revert InvalidAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, adminAddress);
        _grantRole(ADMIN_ROLE, adminAddress);

        _weth = IWETH(wethAddress);

        interestRatePerSecond = 2_219_685_438; // ~7% APR
        processingFeePercentage = 100; // 1% in basis points
    }

    modifier onlyActiveLoan(address borrower, address asset) {
        _checkActiveLoan(borrower, asset);
        _;
    }

    modifier onlySupportedAsset(address asset) {
        if (!ValinityAssetRegistry(_registrar.getContract(VAR)).isSupported(asset)) {
            revert UnsupportedAsset();
        }
        _;
    }

    receive() external payable {
        // Only allow ETH sent by the WETH contract
        if (_msgSender() != address(_weth)) {
            revert ETHNotAccepted();
        }
    }

    function isActive(address borrower, address asset) public view returns (bool) {
        return _loanExists(borrower, asset);
    }

    function getLoan(address borrower, address asset) external view returns (Loan memory) {
        return _loans[borrower][asset];
    }

    function getTotalLoaned(address asset) public view returns (uint256) {
        return _totalLoanedPerAsset[asset];
    }

    function getLTV(address asset) public view onlySupportedAsset(asset) returns (uint256) {
        uint8 assetDecimals = _getAssetDecimals(asset);
        return _getLTV(asset, assetDecimals);
    }

    function getBorrowQuote(address asset, uint256 collateral) public view onlySupportedAsset(asset) returns (uint256) {
        uint8 assetDecimals = _getAssetDecimals(asset);
        uint256 ltv = _getLTV(asset, assetDecimals);
        return _toPrincipal(assetDecimals, ltv, collateral);
    }

    function getAccruedInterest(address borrower, address asset) public view returns (uint256) {
        Loan storage loan = _loans[borrower][asset];
        uint256 elapsed = block.timestamp - loan.interestAppliedAt;
        return (loan.collateral * interestRatePerSecond * elapsed) / WAD;
    }

    function getAssetView(address asset) external view returns (AssetView memory) {
        return AssetView({ ltv: getLTV(asset), reserveBalance: IERC20(asset).balanceOf(_registrar.getContract(VRT)), totalLoaned: getTotalLoaned(asset) });
    }

    function getLoanView(address borrower, address asset) external view returns (LoanView memory) {
        // If loan does not exist, return empty struct
        if (!isActive(borrower, asset)) {
            return LoanView(0, 0, 0, 0, 0, 0, 0);
        }

        Loan storage loan = _loans[borrower][asset];
        uint256 scaledPrincipal = _scaleDecimals(loan.principal, _getAssetDecimals(asset), DEFAULT_DECIMALS);
        uint256 accruedInterest = getAccruedInterest(borrower, asset);
        uint256 netCollateral = loan.collateral - accruedInterest;
        uint256 ltv = (scaledPrincipal * WAD) / netCollateral;

        return
            LoanView({
                collateral: loan.collateral,
                principal: loan.principal,
                openedAt: loan.openedAt,
                interestAppliedAt: loan.interestAppliedAt,
                ltv: ltv,
                accruedInterest: accruedInterest,
                netCollateral: netCollateral
            });
    }

    function getLoanConstraints(address asset, uint256 collateralBalance) external view onlySupportedAsset(asset) returns (LoanConstraintsView memory) {
        ValinityCapOfficer vco = ValinityCapOfficer(_registrar.getContract(VCO));
        uint8 assetDecimals = _getAssetDecimals(asset);
        uint256 ltv = _getLTV(asset, assetDecimals);

        if (ltv == 0 || collateralBalance <= VY_DUST) {
            return LoanConstraintsView({ maxCollateral: 0, maxPrincipal: 0 });
        }

        uint256 maxCollateral = collateralBalance - VY_DUST;

        uint256 cap = vco.getAssetCap(asset);
        uint256 floor = vco.assetCapFloor();
        uint256 collateralLimit = cap > floor ? cap - floor : 0;

        if (maxCollateral > collateralLimit) {
            maxCollateral = collateralLimit;
        }

        uint256 maxPrincipal = _toPrincipal(assetDecimals, ltv, maxCollateral);

        uint256 reserveBalance = IERC20(asset).balanceOf(_registrar.getContract(VRT));
        if (maxPrincipal > reserveBalance) {
            maxPrincipal = reserveBalance;
            maxCollateral = _toCollateral(assetDecimals, ltv, maxPrincipal);
        }

        return LoanConstraintsView({ maxCollateral: maxCollateral, maxPrincipal: maxPrincipal });
    }

    function getNewLoanView(address asset, uint256 collateral) external view onlySupportedAsset(asset) returns (NewLoanView memory) {
        uint8 assetDecimals = _getAssetDecimals(asset);
        uint256 ltv = _getLTV(asset, assetDecimals);
        uint256 principal = _toPrincipal(assetDecimals, ltv, collateral);

        uint256 fee = _getProcessingFee(principal);
        uint256 netAmount = principal - fee;

        return NewLoanView({ principal: principal, ltv: ltv, fee: fee, netAmount: netAmount });
    }

    function getRepayView(address borrower, address asset, uint256 payment) external view onlyActiveLoan(borrower, asset) returns (RepayView memory) {
        Loan storage loan = _loans[borrower][asset];

        if (payment > loan.principal) revert PaymentTooHigh();

        uint256 accruedInterest = getAccruedInterest(borrower, asset);
        uint256 netCollateral = loan.collateral - accruedInterest;
        uint256 collateralReturned = _getRepayCollateralReturned(netCollateral, loan.principal, payment);
        return
            RepayView({
                collateralRatio: (collateralReturned * WAD) / netCollateral,
                collateralReturned: collateralReturned,
                principal: loan.principal - payment
            });
    }

    // ─────────────────────────────────────────────
    // Admin Functions
    // ─────────────────────────────────────────────

    function setInterestRatePerSecond(uint256 value) external onlyRole(ADMIN_ROLE) {
        if (value == interestRatePerSecond) return;
        interestRatePerSecond = value;
        emit InterestRatePerSecondUpdated(value);
    }

    function setProcessingFeePercentage(uint16 value) external onlyRole(ADMIN_ROLE) {
        if (value == processingFeePercentage) return;
        if (value >= BPS_MULTIPLIER) revert InvalidValue();
        processingFeePercentage = value;
        emit ProcessingFeePercentageUpdated(value);
    }

    function setProcessingFeeRecipient(address recipient) external onlyRole(ADMIN_ROLE) {
        if (recipient == processingFeeRecipient) return;
        if (recipient == address(0)) revert InvalidAddress();
        processingFeeRecipient = recipient;
        emit ProcessingFeeRecipientUpdated(recipient);
    }

    function migrateLoans(MigrateLoanVars[] calldata loanDataArray) external onlyRole(ADMIN_ROLE) {
        for (uint16 i = 0; i < loanDataArray.length; i++) {
            _migrateLoan(loanDataArray[i].borrower, loanDataArray[i].asset, loanDataArray[i].collateral, loanDataArray[i].principal);
        }
    }

    // ─────────────────────────────────────────────
    // Loan Operations
    // ─────────────────────────────────────────────

    function openLoan(address asset, uint256 collateral) external nonReentrant onlySupportedAsset(asset) {
        address borrower = _msgSender();
        if (isActive(borrower, asset)) revert ActiveLoanExists();

        (uint256 principal, uint256 fee) = _processLoanIncrease(borrower, asset, collateral);

        uint64 openedAt = uint64(block.timestamp);

        Loan storage loan = _loans[borrower][asset];
        loan.openedAt = openedAt;
        loan.interestAppliedAt = openedAt;

        _emitLoanEvent(LoanEventType.Opened, borrower, asset, int256(collateral), int256(principal), fee, 0);
    }

    function increaseLoan(address asset, uint256 additionalCollateral) external nonReentrant onlyActiveLoan(_msgSender(), asset) {
        address borrower = _msgSender();
        // Apply interest before increasing loan
        uint256 interest = _applyInterest(borrower, asset);

        (uint256 additionalPrincipal, uint256 fee) = _processLoanIncrease(borrower, asset, additionalCollateral);

        _emitLoanEvent(LoanEventType.Increased, borrower, asset, int256(additionalCollateral - interest), int256(additionalPrincipal), fee, interest);
    }

    function repayLoan(address asset, uint256 payment) external payable nonReentrant onlyActiveLoan(_msgSender(), asset) {
        address borrower = _msgSender();
        ValinityReserveTreasury vrt = ValinityReserveTreasury(_registrar.getContract(VRT));
        Loan storage loan = _loans[borrower][asset];

        if (payment == 0) revert PaymentTooLow();
        if (payment > loan.principal) revert PaymentTooHigh();

        // Apply interest before processing payment
        uint256 interest = _applyInterest(borrower, asset);

        // Transfer reserve asset from borrower to VRT
        if (asset == address(_weth)) {
            // If asset is WETH, wrap ETH and transfer WETH directly to VRT
            if (msg.value != payment) revert MismatchedETHValue();
            _weth.deposit{ value: payment }();
            IERC20(address(_weth)).safeTransfer(address(vrt), payment);
        } else {
            if (msg.value > 0) revert ETHNotAccepted();
            IERC20(asset).safeTransferFrom(borrower, address(vrt), payment);
        }

        // Return equivalent VY to borrower
        uint256 collateralReturned = _getRepayCollateralReturned(loan.collateral, loan.principal, payment);
        _withdrawCollateral(borrower, asset, collateralReturned);

        // Update state
        loan.principal -= payment;
        _totalLoanedPerAsset[asset] -= payment;

        if (loan.principal == 0) {
            // Delete loan if fully repaid
            delete _loans[borrower][asset];
        }

        _emitLoanEvent(LoanEventType.Repaid, borrower, asset, -int256(collateralReturned + interest), -int256(payment), 0, interest);
    }

    function _loanExists(address borrower, address asset) internal view returns (bool) {
        return _loans[borrower][asset].openedAt > 0;
    }

    function _checkActiveLoan(address borrower, address asset) internal view {
        if (!_loanExists(borrower, asset)) revert LoanNotFound();
    }

    function _getProcessingFee(uint256 assetAmount) internal view returns (uint256) {
        return (assetAmount * processingFeePercentage) / BPS_MULTIPLIER;
    }

    /**
     * LTV = Reserve Balance / VY Collateral Cap
     * Expressed in asset units per VY, using 1e18 fixed-point scaling.
     * This reflects how many units of the given asset currently back each VY
     * that has been collateralized for this asset.
     *
     * Examples:
     * - 1e18 → 1 unit of asset per VY (e.g. 1 ETH / VY)
     * - 0.5e18 → 0.5 units of asset per VY
     * - 2e18 → 2 units of asset per VY (over-collateralized from asset's POV)
     *
     * A higher value indicates that more of the asset is backing each unit of VY cap,
     * which may affect how much of the asset is borrowable for a given VY input.
     */
    function _getLTV(address asset, uint8 assetDecimals) internal view returns (uint256) {
        ValinityCapOfficer vco = ValinityCapOfficer(_registrar.getContract(VCO));

        uint256 reserve = IERC20(asset).balanceOf(_registrar.getContract(VRT));
        uint256 cap = vco.getAssetCap(asset);
        if (cap == 0) return 0;

        uint256 scaledReserve = _scaleDecimals(reserve, assetDecimals, DEFAULT_DECIMALS);
        return (scaledReserve * WAD) / cap;
    }

    function _getRepayCollateralReturned(uint256 netCollateral, uint256 principal, uint256 payment) internal pure returns (uint256) {
        if (payment == principal) {
            return netCollateral;
        } else {
            return (netCollateral * payment) / principal;
        }
    }

    function _depositCollateral(address borrower, address asset, uint256 vyAmount) internal {
        ValinityToken vyToken = ValinityToken(_registrar.getContract(VY));
        if (vyToken.balanceOf(borrower) < vyAmount + VY_DUST) revert InsufficientCollateralBalance();

        vyToken.transferFrom(borrower, _registrar.getContract(VRT), vyAmount);
        _increaseCollateralBalance(borrower, asset, vyAmount);

        ValinityCapOfficer vco = ValinityCapOfficer(_registrar.getContract(VCO));
        vco.decreaseAssetCap(asset, vyAmount);
    }

    function _withdrawCollateral(address borrower, address asset, uint256 vyAmount) internal {
        ValinityReserveTreasury vrt = ValinityReserveTreasury(_registrar.getContract(VRT));

        // Reduce internal balance before external transfer
        _decreaseCollateralBalance(borrower, asset, vyAmount);

        // Transfer VY from VRT → borrower
        vrt.transferToken(_registrar.getContract(VY), borrower, vyAmount);

        // Increase cap when borrower receives collateral back
        ValinityCapOfficer vco = ValinityCapOfficer(_registrar.getContract(VCO));
        vco.increaseAssetCap(asset, vyAmount);
    }

    function _liquidateCollateral(address borrower, address asset, uint256 amount) internal {
        ValinityReserveTreasury vrt = ValinityReserveTreasury(_registrar.getContract(VRT));

        // Reduce borrower's collateral balance
        _decreaseCollateralBalance(borrower, asset, amount);

        // Transfer VY from VRT to VAT
        vrt.transferToken(_registrar.getContract(VY), _registrar.getContract(VAT), amount);
    }

    function _increaseCollateralBalance(address borrower, address asset, uint256 vyAmount) internal {
        _loans[borrower][asset].collateral += vyAmount;
        ValinityReserveTreasury(_registrar.getContract(VRT)).increaseCollateralizedVY(asset, vyAmount);
    }

    function _decreaseCollateralBalance(address borrower, address asset, uint256 vyAmount) internal {
        _loans[borrower][asset].collateral -= vyAmount;
        ValinityReserveTreasury(_registrar.getContract(VRT)).decreaseCollateralizedVY(asset, vyAmount);
    }

    function _applyInterest(address borrower, address asset) internal returns (uint256 interest) {
        interest = getAccruedInterest(borrower, asset);
        if (interest == 0) return 0;

        // Liquidate interest (decrease collateral balance, transfer to VAT)
        _liquidateCollateral(borrower, asset, interest);

        // Record interest applied timestamp
        _loans[borrower][asset].interestAppliedAt = uint64(block.timestamp);
    }

    function _distributeLoan(address borrower, address asset, uint256 assetAmount) internal returns (uint256 fee) {
        ValinityReserveTreasury vrt = ValinityReserveTreasury(_registrar.getContract(VRT));

        fee = _getProcessingFee(assetAmount);
        uint256 netAmount = assetAmount - fee;

        // Transfer processing fee to processing fee recipient
        if (fee > 0) {
            vrt.transferToken(asset, processingFeeRecipient, fee);
        }

        // Transfer net amount to borrower
        if (asset == address(_weth)) {
            // Transfer WETH from VRT to this contract, and transfer to borrower as ETH
            vrt.transferToken(asset, address(this), netAmount);
            _weth.withdraw(netAmount);
            payable(borrower).transfer(netAmount);
        } else {
            // Transfer other assets directly to borrower from VRT
            vrt.transferToken(asset, borrower, netAmount);
        }
    }

    function _processLoanIncrease(address borrower, address asset, uint256 collateral) internal returns (uint256 principal, uint256 fee) {
        uint8 assetDecimals = _getAssetDecimals(asset);

        // Convert collateral to principal (e.g. WBTC)
        uint256 ltv = _getLTV(asset, assetDecimals);
        principal = _toPrincipal(assetDecimals, ltv, collateral);

        if (principal == 0) revert CollateralTooLow();

        // Deposit collateral (pull VY from borrower → VRT, update internal state, decrease cap)
        _depositCollateral(borrower, asset, collateral);

        // Distribute additional asset to borrower
        fee = _distributeLoan(borrower, asset, principal);

        // Update loan principal and total loaned
        _loans[borrower][asset].principal += principal;
        _totalLoanedPerAsset[asset] += principal;
    }

    function _migrateLoan(address borrower, address asset, uint256 collateral, uint256 principal) internal onlySupportedAsset(asset) {
        if (isActive(borrower, asset)) revert ActiveLoanExists();

        // Validate values
        if (collateral == 0) revert CollateralTooLow();
        if (principal == 0) revert PrincipalTooLow();

        // Increase collateralized VY
        _increaseCollateralBalance(borrower, asset, collateral);

        // Set loan properties
        uint64 openedAt = uint64(block.timestamp);

        Loan storage loan = _loans[borrower][asset];
        loan.principal = principal;
        loan.openedAt = openedAt;
        loan.interestAppliedAt = openedAt;

        // Update total loaned
        _totalLoanedPerAsset[asset] += principal;

        _emitLoanEvent(LoanEventType.Migrated, borrower, asset, int256(collateral), int256(principal), 0, 0);
    }

    function _toPrincipal(uint8 assetDecimals, uint256 ltv, uint256 collateral) internal pure returns (uint256) {
        uint256 raw = (collateral * ltv) / WAD;
        return _scaleDecimals(raw, DEFAULT_DECIMALS, assetDecimals);
    }

    function _toCollateral(uint8 assetDecimals, uint256 ltv, uint256 principal) internal pure returns (uint256) {
        if (ltv == 0) return 0;
        uint256 scaledPrincipal = _scaleDecimals(principal, assetDecimals, DEFAULT_DECIMALS);
        return (scaledPrincipal * WAD) / ltv;
    }

    function _getAssetDecimals(address asset) internal view returns (uint8) {
        try IERC20Metadata(asset).decimals() returns (uint8 dec) {
            return dec;
        } catch {
            return DEFAULT_DECIMALS;
        }
    }

    function _scaleDecimals(uint256 amount, uint8 fromDecimals, uint8 toDecimals) internal pure returns (uint256) {
        if (fromDecimals > toDecimals) {
            return amount / 10 ** (fromDecimals - toDecimals);
        } else if (fromDecimals < toDecimals) {
            return amount * 10 ** (toDecimals - fromDecimals);
        }
        return amount;
    }

    function _emitLoanEvent(
        LoanEventType eventType,
        address borrower,
        address asset,
        int256 deltaCollateral,
        int256 deltaPrincipal,
        uint256 processingFeeAmount,
        uint256 interestFeeAmount
    ) internal {
        Loan storage loan = _loans[borrower][asset];
        emit LoanEvent(eventType, borrower, asset, deltaCollateral, deltaPrincipal, processingFeeAmount, interestFeeAmount, loan.collateral, loan.principal);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(ADMIN_ROLE) {}
}
