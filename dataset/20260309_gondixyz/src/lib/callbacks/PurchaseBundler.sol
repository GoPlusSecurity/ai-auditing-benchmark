// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import "@solmate/auth/Owned.sol";
import "@solmate/tokens/ERC721.sol";
import "@solmate/tokens/WETH.sol";
import "@solmate/utils/FixedPointMathLib.sol";
import "@solmate/utils/SafeTransferLib.sol";
import "@solmate/utils/ReentrancyGuard.sol";
import {IPool} from "@aave/interfaces/IPool.sol";

import "../../interfaces/external/IReservoir.sol";
import "../../interfaces/callbacks/IPurchaseBundler.sol";
import "../../interfaces/IPriceQuoter.sol";
import "../../interfaces/callbacks/ILoanCallback.sol";
import "../../interfaces/external/ICryptoPunksMarket.sol";
import "../../interfaces/external/IWrappedPunk.sol";
import "../../interfaces/external/ICryptoPunks721.sol";
import "../../interfaces/external/IUniversalRouter.sol";
import "../Multicall.sol";
import "../utils/WithProtocolFee.sol";
import "../loans/MultiSourceLoan.sol";
import "../utils/BytesLib.sol";
import "../AddressManager.sol";
import "../InputChecker.sol";
import "./TradeMarketplace.sol";
import {IAaveFlashLoanReceiver} from "../../interfaces/external/IAaveFlashLoanReceiver.sol";
import {IPoolAddressesProvider} from "@aave/interfaces/IPoolAddressesProvider.sol";
import {IPermit2} from "@permit2/interfaces/IPermit2.sol";
import {PURCHASE_BUNDLER_TAX_UPDATE_NOTICE} from "@const/const.sol";

contract PurchaseBundler is
    IPurchaseBundler,
    ILoanCallback,
    ERC721TokenReceiver,
    WithProtocolFee,
    TradeMarketplace,
    IAaveFlashLoanReceiver,
    Multicall
{
    using FixedPointMathLib for uint256;
    using BytesLib for bytes;
    using InputChecker for address;
    using SafeTransferLib for ERC20;
    using SafeTransferLib for WETH;

    uint256 public constant MAX_SLIPPAGE_DENOMINATOR = 1e5;

    /// keccak256("afterPrincipalTransfer(IMultiSourceLoan.Loan,uint256,bytes)")
    bytes4 private constant afterPrincipalTransferSelector = bytes4(
        keccak256(
            "afterPrincipalTransfer((address,uint256,address,address,uint256,uint256,uint256,(uint256,uint256,uint256,address,uint256,uint256,uint256)[],uint256),uint256,bytes)"
        )
    );

    /// keccak256("afterNFTTransfer(IMultiSourceLoan.Loan,bytes)")
    bytes4 private constant afterNFTTransferSelector = bytes4(
        keccak256(
            "afterNFTTransfer((address,uint256,address,address,uint256,uint256,uint256,(uint256,uint256,uint256,address,uint256,uint256,uint256)[],uint256),bytes)"
        )
    );

    uint256 private constant _PRECISION = 10000;
    uint256 private constant _MAX_TAX = 5000;
    uint256 private constant _MAX_SWAP_ARRAY_LENGTH = 10;
    uint256 private constant _MSG_SENDER_TOFFSET = 0x0;
    uint256 private constant _REENTRANCY_TOFFSET = 0x01;
    uint256 private constant _SKIP_REENTRANCY_TOFFSET = 0x02;
    uint256 private constant _SWAPDATA_EXECUTION_COUNTER_TOFFSET = 0x20;
    uint256 private constant _SWAPDATA_MAXBYTES = 0x2000;

    AddressManager private immutable _marketplaceContractsAddressManager;
    AddressManager private immutable _currencyManager;
    WETH private immutable _weth;

    mapping(address => Taxes) private _taxes;
    mapping(address => Taxes) private _pendingTaxes;
    mapping(address => uint256) private _pendingTaxesSetTime;

    MultiSourceLoan private immutable _multiSourceLoan;
    ICryptoPunksMarket private immutable _punkMarket;
    IWrappedPunk private immutable _wrappedPunk;
    ICryptoPunks721 private immutable _c721;
    IUniversalRouter private immutable _uniswapRouter;

    IPermit2 internal immutable _permit2;
    address private immutable _punkProxy;

    IPoolAddressesProvider internal immutable _aaveAddressProvider;

    event BNPLLoansStarted(uint256[] loanIds);
    event SellAndRepayExecuted(uint256[] loanIds);
    event TaxesPendingUpdate(address indexed module, Taxes newTax);
    event TaxesUpdated(address indexed module, Taxes newTax);

    error MarketplaceAddressNotWhitelisted();
    error InvalidSwapDataLengthError();
    error CurrencyNotWhitelisted();
    error TooMuchSlippageError();
    error InvalidSwapError();
    error InvalidStateError();

    error OnlyLoanCallableError();
    error CouldNotReturnEthError();
    error InvalidTaxesError(Taxes newTaxes);
    error InvalidCollateralError();
    error InvalidExecutionData();
    error InvalidTargetContractError();

    constructor(
        string memory name,
        address multiSourceLoanAddress,
        address marketplaceContracts,
        address payable wethAddress,
        address payable punkMarketAddress,
        address payable wrappedPunkAddress,
        address payable c721Address,
        address payable uniswapRouterAddress,
        address payable aaveAddressProvider,
        address payable permit2Address,
        address currencyManager,
        Taxes memory punkTaxes,
        uint256 minWaitTime,
        ProtocolFee memory protocolFee
    ) WithProtocolFee(tx.origin, minWaitTime, protocolFee) TradeMarketplace(name) {
        multiSourceLoanAddress.checkNotZero();
        marketplaceContracts.checkNotZero();

        _multiSourceLoan = MultiSourceLoan(multiSourceLoanAddress);
        _marketplaceContractsAddressManager = AddressManager(marketplaceContracts);
        _weth = WETH(wethAddress);
        _punkMarket = ICryptoPunksMarket(punkMarketAddress);
        _wrappedPunk = IWrappedPunk(wrappedPunkAddress);
        _c721 = ICryptoPunks721(c721Address);
        _uniswapRouter = IUniversalRouter(uniswapRouterAddress);
        _permit2 = IPermit2(permit2Address);
        _currencyManager = AddressManager(currencyManager);
        _punkProxy = _c721.punkProxyForUser(address(this));
        _aaveAddressProvider = IPoolAddressesProvider(aaveAddressProvider);
        ERC20(address(_weth)).safeApprove(permit2Address, type(uint256).max);
        _taxes[address(_punkMarket)] = punkTaxes;
    }

    modifier onlyLoanContract() {
        if (msg.sender != address(_multiSourceLoan)) {
            revert OnlyLoanCallableError();
        }
        _;
    }

    /// @dev Override to use transient storage and allow self-calls (for swapAndExecute internal dispatch via delegatecall).
    modifier nonReentrant() {
        bool skipReentrancy;
        assembly {
            skipReentrancy := tload(_SKIP_REENTRANCY_TOFFSET)
            tstore(_SKIP_REENTRANCY_TOFFSET, 0)
        }
        if (!skipReentrancy) {
            assembly {
                if tload(_REENTRANCY_TOFFSET) {
                    mstore(0, 0)
                    revert(0, 0)
                }
            }
        }
        assembly {
            tstore(_REENTRANCY_TOFFSET, 1)
        }
        _;
        if (!skipReentrancy) {
            assembly {
                tstore(_REENTRANCY_TOFFSET, 0)
            }
        }
    }

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
        // Use execution counter as base index to prevent corruption in batch transactions
        uint256 baseIndex;
        assembly {
            baseIndex := tload(_SWAPDATA_EXECUTION_COUNTER_TOFFSET)
        }

        for (uint256 i = 0; i < rawData.length; i++) {
            _saveOneSwapData(rawData[i], baseIndex + i);
        }
    }

    function _loadAndIncrementExecutionCounter() private returns (uint256 result) {
        assembly {
            result := tload(_SWAPDATA_EXECUTION_COUNTER_TOFFSET)
            tstore(_SWAPDATA_EXECUTION_COUNTER_TOFFSET, add(result, 1))
        }
    }

    /// @dev Loads swap data from transient storage into memory.
    /// @notice The free memory pointer update uses `and(add(length, 0x1f), not(0x1f))` to round
    /// the length up to the next 32-byte boundary. This ensures proper memory alignment:
    /// - `add(length, 0x1f)` adds 31 to length
    /// - `not(0x1f)` creates mask 0xffffffe0 (clears last 5 bits)
    /// - `and(...)` rounds down to nearest multiple of 32, effectively rounding length up
    /// Example: length=50 -> (50+31) & ~31 = 64
    function _loadSwapData(uint256 index) private view returns (bytes memory result) {
        uint256 length;
        assembly {
            let baseSlot := add(0x40, mul(index, _SWAPDATA_MAXBYTES))
            length := tload(baseSlot)
        }
        assembly {
            result := mload(0x40) // allocate new bytes array
            mstore(result, length)
            let baseSlot := add(0x40, mul(index, _SWAPDATA_MAXBYTES))
            let ptr := add(result, 0x20)
            for { let i := 0 } lt(i, length) { i := add(i, 0x20) } {
                let chunkSlot := add(baseSlot, add(1, div(i, 0x20)))
                let chunk := tload(chunkSlot)
                mstore(add(ptr, i), chunk)
            }
            mstore(0x40, add(ptr, and(add(length, 0x1f), not(0x1f)))) // update free mem ptr (rounded to 32-byte boundary)
        }
    }

    function approveForSwap(address currency) external {
        if (!_currencyManager.isWhitelisted(currency)) {
            revert CurrencyNotWhitelisted();
        }
        ERC20(currency).safeApprove(address(_permit2), type(uint256).max);
    }

    /// @inheritdoc IPurchaseBundler
    /// @dev Buy calls emit loan -> Before trying to transfer the NFT but after transfering the principal
    /// emitLoan will call the afterPrincipalTransfer Hook, which will execute the purchase.
    function buy(bytes[] calldata executionData) external payable nonReentrant returns (uint256[] memory loanIds) {
        loanIds = _buy(executionData);
    }

    /// @dev Similar to buy. Hook is called after the NFT transfer but before transfering WETH for repayment.
    /// @inheritdoc IPurchaseBundler
    function sell(bytes[] calldata executionData, bytes[] calldata swapData) external nonReentrant {
        _sell(executionData, swapData);
    }

    function executeSell(
        address[] calldata currencies,
        uint256[] calldata currencyAmounts,
        ERC721[] calldata collections,
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
                    ERC20(currency).safeTransferFrom(buyer, address(this), currencyAmounts[i] - balance);
                }
                ERC20(currency).safeApprove(marketPlace, currencyAmounts[i]);
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
                ERC20(currencies[i]).safeApprove(marketPlace, 0);
            }
        }
        for (uint256 i = 0; i < collections.length; ++i) {
            collections[i].setApprovalForAll(marketPlace, false);
        }
        for (uint256 i = 0; i < collections.length; ++i) {
            _givebackNFTOrPunk(collections[i], tokenIds[i]);
        }
    }

    /// @dev This function is called by the buyer to execute a loaned sell with a buy.
    /// the borrower must make a listing in loan.principal
    /// the buyer must send eth value and it will receive the NFT without any wrapper.
    function executeSellWithLoan(ExecuteSellWithLoanArgs calldata args) external payable _storeMsgSender {
        address aaveV3Pool = _aaveAddressProvider.getPool();
        if (address(args.borrowArgs.pool) != aaveV3Pool) {
            revert InvalidCallbackError();
        }
        bytes memory params = abi.encode(args);
        uint256[] memory interestRateModes = new uint256[](args.borrowArgs.assets.length);
        for (uint256 i = 0; i < interestRateModes.length; i++) {
            interestRateModes[i] = 0;
        }
        args.borrowArgs.pool
            .flashLoan(
                address(this),
                args.borrowArgs.assets,
                args.borrowArgs.amounts,
                interestRateModes,
                address(this),
                params,
                0
            );
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external override(IAaveFlashLoanReceiver) returns (bool) {
        (ExecuteSellWithLoanArgs memory args) = abi.decode(params, (ExecuteSellWithLoanArgs));
        address aaveV3Pool = IPoolAddressesProvider(_aaveAddressProvider).getPool();

        if (address(args.borrowArgs.pool) != aaveV3Pool || msg.sender != aaveV3Pool || initiator != address(this)) {
            revert InvalidCallbackError();
        }

        if (args.unwrap) {
            _weth.withdraw(_weth.balanceOf(address(this)));
        }

        this.executeSell(
            args.executeSellArgs.currencies,
            args.executeSellArgs.currencyAmounts,
            args.executeSellArgs.collections,
            args.executeSellArgs.tokenIds,
            args.executeSellArgs.marketPlace,
            args.executeSellArgs.executionData,
            args.executeSellArgs.swapData
        );
        _multiSourceLoan.multicall(args.loanExecutionData);
        address _buyer = _msgSender();
        for (uint256 i = 0; i < args.swapCurrencies.length; i++) {
            bytes memory swapData = args.swapData[i];
            address currency = address(args.swapCurrencies[i]);
            if (!_currencyManager.isWhitelisted(currency)) {
                revert CurrencyNotWhitelisted();
            }
            uint160 amount = args.swapAmounts[i];

            uint256 ethValue;
            if (currency == ETH) {
                ethValue = amount;
            } else {
                ERC20(currency).safeTransferFrom(_buyer, address(this), amount);
                _permit2.approve(currency, address(_uniswapRouter), amount, 0);
                ethValue = 0;
            }

            (bool swapSuccess,) = address(_uniswapRouter).call{value: ethValue}(swapData);
            if (!swapSuccess) {
                revert InvalidCallbackError();
            }
            _paybackRemaining(currency, _msgSender());
        }

        for (uint256 i = 0; i < assets.length; i++) {
            uint256 owed = amounts[i] + premiums[i];
            ERC20 asset = ERC20(assets[i]);
            uint256 balance = asset.balanceOf(address(this));
            if (balance < owed) {
                asset.safeTransferFrom(_buyer, address(this), owed - balance);
            } else if (balance > owed) {
                asset.safeTransfer(_buyer, balance - owed);
            }
            asset.safeApprove(address(args.borrowArgs.pool), owed);
        }
        return true;
    }

    function swapAndExecute(IPurchaseBundler.SwapAndExecuteParams calldata args)
        external
        payable
        nonReentrant
        _storeMsgSender
    {
        // Validate target is this contract, a whitelisted marketplace or MultiSourceLoan
        if (
            args.target != address(this) && !_marketplaceContractsAddressManager.isWhitelisted(args.target)
                && args.target != address(_multiSourceLoan)
        ) {
            revert InvalidTargetContractError();
        }

        address caller = _msgSender();

        // Collect inputCurrencies from caller
        for (uint256 i = 0; i < args.inputCurrencies.length; ++i) {
            address currency = args.inputCurrencies[i];
            uint256 amount = args.amountsToSwap[i];

            if (currency == ETH) {
                // ETH must be sent as msg.value, verify enough was sent as value
                if (address(this).balance < amount) {
                    revert InvalidStateError();
                }
            } else {
                if (!_currencyManager.isWhitelisted(currency)) {
                    revert CurrencyNotWhitelisted();
                }
                // Pull needed ERC20 from caller
                uint256 balance = ERC20(currency).balanceOf(address(this));
                if (amount > balance) {
                    ERC20(currency).safeTransferFrom(caller, address(this), amount - balance);
                }
            }
        }

        // Execute swap if swap data is provided
        if (args.swapData.length > 0) {
            if (args.swapData.length > _SWAPDATA_MAXBYTES) {
                revert InvalidSwapDataLengthError();
            }
            // Approve all collected ERC20 inputCurrencies for the router via permit2
            for (uint256 i = 0; i < args.inputCurrencies.length; ++i) {
                if (args.inputCurrencies[i] != ETH) {
                    _permit2.approve(args.inputCurrencies[i], address(_uniswapRouter), type(uint160).max, 0);
                }
            }

            (bool swapSuccess,) = address(_uniswapRouter).call{value: address(this).balance}(args.swapData);
            if (!swapSuccess) {
                revert InvalidCallbackError();
            }
        }

        // Approve outputCurrencies for marketplace target (result of swap)
        if (args.target != address(this)) {
            for (uint256 i = 0; i < args.outputCurrencies.length; ++i) {
                if (args.outputCurrencies[i] != ETH) {
                    ERC20(args.outputCurrencies[i]).safeApprove(args.target, type(uint256).max);
                }
            }
        }

        // Execute the target call
        if (args.target == address(this)) {
            bytes4 sel = bytes4(args.executionCalldata[:4]);
            if (sel != this.buy.selector && sel != this.sell.selector && sel != this.executeSell.selector) {
                revert InvalidExecutionData();
            }
            assembly {
                tstore(_SKIP_REENTRANCY_TOFFSET, 1)
            }
            (bool success,) = address(this).delegatecall(args.executionCalldata);
            if (!success) {
                revert InvalidCallbackError();
            }
        } else {
            (bool success,) = args.target.call{value: args.executionValue}(args.executionCalldata);
            if (!success) {
                revert InvalidCallbackError();
            }
        }

        // Reset approvals for outputCurrencies
        if (args.target != address(this)) {
            for (uint256 i = 0; i < args.outputCurrencies.length; ++i) {
                if (args.outputCurrencies[i] != ETH) {
                    ERC20(args.outputCurrencies[i]).safeApprove(args.target, 0);
                }
            }
        }

        // Payback remaining for both input and output currencies
        for (uint256 i = 0; i < args.inputCurrencies.length; ++i) {
            _paybackRemaining(args.inputCurrencies[i], caller);
        }
        for (uint256 i = 0; i < args.outputCurrencies.length; ++i) {
            _paybackRemaining(args.outputCurrencies[i], caller);
        }
        _paybackRemaining(ETH, caller);
    }

    /// @inheritdoc ILoanCallback
    /// @dev method for current MSL
    function afterPrincipalTransfer(IMultiSourceLoan.Loan calldata _loan, uint256 _fee, bytes calldata _executionData)
        external
        onlyLoanContract
        returns (bytes4)
    {
        _afterPrincipalTransfer(_loan, _fee, _executionData);
        return afterPrincipalTransferSelector;
    }

    /// @inheritdoc ILoanCallback
    /// @dev method for current MSL
    function afterNFTTransfer(IMultiSourceLoan.Loan calldata _loan, bytes calldata _executionData)
        external
        onlyLoanContract
        returns (bytes4)
    {
        _afterNFTTransfer(_loan, _executionData);
        return afterNFTTransferSelector;
    }

    function _afterPrincipalTransfer(IMultiSourceLoan.Loan memory _loan, uint256 _fee, bytes calldata _executionData)
        private
    {
        ExecutionInfo memory purchaseBundlerExecutionInfo = abi.decode(_executionData, (ExecutionInfo));
        IReservoir.ExecutionInfo memory executionInfo = purchaseBundlerExecutionInfo.reservoirExecutionInfo;
        if (!_marketplaceContractsAddressManager.isWhitelisted(executionInfo.module)) {
            revert MarketplaceAddressNotWhitelisted();
        }
        ERC20 purchaseCurrency = ERC20(purchaseBundlerExecutionInfo.purchaseCurrency);
        bool purchaseCurrencyIsERC20 = purchaseBundlerExecutionInfo.purchaseCurrency != ETH;

        uint256 borrowed = _loan.principalAmount - _fee;
        /// @dev If the currency is ETH. we unwrap WETH to ETH. We assume the delta between purchase and borrowed was sent as value.
        /// @dev _loan.borrower is the one executing the loan, in BNPL is the buyer.
        if (purchaseCurrencyIsERC20) {
            ERC20(purchaseBundlerExecutionInfo.purchaseCurrency)
                .safeTransferFrom(_loan.borrower, address(this), purchaseBundlerExecutionInfo.amount);
        }
        bool success;
        if (purchaseBundlerExecutionInfo.swapData.length > 0) {
            _permit2.approve(_loan.principalAddress, address(_uniswapRouter), type(uint160).max, 0);
            (success,) = address(_uniswapRouter).call{value: purchaseBundlerExecutionInfo.swapValue}(
                purchaseBundlerExecutionInfo.swapData
            );
            if (!success) {
                revert InvalidCallbackError();
            }
        }

        // Track balance before to calculate actual purchase amount
        uint256 balanceBeforeBuy = _getBalance(purchaseBundlerExecutionInfo.purchaseCurrency);

        if (purchaseCurrencyIsERC20) {
            purchaseCurrency.safeApprove(executionInfo.module, purchaseCurrency.balanceOf(address(this)));
        }

        (success,) = executionInfo.module.call{value: executionInfo.value}(executionInfo.data);
        if (!success) {
            revert InvalidCallbackError();
        }

        // Calculate actual purchase amount from balance delta, fallback to executionInfo.value
        uint256 balanceAfterBuy = _getBalance(purchaseBundlerExecutionInfo.purchaseCurrency);
        uint256 balanceDelta = balanceBeforeBuy > balanceAfterBuy ? balanceBeforeBuy - balanceAfterBuy : 0;
        // Use the greater of balance delta or executionInfo.value to prevent tax evasion
        uint256 purchaseAmount = balanceDelta > executionInfo.value ? balanceDelta : executionInfo.value;

        /// @dev If contract must be owner we transfer the NFT to the purchaseBundler contract.
        if (executionInfo.module == address(_punkMarket)) {
            /// @dev Wrap punk and transfer it to the borrower (loan is in CryptoPunks-721).
            _punkMarket.transferPunk(address(_punkProxy), _loan.nftCollateralTokenId);
            _c721.wrapPunk(_loan.nftCollateralTokenId);
            _c721.safeTransferFrom(address(this), _loan.borrower, _loan.nftCollateralTokenId);
        } else if (purchaseBundlerExecutionInfo.contractMustBeOwner) {
            ERC721(_loan.nftCollateralAddress).transferFrom(address(this), _loan.borrower, _loan.nftCollateralTokenId);
        }

        _handleProtocolFee(
            _loan.borrower, purchaseAmount, address(purchaseCurrency), _taxes[executionInfo.module].buyTax
        );

        if (purchaseCurrencyIsERC20) {
            purchaseCurrency.safeApprove(executionInfo.module, 0);
        }

        _paybackRemaining(purchaseBundlerExecutionInfo.purchaseCurrency, address(_loan.borrower));
        _paybackRemaining(_loan.principalAddress, address(_loan.borrower));
    }

    /// @dev See notes for `afterPrincipalTransfer`.
    function _afterNFTTransfer(IMultiSourceLoan.Loan memory loan, bytes calldata _executionData) private {
        ExecutionInfo memory purchaseBundlerExecutionInfo = abi.decode(_executionData, (ExecutionInfo));
        IReservoir.ExecutionInfo memory executionInfo = purchaseBundlerExecutionInfo.reservoirExecutionInfo;
        bool contractMustBeOwner = purchaseBundlerExecutionInfo.contractMustBeOwner;
        if (!_marketplaceContractsAddressManager.isWhitelisted(executionInfo.module)) {
            revert MarketplaceAddressNotWhitelisted();
        }
        address loanCurrency = loan.principalAddress;
        address purchaseCurrency = purchaseBundlerExecutionInfo.purchaseCurrency;

        // Snapshot balance before marketplace execution to calculate actual sale proceeds
        uint256 balanceBeforeSale = _getBalance(purchaseCurrency);

        bool success;
        /// @dev Similar to `afterPrincipalTransfer`, we use the matchOrder method to avoid extra transfers.
        /// Note that calling fullfilment on seaport will fail on this contract.
        if (executionInfo.module == address(_punkMarket)) {
            success = _sellReleasedCollateralInPunkMarket(loan, executionInfo);
        } else {
            success = _sellReleasedCollateralInMarketplace(loan, executionInfo, contractMustBeOwner);
        }
        if (!success) {
            revert InvalidCallbackError();
        }

        // Calculate actual sale proceeds from balance delta
        uint256 balanceAfterSale = _getBalance(purchaseCurrency);
        uint256 saleAmount = balanceAfterSale > balanceBeforeSale ? balanceAfterSale - balanceBeforeSale : 0;

        _handleProtocolFee(
            loan.borrower,
            saleAmount,
            address(purchaseBundlerExecutionInfo.purchaseCurrency),
            _taxes[executionInfo.module].sellTax
        );

        // The swap is done from purchaseCurrency (as we sold the item) to loan currency
        // Slippage is checked against price from the price quoter
        if (purchaseBundlerExecutionInfo.swapData.length > 0) {
            (uint256 purchaseCurrencyBalance, uint256 loanCurrencyBalance) = _swapAndCheck(
                purchaseCurrency,
                ERC20(loan.principalAddress),
                purchaseBundlerExecutionInfo.swapValue,
                purchaseBundlerExecutionInfo.maxSlippage,
                purchaseBundlerExecutionInfo.swapData
            );

            ERC20(loanCurrency).safeTransfer(loan.borrower, loanCurrencyBalance);
            _sendCurrency(purchaseCurrency, loan.borrower, purchaseCurrencyBalance);
        } else {
            // No swap needed - transfer the sale proceeds directly to borrower
            _paybackRemaining(loanCurrency, loan.borrower);
        }
    }

    /// @inheritdoc IPurchaseBundler
    function getMultiSourceLoanAddress() external view override returns (address) {
        return address(_multiSourceLoan);
    }

    /// @inheritdoc IPurchaseBundler
    function getTaxes(address module) external view returns (Taxes memory) {
        return _taxes[module];
    }

    /// @notice Get the pending tax and the time it was set.
    /// @param module The module address to query.
    /// @return pendingTax The pending tax values.
    function getPendingTaxes(address module) external view returns (Taxes memory) {
        return _pendingTaxes[module];
    }

    /// @notice Get the pending tax and the time it was set.
    /// @param module The module address to query.
    /// @return setTime The time when the pending tax was set.
    function getPendingTaxesSetTime(address module) external view returns (uint256) {
        return _pendingTaxesSetTime[module];
    }

    /// @inheritdoc IPurchaseBundler
    /// @param module The module address to set the tax for.
    /// @dev if the tax is not initialized this method sets it immediately.
    /// @param newTax The new tax value.
    function updateTaxes(address module, Taxes calldata newTax) external onlyOwner {
        if (newTax.buyTax > _MAX_TAX || newTax.sellTax > _MAX_TAX) {
            revert InvalidTaxesError(newTax);
        }
        // uninitialized taxes can be set immediately, otherwise we need to wait for the notice period
        if (_pendingTaxesSetTime[module] == 0) {
            _taxes[module] = newTax;
        }
        _pendingTaxes[module] = newTax;
        _pendingTaxesSetTime[module] = block.timestamp;

        emit TaxesPendingUpdate(module, newTax);
    }

    /// @notice Set the tax if enough notice has been given.
    /// @param module The module address to finalize the tax for.
    function setTaxes(address module) external onlyOwner {
        uint256 pendingSetTime = _pendingTaxesSetTime[module];
        if (block.timestamp < pendingSetTime + PURCHASE_BUNDLER_TAX_UPDATE_NOTICE) {
            revert TooEarlyError(pendingSetTime);
        }
        Taxes memory newTax = _pendingTaxes[module];
        _taxes[module] = newTax;

        emit TaxesUpdated(module, newTax);
    }

    function _buy(bytes[] calldata executionData) private returns (uint256[] memory) {
        if (executionData.length == 0) {
            revert InvalidExecutionData();
        }
        bytes[] memory encodedOutput = _multiSourceLoan.multicall(executionData);
        uint256[] memory loanIds = new uint256[](encodedOutput.length);
        uint256 total = encodedOutput.length;
        for (uint256 i; i < total;) {
            if (executionData[i].length <= 4) {
                // it should include the selector and parameters
                revert InvalidExecutionData();
            }
            loanIds[i] = abi.decode(encodedOutput[i], (uint256));
            unchecked {
                ++i;
            }
        }

        /// Return any remaining funds to sender.
        uint256 remainingBalance;
        assembly {
            remainingBalance := selfbalance()
        }
        if (remainingBalance != 0) {
            (bool success,) = payable(msg.sender).call{value: remainingBalance}("");
            if (!success) {
                revert CouldNotReturnEthError();
            }
        }

        emit BNPLLoansStarted(loanIds);
        return loanIds;
    }

    /*
        Tax applied over a value.
        @param taxpayer The actor to apply the tax to.
        @param value The value to apply the tax to.
        @param currency The currency to apply the tax to.
        @param loan The loan to apply the tax to.
        @param tax The tax to apply.
    */
    function _handleProtocolFee(address taxpayer, uint256 value, address currency, uint256 tax) private {
        if (tax == 0 || value == 0) {
            return;
        }
        uint256 taxAmount = value.mulDivUp(tax, _PRECISION);
        _sendCurrency(currency, _protocolFee.recipient, taxAmount);
    }

    function _paybackRemaining(address currency, address _to) private {
        uint256 remaining = _getBalance(currency);
        if (remaining > 0) {
            _sendCurrency(currency, _to, remaining);
        }
    }

    function _paybackRemainingWeth() private {
        uint256 remaining = _weth.balanceOf(address(this));
        _weth.withdraw(remaining);
        (bool success,) = payable(msg.sender).call{value: remaining}("");
        if (!success) {
            revert CouldNotReturnEthError();
        }
    }

    function _givebackNFTOrPunk(ERC721 collection, uint256 tokenId) private {
        if (_isPunkWrapper(collection)) _givebackPunk(collection, tokenId);
        else _givebackNFT(collection, tokenId);
    }

    function _givebackPunk(ERC721 collection, uint256 tokenId) private {
        address nakedOwner = _punkMarket.punkIndexToAddress(tokenId);
        address buyer = _msgSender();
        if (nakedOwner != address(collection) && nakedOwner != buyer) {
            /// @dev if nakedOwner is not the wrapper, the punk has been unwrapped and should be transferred to the caller
            _punkMarket.transferPunk(buyer, tokenId);
        } else if (nakedOwner != buyer) {
            _givebackNFT(collection, tokenId);
        }
    }

    function _givebackNFT(ERC721 collection, uint256 tokenId) private {
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

    /// @dev Sell the NFT in the punk market before making the loan repayment
    /// @param loan The loan to sell the NFT from
    /// @param executionInfo The execution info of the market, includes calldata to execute the market sell
    /// @return success True if the sell was successful, false otherwise
    function _sellReleasedCollateralInPunkMarket(
        IMultiSourceLoan.Loan memory loan,
        IReservoir.ExecutionInfo memory executionInfo
    ) private returns (bool success) {
        /// @dev Unwrap punk
        ERC721 collateral = ERC721(loan.nftCollateralAddress);
        ERC20 principal = ERC20(loan.principalAddress);
        uint256 tokenId = loan.nftCollateralTokenId;
        uint256 owedToBorrower = executionInfo.value;

        collateral.transferFrom(loan.borrower, address(this), tokenId);
        _unwrapPunk(collateral, tokenId);

        /// @dev Execute sell, claim ETH from the contract and wrap it before sending it to the borrower.
        (success,) = executionInfo.module.call(executionInfo.data);
        _punkMarket.withdraw();
    }

    /// @dev Sell the NFT in another market before making the loan repayment
    /// @param loan The loan to sell the NFT from
    /// @param executionInfo The execution info of the market, includes calldata to execute the market sell
    /// @param contractMustBeOwner If this contract must own the NFT and take the buyer's role in the market
    /// @return success True if the sell was successful, false otherwise
    function _sellReleasedCollateralInMarketplace(
        IMultiSourceLoan.Loan memory loan,
        IReservoir.ExecutionInfo memory executionInfo,
        bool contractMustBeOwner
    ) private returns (bool success) {
        if (!contractMustBeOwner) {
            (success,) = executionInfo.module.call{value: executionInfo.value}(executionInfo.data);
            return success;
        }
        ERC721 collateral = ERC721(loan.nftCollateralAddress);
        uint256 tokenId = loan.nftCollateralTokenId;

        collateral.transferFrom(loan.borrower, address(this), tokenId);
        collateral.approve(executionInfo.module, tokenId);
        (success,) = executionInfo.module.call{value: executionInfo.value}(executionInfo.data);
    }

    /// @dev performs the swap and checks slippage against the price from the price quoter.
    /// @dev note: out currency must be an ERC20 (limitation by optimizations).
    /// @param quoterData abi.encode(address quoter, bytes quoterArgs)
    function _swapAndCheck(
        address currencyIn,
        ERC20 currencyOut,
        uint256 swapValue,
        uint256 maxSlippage,
        bytes memory quoterData
    ) private returns (uint256 newInBalance, uint256 newOutBalance) {
        uint256 originalInBalance = _getBalance(currencyIn);
        uint256 originalOutBalance = currencyOut.balanceOf(address(this));
        (address quoter, bytes memory quoterArgs) = abi.decode(quoterData, (address, bytes));
        if (!_marketplaceContractsAddressManager.isWhitelisted(quoter)) revert InvalidCallbackError();
        uint256 price = IPriceQuoter(quoter).getPrice(currencyIn, address(currencyOut), quoterArgs);
        uint256 executionCounter = _loadAndIncrementExecutionCounter();
        bytes memory swapData = _loadSwapData(executionCounter);
        if (swapData.length == 0) revert InvalidCallbackError();
        _permit2.approve(currencyIn, address(_uniswapRouter), type(uint160).max, 0);
        (bool success,) = address(_uniswapRouter).call{value: swapValue}(swapData);
        if (!success) {
            revert InvalidCallbackError();
        }
        newInBalance = _getBalance(currencyIn);
        newOutBalance = currencyOut.balanceOf(address(this));
        if (newOutBalance <= originalOutBalance) {
            revert InvalidSwapError();
        }
        _checkSwapSlippage(originalInBalance - newInBalance, newOutBalance - originalOutBalance, price, maxSlippage);
    }

    /// @dev Check if the slippage is too much. We check `amountOut / amountIn >= price * (MAX_SLIPPAGE_DENOMINATOR - maxSlippage) / MAX_SLIPPAGE_DENOMINATOR`
    /// @dev price is scaled by 10 ** (QUOTER_PRECISION - currencyIn.decimals + currencyOut.decimals)
    function _checkSwapSlippage(uint256 amountIn, uint256 amountOut, uint256 price, uint256 maxSlippage) private pure {
        // Reject zero amounts to prevent division issues
        if (
            amountOut * QUOTER_PRECISION * MAX_SLIPPAGE_DENOMINATOR
                < amountIn * price * (MAX_SLIPPAGE_DENOMINATOR - maxSlippage)
        ) {
            revert TooMuchSlippageError();
        }
    }

    /// @dev Unwraps an NFT from a wrapper contract.
    /// @param wrapper The wrapper contract to unwrap the NFT from.
    /// @param tokenId The token ID of the NFT to unwrap.
    function _unwrapPunk(ERC721 wrapper, uint256 tokenId) private {
        if (address(wrapper) == address(_c721)) {
            _c721.unwrapPunk(tokenId);
        } else if (address(wrapper) == address(_wrappedPunk)) {
            _wrappedPunk.burn(tokenId);
        }
    }

    /// @dev Unwraps an NFT from a wrapper contract.
    /// @param wrapper The wrapper contract to unwrap the NFT from.
    /// @return The naked NFT address if successful, otherwise the wrapper contract doing nothing.
    function _isPunkWrapper(ERC721 wrapper) private view returns (bool) {
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
        return ERC20(_currency).balanceOf(address(this));
    }

    function _sendCurrency(address _currency, address _to, uint256 _amount) private {
        if (_currency == ETH) {
            (bool success,) = payable(_to).call{value: _amount}("");
            if (!success) {
                revert CouldNotReturnEthError();
            }
        } else {
            ERC20(_currency).safeTransfer(_to, _amount);
        }
    }
    fallback() external payable {}

    receive() external payable {}
}
