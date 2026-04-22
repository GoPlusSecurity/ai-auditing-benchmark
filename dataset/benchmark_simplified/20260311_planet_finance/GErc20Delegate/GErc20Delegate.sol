//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

// ---------------------------------------------------------------------------
// External interfaces
// ---------------------------------------------------------------------------

interface PriceOracleInterface {
    function validate(address gToken) external returns (uint, bool);
}

interface PlanetDiscount {
    function changeUserBorrowDiscount(address borrower) external returns (uint, uint, uint, uint);

    function changeLastBorrowAmountDiscountGiven(address borrower, uint borrowAmount) external;
}

/**
 * @title ERC 20 Token Standard Interface
 * https://eips.ethereum.org/EIPS/eip-20
 */
interface EIP20Interface {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256 balance);
    function transfer(address dst, uint256 amount) external returns (bool success);
    function transferFrom(address src, address dst, uint256 amount) external returns (bool success);
    function approve(address spender, uint256 amount) external returns (bool success);
    function allowance(address owner, address spender) external view returns (uint256 remaining);

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
}

/**
 * @title Interest rate model (interface)
 */
abstract contract InterestRateModel {
    bool public constant isInterestRateModel = true;

    function getBorrowRate(uint cash, uint borrows, uint reserves) external view virtual returns (uint);

    function getSupplyRate(uint cash, uint borrows, uint reserves, uint reserveFactorMantissa) external view virtual returns (uint);
}

/**
 * @notice Minimal Gammatroller surface for interest accrual.
 */
abstract contract GammatrollerInterface {
    bool public constant isGammatroller = true;

    function getOracle() external view virtual returns (PriceOracleInterface);
}

/**
 * @title Token ErrorReporter (subset used by GToken)
 */
contract TokenErrorReporter {
    uint public constant NO_ERROR = 0;

    error TransferGammatrollerRejection(uint256 errorCode);
    error TransferNotAllowed();
    error TransferNotEnough();
    error TransferTooMuch();
    error MintGammatrollerRejection(uint256 errorCode);
    error MintFreshnessCheck();
    error RedeemGammatrollerRejection(uint256 errorCode);
    error RedeemFreshnessCheck();
    error RedeemTransferOutNotPossible();
    error BorrowGammatrollerRejection(uint256 errorCode);
    error BorrowFreshnessCheck();
    error BorrowCashNotAvailable();
    error RepayBorrowGammatrollerRejection(uint256 errorCode);
    error RepayBorrowFreshnessCheck();
    error LiquidateGammatrollerRejection(uint256 errorCode);
    error LiquidateFreshnessCheck();
    error LiquidateCollateralFreshnessCheck();
    error LiquidateAccrueBorrowInterestFailed(uint256 errorCode);
    error LiquidateAccrueCollateralInterestFailed(uint256 errorCode);
    error LiquidateLiquidatorIsBorrower();
    error LiquidateCloseAmountIsZero();
    error LiquidateCloseAmountIsUintMax();
    error LiquidateRepayBorrowFreshFailed(uint256 errorCode);
    error LiquidateSeizeGammatrollerRejection(uint256 errorCode);
    error LiquidateSeizeLiquidatorIsBorrower();
    error AcceptAdminPendingAdminCheck();
    error SetGammatrollerOwnerCheck();
    error SetPendingAdminOwnerCheck();
    error SetReserveFactorAdminCheck();
    error SetReserveFactorFreshCheck();
    error SetReserveFactorBoundsCheck();
    error AddReservesFactorFreshCheck(uint256 actualAddAmount);
    error ReduceReservesAdminCheck();
    error ReduceReservesFreshCheck();
    error ReduceReservesCashNotAvailable();
    error ReduceReservesCashValidation();
    error SetInterestRateModelOwnerCheck();
    error SetInterestRateModelFreshCheck();
    error SetDiscountLevelAdminCheck();
    error SetWithdrawFeeFactorFreshCheck();
    error SetWithdrawFeeFactorBoundsCheck();
}

/**
 * @title Exponential module for fixed-precision decimals
 */
contract ExponentialNoError {
    uint constant expScale = 1e18;
    uint constant doubleScale = 1e36;
    uint constant halfExpScale = expScale / 2;
    uint constant mantissaOne = expScale;

    struct Exp {
        uint mantissa;
    }

    struct Double {
        uint mantissa;
    }

    function truncate(Exp memory exp) internal pure returns (uint) {
        return exp.mantissa / expScale;
    }

    function mul_ScalarTruncate(Exp memory a, uint scalar) internal pure returns (uint) {
        Exp memory product = mul_(a, scalar);
        return truncate(product);
    }

    function mul_ScalarTruncateAddUInt(Exp memory a, uint scalar, uint addend) internal pure returns (uint) {
        Exp memory product = mul_(a, scalar);
        return add_(truncate(product), addend);
    }

    function lessThanExp(Exp memory left, Exp memory right) internal pure returns (bool) {
        return left.mantissa < right.mantissa;
    }

    function lessThanOrEqualExp(Exp memory left, Exp memory right) internal pure returns (bool) {
        return left.mantissa <= right.mantissa;
    }

    function greaterThanExp(Exp memory left, Exp memory right) internal pure returns (bool) {
        return left.mantissa > right.mantissa;
    }

    function isZeroExp(Exp memory value) internal pure returns (bool) {
        return value.mantissa == 0;
    }

    function safe224(uint n, string memory errorMessage) internal pure returns (uint224) {
        require(n < 2 ** 224, errorMessage);
        return uint224(n);
    }

    function safe32(uint n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2 ** 32, errorMessage);
        return uint32(n);
    }

    function add_(Exp memory a, Exp memory b) internal pure returns (Exp memory) {
        return Exp({mantissa: add_(a.mantissa, b.mantissa)});
    }

    function add_(Double memory a, Double memory b) internal pure returns (Double memory) {
        return Double({mantissa: add_(a.mantissa, b.mantissa)});
    }

    function add_(uint a, uint b) internal pure returns (uint) {
        return a + b;
    }

    function sub_(Exp memory a, Exp memory b) internal pure returns (Exp memory) {
        return Exp({mantissa: sub_(a.mantissa, b.mantissa)});
    }

    function sub_(Double memory a, Double memory b) internal pure returns (Double memory) {
        return Double({mantissa: sub_(a.mantissa, b.mantissa)});
    }

    function sub_(uint a, uint b) internal pure returns (uint) {
        return a - b;
    }

    function mul_(Exp memory a, Exp memory b) internal pure returns (Exp memory) {
        return Exp({mantissa: mul_(a.mantissa, b.mantissa) / expScale});
    }

    function mul_(Exp memory a, uint b) internal pure returns (Exp memory) {
        return Exp({mantissa: mul_(a.mantissa, b)});
    }

    function mul_(uint a, Exp memory b) internal pure returns (uint) {
        return mul_(a, b.mantissa) / expScale;
    }

    function mul_(Double memory a, Double memory b) internal pure returns (Double memory) {
        return Double({mantissa: mul_(a.mantissa, b.mantissa) / doubleScale});
    }

    function mul_(Double memory a, uint b) internal pure returns (Double memory) {
        return Double({mantissa: mul_(a.mantissa, b)});
    }

    function mul_(uint a, Double memory b) internal pure returns (uint) {
        return mul_(a, b.mantissa) / doubleScale;
    }

    function mul_(uint a, uint b) internal pure returns (uint) {
        return a * b;
    }

    function div_(Exp memory a, Exp memory b) internal pure returns (Exp memory) {
        return Exp({mantissa: div_(mul_(a.mantissa, expScale), b.mantissa)});
    }

    function div_(Exp memory a, uint b) internal pure returns (Exp memory) {
        return Exp({mantissa: div_(a.mantissa, b)});
    }

    function div_(uint a, Exp memory b) internal pure returns (uint) {
        return div_(mul_(a, expScale), b.mantissa);
    }

    function div_(Double memory a, Double memory b) internal pure returns (Double memory) {
        return Double({mantissa: div_(mul_(a.mantissa, doubleScale), b.mantissa)});
    }

    function div_(Double memory a, uint b) internal pure returns (Double memory) {
        return Double({mantissa: div_(a.mantissa, b)});
    }

    function div_(uint a, Double memory b) internal pure returns (uint) {
        return div_(mul_(a, doubleScale), b.mantissa);
    }

    function div_(uint a, uint b) internal pure returns (uint) {
        return a / b;
    }

    function fraction(uint a, uint b) internal pure returns (Double memory) {
        return Double({mantissa: div_(mul_(a, doubleScale), b)});
    }
}

// ---------------------------------------------------------------------------
// Storage & delegation types
// ---------------------------------------------------------------------------

contract GTokenStorage {
    bool internal _notEntered;
    bool public isBoostDeprecated;
    string public name;
    string public symbol;
    uint8 public decimals;
    uint internal constant borrowRateMaxMantissa = 0.0005e16;
    uint internal constant reserveFactorMaxMantissa = 1e18;
    address payable public admin;
    address payable public pendingAdmin;
    GammatrollerInterface public gammatroller;
    PlanetDiscount public discountLevel;
    InterestRateModel public interestRateModel;
    uint internal initialExchangeRateMantissa;
    uint public reserveFactorMantissa;
    uint public accrualBlockNumber;
    uint public borrowIndex;
    uint public totalBorrows;
    uint public totalReserves;
    uint public totalSupply;
    uint public totalFactor;
    address public iGamma;
    mapping(address => uint) internal accountTokens;
    mapping(address => uint) internal userFactors;
    mapping(address => mapping(address => uint)) internal transferAllowances;

    struct BorrowSnapshot {
        uint principal;
        uint interestIndex;
    }

    mapping(address => BorrowSnapshot) internal accountBorrows;
    uint public constant protocolSeizeShareMantissa = 2.8e16;
}

abstract contract GTokenInterface is GTokenStorage {
    bool public constant isGToken = true;
}

contract GErc20Storage {
    address public underlying;
}

abstract contract GErc20Interface is GErc20Storage {}

contract GDelegationStorage {
    address public implementation;
}

abstract contract GDelegatorInterface is GDelegationStorage {
    event NewImplementation(address oldImplementation, address newImplementation);

    function _setImplementation(address implementation_, bool allowResign, bytes memory becomeImplementationData) external virtual;
}

abstract contract GDelegateInterface is GDelegationStorage {
    function _becomeImplementation(bytes memory data) external virtual;

    function _resignImplementation() external virtual;
}

// ---------------------------------------------------------------------------
// GToken & GErc20
// ---------------------------------------------------------------------------

/**
 * @title Planet's GToken (simplified)
 * @notice Logic required by `updateUserDiscount` and its callees.
 */
abstract contract GToken is GTokenInterface, ExponentialNoError, TokenErrorReporter {
    event AccrueInterest(uint cashPrior, uint interestAccumulated, uint borrowIndex, uint totalBorrows);
    event NewGammatroller(GammatrollerInterface oldGammatroller, GammatrollerInterface newGammatroller);
    event NewMarketInterestRateModel(InterestRateModel oldInterestRateModel, InterestRateModel newInterestRateModel);

    modifier onlyAdminValidAddress(address _address) {
        require(msg.sender == admin && _address != address(0), "no admin priv or 0 address");
        _;
    }

    function initialize(
        address[] memory addresses,
        uint initialExchangeRateMantissa_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) public {
        require(msg.sender == admin, "only admin may initialize the market");
        require(accrualBlockNumber == 0 && borrowIndex == 0, "market may only be initialized once");

        initialExchangeRateMantissa = initialExchangeRateMantissa_;
        require(initialExchangeRateMantissa > 0, "initial exchange rate must be greater than zero.");

        GammatrollerInterface newGammatroller = GammatrollerInterface(addresses[0]);
        require(newGammatroller.isGammatroller(), "marker method returned false");
        emit NewGammatroller(gammatroller, newGammatroller);
        gammatroller = newGammatroller;

        accrualBlockNumber = block.number;
        borrowIndex = mantissaOne;

        InterestRateModel newInterestRateModel = InterestRateModel(addresses[1]);
        require(newInterestRateModel.isInterestRateModel(), "marker method returned false");
        emit NewMarketInterestRateModel(interestRateModel, newInterestRateModel);
        interestRateModel = newInterestRateModel;

        name = name_;
        symbol = symbol_;
        decimals = decimals_;
        discountLevel = PlanetDiscount(addresses[2]);
        iGamma = addresses[3];

        _notEntered = true;
    }

    function accrueInterest() public virtual returns (uint) {
        (uint error, bool valid) = gammatroller.getOracle().validate(address(this));
        require(error == NO_ERROR && valid, "validate failed");

        uint currentBlockNumber = block.number;
        uint accrualBlockNumberPrior = accrualBlockNumber;

        if (accrualBlockNumberPrior == currentBlockNumber) {
            return NO_ERROR;
        }

        uint cashPrior = getCashPrior();
        uint borrowsPrior = totalBorrows;
        uint reservesPrior = totalReserves;
        uint borrowIndexPrior = borrowIndex;

        uint borrowRateMantissa = interestRateModel.getBorrowRate(cashPrior, borrowsPrior, reservesPrior);
        require(borrowRateMantissa <= borrowRateMaxMantissa, "borrow rate is absurdly high");

        uint blockDelta = currentBlockNumber - accrualBlockNumberPrior;

        Exp memory simpleInterestFactor = mul_(Exp({mantissa: borrowRateMantissa}), blockDelta);
        uint interestAccumulated = mul_ScalarTruncate(simpleInterestFactor, borrowsPrior);
        uint totalBorrowsNew = interestAccumulated + borrowsPrior;
        uint totalReservesNew = mul_ScalarTruncateAddUInt(Exp({mantissa: reserveFactorMantissa}), interestAccumulated, reservesPrior);
        uint borrowIndexNew = mul_ScalarTruncateAddUInt(simpleInterestFactor, borrowIndexPrior, borrowIndexPrior);

        accrualBlockNumber = currentBlockNumber;
        borrowIndex = borrowIndexNew;
        totalBorrows = totalBorrowsNew;
        totalReserves = totalReservesNew;

        emit AccrueInterest(cashPrior, interestAccumulated, borrowIndexNew, totalBorrowsNew);

        return NO_ERROR;
    }

    function borrowBalanceStoredInternal(address account) internal view returns (uint) {
        BorrowSnapshot memory borrowSnapshot = accountBorrows[account];

        if (borrowSnapshot.principal == 0) {
            return 0;
        }

        uint principalTimesIndex = borrowSnapshot.principal * borrowIndex;
        return principalTimesIndex / borrowSnapshot.interestIndex;
    }

    function changeUserBorrowDiscountInternal(address borrower) internal {
        accrueInterest();
        (accountBorrows[borrower].principal, accountBorrows[borrower].interestIndex, totalBorrows, totalReserves) =
            PlanetDiscount(discountLevel).changeUserBorrowDiscount(borrower);
    }

    function changeLastBorrowBalanceAtBorrow(address borrower) internal {
        uint newBorrow = borrowBalanceStoredInternal(borrower);
        PlanetDiscount(discountLevel).changeLastBorrowAmountDiscountGiven(borrower, newBorrow);
    }

    function getCashPrior() internal view virtual returns (uint);
}

/**
 * @title Planet's GErc20 (simplified)
 */
contract GErc20 is GToken, GErc20Interface {
    function initialize(
        address underlying_,
        address[] memory addresses,
        uint initialExchangeRateMantissa_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) public {
        super.initialize(addresses, initialExchangeRateMantissa_, name_, symbol_, decimals_);

        underlying = underlying_;
        EIP20Interface(underlying).totalSupply();
    }

    function updateUserDiscount(address user) external {
        changeUserBorrowDiscountInternal(user);
        changeLastBorrowBalanceAtBorrow(user);
    }

    function getCashPrior() internal view override returns (uint) {
        return EIP20Interface(underlying).balanceOf(address(this));
    }
}

// ---------------------------------------------------------------------------
// Delegate implementation
// ---------------------------------------------------------------------------

/**
 * @title Planet's GErc20Delegate Contract
 * @notice GTokens which wrap an EIP-20 underlying and are delegated to this implementation.
 */
contract GErc20Delegate is GErc20, GDelegateInterface {
    constructor() {}

    function _becomeImplementation(bytes memory data) public virtual override {
        data;

        if (false) {
            implementation = address(0);
        }

        require(msg.sender == admin, "only the admin may call _becomeImplementation");
    }

    function _resignImplementation() public virtual override {
        if (false) {
            implementation = address(0);
        }

        require(msg.sender == admin, "only the admin may call _resignImplementation");
    }
}
