// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

// -------------------------------------------------------------------------
// Inlined dependencies (flattened into this file).
// Note: We intentionally keep deep external dependency chains (e.g. some OZ
// utility graphs) as imports inside their original sources when inlining them
// would balloon this file excessively.
// -------------------------------------------------------------------------

// Minimal interfaces (PurchaseBundler does not inherit them).
interface IERC20 {
    function balanceOf(address owner) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function setApprovalForAll(address operator, bool approved) external;
    function approve(address spender, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

interface IERC721TokenReceiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4);
}

// ===== Inlined from: lib/solmate/src/utils/FixedPointMathLib.sol =====
/// @notice Arithmetic library with operations for fixed-point numbers.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/FixedPointMathLib.sol)
/// @author Inspired by USM (https://github.com/usmfum/USM/blob/master/contracts/WadMath.sol)
library FixedPointMathLib {
    uint256 internal constant MAX_UINT256 = 2**256 - 1;
    uint256 internal constant WAD = 1e18;

    function mulWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, y, WAD);
    }

    function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, y, WAD);
    }

    function divWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, WAD, y);
    }

    function divWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, WAD, y);
    }

    function mulDivDown(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 z) {
        assembly {
            if iszero(mul(denominator, iszero(mul(y, gt(x, div(MAX_UINT256, y)))))) { revert(0, 0) }
            z := div(mul(x, y), denominator)
        }
    }

    function mulDivUp(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 z) {
        assembly {
            if iszero(mul(denominator, iszero(mul(y, gt(x, div(MAX_UINT256, y)))))) { revert(0, 0) }
            z := add(gt(mod(mul(x, y), denominator), 0), div(mul(x, y), denominator))
        }
    }

    function rpow(uint256 x, uint256 n, uint256 scalar) internal pure returns (uint256 z) {
        assembly {
            switch x
            case 0 {
                switch n
                case 0 { z := scalar }
                default { z := 0 }
            }
            default {
                switch mod(n, 2)
                case 0 { z := scalar }
                default { z := x }
                let half := shr(1, scalar)
                for { n := shr(1, n) } n { n := shr(1, n) } {
                    if shr(128, x) { revert(0, 0) }
                    let xx := mul(x, x)
                    let xxRound := add(xx, half)
                    if lt(xxRound, xx) { revert(0, 0) }
                    x := div(xxRound, scalar)
                    if mod(n, 2) {
                        let zx := mul(z, x)
                        if iszero(eq(div(zx, x), z)) { if iszero(iszero(x)) { revert(0, 0) } }
                        let zxRound := add(zx, half)
                        if lt(zxRound, zx) { revert(0, 0) }
                        z := div(zxRound, scalar)
                    }
                }
            }
        }
    }

    function sqrt(uint256 x) internal pure returns (uint256 z) {
        assembly {
            let y := x
            z := 181
            if iszero(lt(y, 0x10000000000000000000000000000000000)) { y := shr(128, y) z := shl(64, z) }
            if iszero(lt(y, 0x1000000000000000000)) { y := shr(64, y) z := shl(32, z) }
            if iszero(lt(y, 0x10000000000)) { y := shr(32, y) z := shl(16, z) }
            if iszero(lt(y, 0x1000000)) { y := shr(16, y) z := shl(8, z) }
            z := shr(18, mul(z, add(y, 65536)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := sub(z, lt(div(x, z), z))
        }
    }

    function unsafeMod(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            z := mod(x, y)
        }
    }

    function unsafeDiv(uint256 x, uint256 y) internal pure returns (uint256 r) {
        assembly {
            r := div(x, y)
        }
    }

    function unsafeDivUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            z := add(gt(mod(x, y), 0), div(x, y))
        }
    }
}

// ===== Inlined from: lib/solmate/src/utils/SafeTransferLib.sol =====
/// @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// @dev Use with caution! Some functions in this library knowingly create dirty bits at the destination of the free memory pointer.
/// @dev Note that none of the functions in this library check that a token has code at all! That responsibility is delegated to the caller.
library SafeTransferLib {
    function safeTransferETH(address to, uint256 amount) internal {
        bool success;
        assembly {
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }
        require(success, "ETH_TRANSFER_FAILED");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool success;
        assembly {
            let freeMemoryPointer := mload(0x40)
            mstore(freeMemoryPointer, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), and(from, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(freeMemoryPointer, 36), and(to, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(freeMemoryPointer, 68), amount)
            success := and(
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                call(gas(), token, 0, freeMemoryPointer, 100, 0, 32))
            )
        }
        require(success, "TRANSFER_FROM_FAILED");
    }

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success;
        assembly {
            let freeMemoryPointer := mload(0x40)
            mstore(freeMemoryPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(freeMemoryPointer, 36), amount)
            success := and(
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                call(gas(), token, 0, freeMemoryPointer, 68, 0, 32))
            )
        }
        require(success, "TRANSFER_FAILED");
    }

    function safeApprove(IERC20 token, address to, uint256 amount) internal {
        bool success;
        assembly {
            let freeMemoryPointer := mload(0x40)
            mstore(freeMemoryPointer, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(freeMemoryPointer, 36), amount)
            success := and(
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                call(gas(), token, 0, freeMemoryPointer, 68, 0, 32))
            )
        }
        require(success, "APPROVE_FAILED");
    }
}

// ===== Inlined from: lib/solmate/src/utils/ReentrancyGuard.sol =====
/// @notice Gas optimized reentrancy protection for smart contracts.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/ReentrancyGuard.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol)
abstract contract ReentrancyGuard {
    uint256 private locked = 1;

    modifier nonReentrant() virtual {
        require(locked == 1, "REENTRANCY");
        locked = 2;
        _;
        locked = 1;
    }
}

// ===== Inlined project interfaces/libs used by PurchaseBundler =====

// src/interfaces/external/ICryptoPunksMarket.sol
interface ICryptoPunksMarket {
    function transferPunk(address to, uint256 punkIndex) external;
    function punkIndexToAddress(uint256 punkIndex) external view returns (address);
}

// -------------------------------------------------------------------------
// Project libraries/contracts (fully inlined to remove remaining imports)
// -------------------------------------------------------------------------

// src/lib/InputChecker.sol
library InputChecker {
    error AddressZeroError();
    function checkNotZero(address _address) internal pure {
        if (_address == address(0)) revert AddressZeroError();
    }
}

// src/lib/AddressManager.sol
interface IAddressManager {
    function isWhitelisted(address _entry) external view returns (bool);
}

// src/interfaces/loans/IMultiSourceLoan.sol + IBaseLoan.sol are required for callback types.
// To keep this patch size manageable, we declare only the subset used by PurchaseBundler.
interface IMultiSourceLoan {
    struct Tranche {
        uint256 loanId;
        uint256 floor;
        uint256 principalAmount;
        address lender;
        uint256 accruedInterest;
        uint256 startTime;
        uint256 aprBps;
    }

    struct Loan {
        address borrower;
        uint256 nftCollateralTokenId;
        address nftCollateralAddress;
        address principalAddress;
        uint256 principalAmount;
        uint256 startTime;
        uint256 duration;
        Tranche[] tranche;
        uint256 protocolFee;
    }

    struct SignableRepaymentData {
        uint256 loanId;
        bytes callbackData;
        bool shouldDelegate;
    }

    struct LoanRepaymentData {
        SignableRepaymentData data;
        Loan loan;
        bytes borrowerSignature;
    }
}

interface IMultiSourceLoanWithMulticall is IMultiSourceLoan {
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);
}

contract PurchaseBundler is ReentrancyGuard {
    using FixedPointMathLib for uint256;
    using InputChecker for address;
    using SafeTransferLib for IERC20;

    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint256 private constant _MAX_SWAP_ARRAY_LENGTH = 10;
    uint256 private constant _MSG_SENDER_TOFFSET = 0x0;
    uint256 private constant _SWAPDATA_MAXBYTES = 0x2000;

    IAddressManager private immutable _marketplaceContractsAddressManager;
    IAddressManager private immutable _currencyManager;

    IMultiSourceLoanWithMulticall private immutable _multiSourceLoan;
    ICryptoPunksMarket private immutable _punkMarket;
    address private immutable _wrappedPunk;
    address private immutable _c721;

    event SellAndRepayExecuted(uint256[] loanIds);

    error MarketplaceAddressNotWhitelisted();
    error InvalidSwapDataLengthError();
    error CurrencyNotWhitelisted();
    error InvalidStateError();
    error CouldNotReturnEthError();
    error InvalidCollateralError();
    error InvalidExecutionData();

    constructor(
        address multiSourceLoanAddress,
        address marketplaceContracts,
        address payable punkMarketAddress,
        address payable wrappedPunkAddress,
        address payable c721Address,
        address currencyManager
    ) {
        multiSourceLoanAddress.checkNotZero();
        marketplaceContracts.checkNotZero();

        _multiSourceLoan = IMultiSourceLoanWithMulticall(multiSourceLoanAddress);
        _marketplaceContractsAddressManager = IAddressManager(marketplaceContracts);
        _punkMarket = ICryptoPunksMarket(punkMarketAddress);
        _wrappedPunk = wrappedPunkAddress;
        _c721 = c721Address;
        _currencyManager = IAddressManager(currencyManager);
    }

    // We keep Solmate's ReentrancyGuard as the nonReentrant modifier.

    function _saveOneSwapData(bytes memory data, uint256 index) private {
        uint256 length = data.length;
        if (length == 0) {
            revert InvalidSwapDataLengthError();
        }
        if (length > _SWAPDATA_MAXBYTES) {
            revert InvalidSwapDataLengthError();
        }
        assembly {
            // Store length at the beginning of the slot for this index
            let baseSlot := add(0x40, mul(index, _SWAPDATA_MAXBYTES))
            tstore(baseSlot, length)

            // Store each 32-byte chunk sequentially
            let ptr := add(data, 0x20) // Start from actual data, skip length prefix
            for { let i := 0 } lt(i, length) { i := add(i, 0x20) } {
                let chunk := mload(add(ptr, i))
                let chunkSlot := add(baseSlot, add(1, div(i, 0x20)))
                tstore(chunkSlot, chunk)
            }
        }
    }

    function _saveSwapData(bytes[] memory rawData) private {
        if (rawData.length > _MAX_SWAP_ARRAY_LENGTH) {
            revert InvalidSwapDataLengthError();
        }
        // Store swap data sequentially starting from index 0.
        uint256 baseIndex = 0;

        for (uint256 i = 0; i < rawData.length; i++) {
            _saveOneSwapData(rawData[i], baseIndex + i);
        }
    }

    function executeSell(
        address[] calldata currencies,
        uint256[] calldata currencyAmounts,
        IERC721[] calldata collections,
        uint256[] calldata tokenIds,
        address marketPlace,
        bytes[] calldata executionData,
        bytes[] calldata swapData
    ) external payable nonReentrant _storeMsgSender {
        if (executionData.length != collections.length || collections.length != tokenIds.length) {
            revert InvalidExecutionData();
        }

        // Validate that collections/tokenIds match the loan collateral
        for (uint256 i = 0; i < executionData.length; ++i) {
            if (executionData[i].length <= 4) {
                revert InvalidExecutionData();
            }
            IMultiSourceLoan.LoanRepaymentData memory repaymentData =
                abi.decode(executionData[i][4:], (IMultiSourceLoan.LoanRepaymentData));
            if (
                address(collections[i]) != repaymentData.loan.nftCollateralAddress
                    || tokenIds[i] != repaymentData.loan.nftCollateralTokenId
            ) {
                revert InvalidCollateralError();
            }
        }

        if (!_marketplaceContractsAddressManager.isWhitelisted(marketPlace)) {
            revert MarketplaceAddressNotWhitelisted();
        }

        address buyer = _msgSender();
        for (uint256 i = 0; i < currencies.length; ++i) {
            address currency = currencies[i];
            bool isERC20 = currency != ETH;
            if (!_currencyManager.isWhitelisted(address(currency)) && isERC20) {
                revert CurrencyNotWhitelisted();
            }
            uint256 balance = _getBalance(currency);
            bool notEnoughBalance = currencyAmounts[i] > balance;
            if (isERC20) {
                if (notEnoughBalance) {
                    IERC20(currency).safeTransferFrom(buyer, address(this), currencyAmounts[i] - balance);
                }
                IERC20(currency).safeApprove(marketPlace, currencyAmounts[i]);
            } else {
                if (notEnoughBalance) {
                    revert InvalidStateError(); // @dev we can't ask for eth, so it should be in the value sent
                }
            }
        }
        for (uint256 i = 0; i < collections.length; ++i) {
            collections[i].setApprovalForAll(marketPlace, true);
        }

        if (executionData.length > 1) revert InvalidExecutionData(); // @dev for now we only support 1 item, if we want to support more we need to make sure the marketplace supports it and adapt the execution info accordingly
        _sell(executionData, swapData);

        for (uint256 i = 0; i < currencies.length; ++i) {
            _paybackRemaining(currencies[i], _msgSender());
            if (currencies[i] != ETH) {
                IERC20(currencies[i]).safeApprove(marketPlace, 0);
            }
        }
        for (uint256 i = 0; i < collections.length; ++i) {
            collections[i].setApprovalForAll(marketPlace, false);
        }
        for (uint256 i = 0; i < collections.length; ++i) {
            _givebackNFTOrPunk(collections[i], tokenIds[i]);
        }
    }

    function _paybackRemaining(address currency, address _to) private {
        uint256 remaining = _getBalance(currency);
        if (remaining > 0) {
            _sendCurrency(currency, _to, remaining);
        }
    }

    function _givebackNFTOrPunk(IERC721 collection, uint256 tokenId) private {
        if (_isPunkWrapper(collection)) _givebackPunk(collection, tokenId);
        else _givebackNFT(collection, tokenId);
    }

    function _givebackPunk(IERC721 collection, uint256 tokenId) private {
        address nakedOwner = _punkMarket.punkIndexToAddress(tokenId);
        address buyer = _msgSender();
        if (nakedOwner != address(collection) && nakedOwner != buyer) {
            /// @dev if nakedOwner is not the wrapper, the punk has been unwrapped and should be transferred to the caller
            _punkMarket.transferPunk(buyer, tokenId);
        } else if (nakedOwner != buyer) {
            _givebackNFT(collection, tokenId);
        }
    }

    function _givebackNFT(IERC721 collection, uint256 tokenId) private {
        if (collection.ownerOf(tokenId) != _msgSender()) {
            collection.safeTransferFrom(collection.ownerOf(tokenId), _msgSender(), tokenId);
        }
    }

    function _sell(bytes[] calldata executionData, bytes[] calldata swapData) private {
        if (executionData.length == 0) {
            revert InvalidExecutionData();
        }
        _saveSwapData(swapData);
        _multiSourceLoan.multicall(executionData);
        uint256[] memory loanIds = new uint256[](executionData.length);
        uint256 total = executionData.length;
        for (uint256 i = 0; i < total; ++i) {
            if (executionData[i].length <= 4) {
                // it should include the selector and parameters
                revert InvalidExecutionData();
            }
            IMultiSourceLoan.LoanRepaymentData memory repaymentData =
                abi.decode(executionData[i][4:], (IMultiSourceLoan.LoanRepaymentData));
            loanIds[i] = repaymentData.data.loanId;
        }
        emit SellAndRepayExecuted(loanIds);
    }

    /// @dev Unwraps an NFT from a wrapper contract.
    /// @param wrapper The wrapper contract to unwrap the NFT from.
    /// @return The naked NFT address if successful, otherwise the wrapper contract doing nothing.
    function _isPunkWrapper(IERC721 wrapper) private view returns (bool) {
        return address(wrapper) == address(_c721) || address(wrapper) == address(_wrappedPunk);
    }

    modifier _storeMsgSender() {
        address msgSender = _tloadMsgSender();
        if (msgSender != address(0)) {
            _;
            return;
        }
        assembly {
            tstore(_MSG_SENDER_TOFFSET, caller())
        }
        _;
        assembly {
            tstore(_MSG_SENDER_TOFFSET, 0)
        }
    }

    function _msgSender() private view returns (address msgSender) {
        msgSender = _tloadMsgSender();
        if (msgSender == address(0)) {
            msgSender = msg.sender;
        }
    }

    function _tloadMsgSender() private view returns (address msgSender) {
        assembly {
            msgSender := tload(_MSG_SENDER_TOFFSET)
        }
    }

    function _getBalance(address _currency) private view returns (uint256) {
        if (_currency == ETH) {
            uint256 currentBalance;
            assembly {
                currentBalance := selfbalance()
            }
            return currentBalance;
        }
        return IERC20(_currency).balanceOf(address(this));
    }

    function _sendCurrency(address _currency, address _to, uint256 _amount) private {
        if (_currency == ETH) {
            (bool success,) = payable(_to).call{value: _amount}("");
            if (!success) {
                revert CouldNotReturnEthError();
            }
        } else {
            IERC20(_currency).safeTransfer(_to, _amount);
        }
    }
    fallback() external payable {}

    receive() external payable {}
}
