// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.10;

contract PlanetStorage {
    address public gGammaAddress = 0xF701A48e5C751A213b7c540F84B64b5A6109962E;
    address public gammatroller = 0xF54f9e7070A1584532572A6F640F09c606bb9A83;
    address public oracle = 0xC23b8aF5D68222a2FB835CEB07B009b94e36eFF9;
    address public infinityVault;

    uint256 public level0Discount = 0;
    uint256 public level1Discount = 500;
    uint256 public level2Discount = 2000;
    uint256 public level3Discount = 5000;

    uint256 public level1Min = 100;
    uint256 public level2Min = 500;
    uint256 public level3Min = 1000;

    mapping(address => uint) public totalDiscountGiven;
    mapping(address => bool) public isMarketListed;
    mapping(address => mapping(address => BorrowDiscountSnapshot)) public borrowDiscountSnap;

    struct ReturnBorrowDiscountLocalVars {
        uint marketTokenSupplied;
    }

    mapping(address => address[]) public usersWhoHaveBorrow;

    struct BorrowDiscountSnapshot {
        bool exist;
        uint index;
        uint lastBorrowAmountDiscountGiven;
        uint accTotalDiscount;
        uint lastUpdated;
    }

    event BorrowDiscountAccrued(
        address market,
        address borrower,
        uint discountGiven,
        uint lastUpdated,
        uint accountBorrowsNew,
        uint marketTotalBorrows
    );
}

/// @dev Only the math helpers needed by `returnDiscountPercentage` / `returnBorrowerStakedAsset`.
contract ExponentialNoError {
    uint internal constant expScale = 1e18;

    struct Exp {
        uint mantissa;
    }

    function truncate(Exp memory exp) internal pure returns (uint) {
        return exp.mantissa / expScale;
    }

    function mul_ScalarTruncate(Exp memory a, uint scalar) internal pure returns (uint) {
        return truncate(mul_(a, scalar));
    }

    function mul_(Exp memory a, uint b) internal pure returns (Exp memory) {
        return Exp({mantissa: mul_(a.mantissa, b)});
    }

    function mul_(uint a, uint b) internal pure returns (uint) {
        if (a == 0 || b == 0) {
            return 0;
        }
        uint c = a * b;
        require(c / a == b, "multiplication overflow");
        return c;
    }

    function div_(uint a, uint b) internal pure returns (uint) {
        require(b > 0, "divide by zero");
        return a / b;
    }
}

interface PriceOracle {
    function getUnderlyingPrice(GToken gToken) external view returns (uint);
}

interface GammatrollerInterface {
    function getAllMarkets() external view returns (GToken[] memory);
}

interface GToken {
    function totalReserves() external view returns (uint256);
    function totalBorrows() external view returns (uint256);
    function borrowIndex() external view returns (uint256);
    function getAccountSnapshot(address account) external view returns (uint, uint, uint, uint);
    function borrowBalanceStored(address account) external view returns (uint);
    function reserveFactorMantissa() external view returns (uint);
}

interface InfinityVault {
    function getUserGtokenBal(address user) external view returns (uint);
}

contract PlanetDiscountDelegate is PlanetStorage, ExponentialNoError {
    struct BorrowLocalVars {
        uint accountBorrowsNew;
        uint interest;
        uint newDiscount;
    }

    function returnBorrowerStakedAsset(address borrower, address market) internal view returns (uint) {
        ReturnBorrowDiscountLocalVars memory vars;
        (, uint gTokenBalance,, uint exchangeRate) = GToken(market).getAccountSnapshot(borrower);

        if (gTokenBalance != 0) {
            uint price = PriceOracle(oracle).getUnderlyingPrice(GToken(market));
            vars.marketTokenSupplied = mul_ScalarTruncate(Exp({mantissa: gTokenBalance}), exchangeRate);
            uint256 marketTokenSuppliedInBnb = mul_ScalarTruncate(Exp({mantissa: vars.marketTokenSupplied}), price);
            return marketTokenSuppliedInBnb;
        }
        return 0;
    }

    function returnDiscountPercentage(address borrower) internal view returns (uint) {
        uint discount;
        GToken[] memory userInMarkets = GammatrollerInterface(gammatroller).getAllMarkets();

        (, uint gTokenBalance,, uint exchangeRate) = GToken(gGammaAddress).getAccountSnapshot(borrower);
        uint price = PriceOracle(oracle).getUnderlyingPrice(GToken(gGammaAddress));

        gTokenBalance = gTokenBalance + InfinityVault(infinityVault).getUserGtokenBal(borrower);

        uint256 gammaStaked = mul_ScalarTruncate(Exp({mantissa: gTokenBalance}), exchangeRate);
        gammaStaked = mul_ScalarTruncate(Exp({mantissa: gammaStaked}), price);

        uint256 otherStaked = 0;

        for (uint i = 0; i < userInMarkets.length; ++i) {
            GToken _market = userInMarkets[i];
            if (isMarketListed[address(_market)] && address(_market) != gGammaAddress) {
                otherStaked = otherStaked + returnBorrowerStakedAsset(borrower, address(_market));
            }
        }

        if (otherStaked == 0) {
            return level0Discount;
        }

        Exp memory _discount = Exp({mantissa: div_((gammaStaked * expScale), otherStaked)});
        _discount.mantissa = _discount.mantissa * 100;
        uint256 _scaledDiscount = _discount.mantissa / 1e16;
        discount = _scaledDiscount;

        if (level1Min <= discount && discount < level2Min) {
            discount = level1Discount;
        } else if (level2Min <= discount && discount < level3Min) {
            discount = level2Discount;
        } else if (discount >= level3Min) {
            discount = level3Discount;
        } else {
            discount = level0Discount;
        }
        return discount;
    }

    function changeUserBorrowDiscount(address borrower) external returns (uint, uint, uint, uint) {
        address _market = msg.sender;
        GToken market = GToken(_market);
        BorrowLocalVars memory vars;
        BorrowDiscountSnapshot storage _dis = borrowDiscountSnap[_market][borrower];

        uint discount = returnDiscountPercentage(borrower);

        uint currentBorrowBal = market.borrowBalanceStored(borrower);
        uint marketTotalBorrows = market.totalBorrows();

        if (!isMarketListed[address(market)]) {
            return (currentBorrowBal, market.borrowIndex(), market.totalBorrows(), market.totalReserves());
        }

        if (_dis.exist && discount > 0) {
            if (_dis.lastBorrowAmountDiscountGiven > currentBorrowBal) {
                _dis.lastBorrowAmountDiscountGiven = currentBorrowBal;
            }

            vars.interest = currentBorrowBal - _dis.lastBorrowAmountDiscountGiven;
            uint reserveFactor = GToken(address(market)).reserveFactorMantissa();
            uint valueOfGivenInterestGoToReserves =
                mul_ScalarTruncate(Exp({mantissa: vars.interest}), reserveFactor);

            vars.newDiscount = discount * valueOfGivenInterestGoToReserves;
            vars.newDiscount = vars.newDiscount / 10000;

            _dis.lastBorrowAmountDiscountGiven = currentBorrowBal;
            vars.accountBorrowsNew = currentBorrowBal - vars.newDiscount;

            totalDiscountGiven[_market] = totalDiscountGiven[_market] + vars.newDiscount;
            _dis.lastUpdated = block.number;

            emit BorrowDiscountAccrued(
                _market,
                borrower,
                vars.newDiscount,
                _dis.lastUpdated,
                vars.accountBorrowsNew,
                marketTotalBorrows
            );
            return (
                vars.accountBorrowsNew,
                market.borrowIndex(),
                marketTotalBorrows - vars.newDiscount,
                market.totalReserves() - vars.newDiscount
            );
        } else {
            if (_dis.exist) {
                _dis.lastBorrowAmountDiscountGiven = currentBorrowBal;
                _dis.lastUpdated = block.number;
            } else {
                usersWhoHaveBorrow[_market].push(borrower);
                _dis.exist = true;
                _dis.index = usersWhoHaveBorrow[_market].length - 1;
                _dis.lastBorrowAmountDiscountGiven = currentBorrowBal;
                _dis.lastUpdated = block.number;
            }
            return (currentBorrowBal, market.borrowIndex(), market.totalBorrows(), market.totalReserves());
        }
    }
}
