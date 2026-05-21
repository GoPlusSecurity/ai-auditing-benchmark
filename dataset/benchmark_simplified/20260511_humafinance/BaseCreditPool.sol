// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface IFeeManager {
    function calcCorrection(
        uint256 dueDate,
        uint256 aprInBps,
        uint256 amount
    ) external view returns (uint256 correction);

    function distBorrowingAmount(uint256 borrowAmount)
        external
        view
        returns (uint256 amtToBorrower, uint256 platformFees);

    function getDueInfo(
        BaseStructs.CreditRecord memory _cr,
        BaseStructs.CreditRecordStatic memory _crStatic
    )
        external
        view
        returns (
            uint256 periodsPassed,
            uint96 feesAndInterestDue,
            uint96 totalDue,
            uint96 unbilledPrincipal,
            int96 totalCharges
        );
}

interface IHumaConfig {
    function paused() external view returns (bool);
}

interface IBasePoolConfig {
    function distributeIncome(uint256 value) external returns (uint256 poolIncome);
    function reverseIncome(uint256 value) external returns (uint256 poolIncome);
    function getCoreData()
        external
        view
        returns (
            address underlyingToken_,
            address poolToken_,
            address humaConfig_,
            address feeManager_
        );
    function poolAprInBps() external view returns (uint256);
    function maxCreditLine() external view returns (uint256);
    function poolDefaultGracePeriodInSeconds() external view returns (uint256);
}

library BaseStructs {

    struct CreditRecord {
        uint96 unbilledPrincipal; // the amount of principal not included in the bill
        uint64 dueDate; // the due date of the next payment
        // correction is the adjustment of interest over or under-counted because of drawdown
        // or principal payment in the middle of a billing period
        int96 correction;
        uint96 totalDue; // the due amount of the next payment
        uint96 feesAndInterestDue; // interest and fees due for the next payment
        uint16 missedPeriods; // # of consecutive missed payments, for default processing
        uint16 remainingPeriods; // # of payment periods until the maturity of the credit line
        CreditState state; // status of the credit line
    }

    struct CreditRecordStatic {
        uint96 creditLimit; // the limit of the credit line
        uint16 aprInBps; // annual percentage rate in basis points, 3.75% is represented as 375
        uint16 intervalInDays; // # of days in one billing period
        uint96 defaultAmount; // the amount that has been defaulted.
    }

    enum CreditState {
        Deleted,
        Requested,
        Approved,
        GoodStanding,
        Delayed,
        Defaulted
    }
}

interface ICredit {
    /// Makes drawdown from an approved credit line
    function drawdown(uint256 _borrowAmount) external;

    function refreshAccount(address borrower) external returns (BaseStructs.CreditRecord memory cr);

    function requestCredit(
        uint256 _creditLimit,
        uint256 _intervalInDays,
        uint256 _numOfPayments
    ) external;

}

// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

library AddressUpgradeable {

    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

// OpenZeppelin Contracts (last updated v4.8.1) (proxy/utils/Initializable.sol)

abstract contract Initializable {

    uint8 private _initialized;

    bool private _initializing;

    event Initialized(uint8 version);

    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}

// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

interface IERC20 {

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/ERC20.sol)

library Address {

    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly
                /// @solidity memory-safe-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/utils/SafeERC20.sol)

library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

interface IHDT {

    function withdrawableFundsOf(address owner) external view returns (uint256);

    function mintAmount(address account, uint256 amount) external returns (uint256 shares);

    function burnAmount(address account, uint256 amount) external returns (uint256 shares);

    function assetToken() external view returns (address);
}

// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

contract Errors {
    // common
    error sameValue(); // 0x0811ff09
    error zeroAddressProvided(); // 0x5ff75ab0
    error zeroAmountProvided(); // 0x71799f2a
    error amountTooLow(); // 0x5b05bfbf
    error invalidBasisPointHigherThan10000(); // 0x07982d85
    error withdrawnAmountHigherThanBalance(); // 0x477c0ab2

    // security
    error permissionDeniedNotAdmin(); // 0xf2c5b6a7
    error permissionDeniedNotLender(); // 0x68299b20
    error evaluationAgentServiceAccountRequired(); // 0x9b3b1ed6
    error paymentDetectionServiceAccountRequired(); // 0x731b978f
    error poolOperatorRequired(); // 0xdc2dc6d0
    error notPoolOwner(); // 0xd39208c9
    error notProtocolOwner(); // 0x97924c20
    error notEvaluationAgent(); // 0x66f7b8b7
    error notOperator(); // 0xf67113fe
    error notPoolOwnerTreasury(); // 0x325bf3c2
    error notPoolOwnerOrEA(); // 0xd6ed9384
    error notPoolOwnerTreasuryOrEA(); // 0xc74cb44c
    error notPauser(); // 0xdcdea7c8
    error notPool(); // 0x26d29bbf
    error drawdownFunctionUsedInsteadofDrawdownWithReceivable(); // 0x7e737537
    error notNFTOwner(); // 0x091a5762

    // system config
    error defaultGracePeriodLessThanMinAllowed(); // 0xa733ff9c
    error treasuryFeeHighThanUpperLimit(); // 0x39cda0d1
    error alreadyAnOperator(); // 0x75cea0fc
    error alreadyAPauser(); // 0xfbca9e38
    error alreadyPoolAdmin(); // 0x7bb356e2

    // fee config
    error minPrincipalPaymentRateSettingTooHigh(); // 0xc11fc042

    // pool config
    error proposedEADoesNotOwnProvidedEANFT(); // 0x75b0da3b
    error underlyingTokenNotApprovedForHumaProtocol(); // 0xce179d6d
    error poolOwnerNotEnoughLiquidity(); // 0xe95282e2
    error evaluationAgentNotEnoughLiquidity(); // 0x67e26217

    // pool state
    error protocolIsPaused(); // 0x8f6fa2d4
    error poolIsNotOn(); // 0x69b355df

    // pool credit line
    error creditExpiredDueToFirstDrawdownTooLate(); // 0x9fac7390
    error creditExpiredDueToMaturity(); // 0xa52f3c3f
    error creditLineNotInGoodStandingState(); // 0x96e79474
    error creditLineNotInStateForMakingPayment(); // 0xf023e48b
    error creditLineNotInStateForDrawdown(); // 0x4ff95a6d
    error creditLineExceeded(); // 0xef7d66ff
    error creditLineAlreadyExists(); // 0x6c5805f2
    error creditLineGreatThanUpperLimit(); // 0xd8c27d2f
    error greaterThanMaxCreditLine(); // 0x8a754ae8
    error requestedCreditWithZeroDuration(); // 0xb16dd34d
    error onlyBorrowerOrEACanReduceCreditLine(); // 0xd61dbe31
    error creditLineNotInApprovedState(); // 0xfc91a989
    error paymentIdNotUnderReview(); // 0xd1696aaa
    error creditLineTooHigh(); // 0x552b8377
    error creditLineOutstanding(); // 0x2901939a

    // pool operation
    error exceededPoolLiquidityCap(); // 0x5642ebd4
    error receivableAssetMismatch(); // 0x41dbeec1
    error unsupportedReceivableAsset(); // 0xe60c383e
    error receivableAssetParamMismatch(); // 0x1400a0b4
    error insufficientReceivableAmount(); // 0xf7f34854
    error borrowingAmountLessThanPlatformFees(); // 0x97fde118
    error withdrawTooSoon(); // 0x67982472
    error paymentAlreadyProcessed(); // 0xfd6754cf

    error defaultTriggeredTooEarly(); // 0x7872424e
    error defaultHasAlreadyBeenTriggered(); // 0xeb8d2ccc
}

contract BasePoolStorage {
    uint256 internal constant HUNDRED_PERCENT_IN_BPS = 10000;
    uint256 internal constant SECONDS_IN_A_DAY = 1 days;
    /// A multiplier over the credit limit, which is up to 80% of the invoice amount,
    /// that determines whether a payment amount should be flagged for review.
    /// It is possible for the actual invoice payment is higher than the invoice amount,
    /// however, it is too high, the chance for a fraud is high and thus requires review.
    uint256 internal constant REVIEW_MULTIPLIER = 5;

    enum PoolStatus {
        Off,
        On
    }

    // The ERC20 token this pool manages
    IERC20 internal _underlyingToken;

    // The HDT token for this pool
    IHDT internal _poolToken;

    IBasePoolConfig internal _poolConfig;

    // Reference to HumaConfig. Removed immutable since Solidity disallow reference it in the constructor,
    // but we need to retrieve the poolDefaultGracePeriod in the constructor.
    IHumaConfig internal _humaConfig;

    // Reference to the fee manager contract
    IFeeManager internal _feeManager;

    // The amount of underlying token belongs to lenders
    uint256 internal _totalPoolValue;

    // Tracks the last deposit time for each lender in this pool
    mapping(address => uint256) internal _lastDepositTime;

    // Whether the pool is ON or OFF
    PoolStatus internal _status;

    // The addresses that are allowed to lend to this pool. Configurable only by the pool owner
    mapping(address => bool) internal _approvedLenders;

    uint256[100] private __gap;
}

// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

abstract contract BasePool is Initializable, BasePoolStorage {
    using SafeERC20 for IERC20;

    event LiquidityDeposited(address indexed account, uint256 assetAmount, uint256 shareAmount);
    event LiquidityWithdrawn(address indexed account, uint256 assetAmount, uint256 shareAmount);

    event PoolConfigChanged(address indexed sender, address newPoolConfig);
    event PoolCoreDataChanged(
        address indexed sender,
        address underlyingToken,
        address poolToken,
        address humaConfig,
        address feeManager
    );

    event PoolDisabled(address indexed by);
    event PoolEnabled(address indexed by);

    event AddApprovedLender(address indexed lender, address by);
    event RemoveApprovedLender(address indexed lender, address by);

    event LossesDistributed(uint256 lossesDistributed, uint256 updatedPoolValue);

    constructor() {
        _disableInitializers();
    }

    function initialize(address poolConfigAddr) external initializer {
        _poolConfig = IBasePoolConfig(poolConfigAddr);
        _updateCoreData();

        // note approve max amount to pool config for admins to withdraw their rewards
        _safeApproveForPoolConfig(type(uint256).max);

        // All pools are off when initiated, will turn on after admins' initial deposits
        _status = PoolStatus.Off;
    }

    //********************************************/
    //               LP Functions                //
    //********************************************/

    function distributeIncome(uint256 value) internal virtual {
        uint256 poolIncome = _poolConfig.distributeIncome(value);
        _totalPoolValue += poolIncome;
    }

    function reverseIncome(uint256 value) internal virtual {
        uint256 poolIncome = _poolConfig.reverseIncome(value);
        if (_totalPoolValue > poolIncome) _totalPoolValue -= poolIncome;
        else _totalPoolValue = 0;
    }

    //********************************************/
    //            Admin Functions                //
    //********************************************/

    function getCoreData()
        external
        view
        returns (
            address underlyingToken_,
            address poolToken_,
            address humaConfig_,
            address feeManager_
        )
    {
        underlyingToken_ = address(_underlyingToken);
        poolToken_ = address(_poolToken);
        humaConfig_ = address(_humaConfig);
        feeManager_ = address(_feeManager);
    }

    /// Reports if the given account has been approved as a lender for this pool

    /// Gets the on/off status of the pool

    /// Gets the last deposit time of the given lender

    /// Gets the address of poolConfig

    /// Gets the total value of the pool, measured by the units of underlying token

    function _safeApproveForPoolConfig(uint256 amount) internal {
        address config = address(_poolConfig);
        uint256 allowance = _underlyingToken.allowance(address(this), config);

        // Call safeApprove when the allowance is changed from >0 to 0, or from 0 to >0.
        if ((amount == 0 && allowance > 0) || (amount > 0 && allowance == 0)) {
            _underlyingToken.safeApprove(config, amount);
        }
    }

    /// Refreshes the cache of addresses for key contracts using the current data in PoolConfig
    function _updateCoreData() private {
        (
            address underlyingTokenAddr,
            address poolTokenAddr,
            address humaConfigAddr,
            address feeManagerAddr
        ) = _poolConfig.getCoreData();
        _underlyingToken = IERC20(underlyingTokenAddr);
        _poolToken = IHDT(poolTokenAddr);
        _humaConfig = IHumaConfig(humaConfigAddr);
        _feeManager = IFeeManager(feeManagerAddr);

        emit PoolCoreDataChanged(
            msg.sender,
            underlyingTokenAddr,
            poolTokenAddr,
            humaConfigAddr,
            feeManagerAddr
        );
    }

    /// "Modifier" function that limits access only when both protocol and pool are on.
    /// Did not use modifier for contract size consideration.
    function _protocolAndPoolOn() internal view {
        if (_humaConfig.paused()) revert Errors.protocolIsPaused();
        if (_status != PoolStatus.On) revert Errors.poolIsNotOn();
    }

    /// "Modifier" function that limits access to approved lenders only.

    /// "Modifier" function that limits access to pool owner or protocol owner

    /// "Modifier" function that limits access to pool operators only
}

contract BaseCreditPoolStorage {
    /// mapping from wallet address to the credit record
    mapping(address => BaseStructs.CreditRecord) internal _creditRecordMapping;
    mapping(address => BaseStructs.CreditRecordStatic) internal _creditRecordStaticMapping;

    uint256[100] private __gap;
}

contract BaseCreditPool is BasePool, BaseCreditPoolStorage, ICredit {
    using SafeERC20 for IERC20;
    
    enum CreditLineClosureReason {
        OverwrittenByNewLine
    }

    /// Account billing info refreshed with the updated due amount and date
    event BillRefreshed(address indexed borrower, uint256 newDueDate, address by);

    event CreditInitiated(
        address indexed borrower,
        uint256 creditLimit,
        uint256 aprInBps,
        uint256 payPeriodInDays,
        uint256 remainingPeriods,
        bool approved
    );

    event CreditLineClosed(
        address indexed borrower,
        address by,
        CreditLineClosureReason reasonCode
    );

    event DrawdownMade(
        address indexed borrower,
        uint256 borrowAmount,
        uint256 netAmountToBorrower
    );

    function drawdown(uint256 borrowAmount) external virtual override {
        address borrower = msg.sender;
        // Open access to the borrower
        if (borrowAmount == 0) revert Errors.zeroAmountProvided();
        BaseStructs.CreditRecord memory cr = _getCreditRecord(borrower);

        _checkDrawdownEligibility(borrower, cr, borrowAmount);
        uint256 netAmountToBorrower = _drawdown(borrower, cr, borrowAmount);
        emit DrawdownMade(borrower, borrowAmount, netAmountToBorrower);
    }

    function refreshAccount(address borrower)
        external
        virtual
        override
        returns (BaseStructs.CreditRecord memory cr)
    {
        if (_creditRecordMapping[borrower].state != BaseStructs.CreditState.Defaulted) {
            if (isDefaultReady(borrower)) return _updateDueInfo(borrower, false, false);
            else return _updateDueInfo(borrower, false, true);
        }
    }

    function requestCredit(
        uint256 creditLimit,
        uint256 intervalInDays,
        uint256 numOfPayments
    ) external virtual override {
        // Open access to the borrower. Data validation happens in _initiateCredit()
        _initiateCredit(
            msg.sender,
            creditLimit,
            _poolConfig.poolAprInBps(),
            intervalInDays,
            numOfPayments
        );
    }

    function isDefaultReady(address borrower) internal view returns (bool) {
        uint16 intervalInDays = _creditRecordStaticMapping[borrower].intervalInDays;
        return
            _creditRecordMapping[borrower].missedPeriods * intervalInDays * SECONDS_IN_A_DAY >
                _poolConfig.poolDefaultGracePeriodInSeconds()
                ? true
                : false;
    }

    function _checkDrawdownEligibility(
        address borrower,
        BaseStructs.CreditRecord memory cr,
        uint256 borrowAmount
    ) internal view {
        _protocolAndPoolOn();

        if (cr.state != BaseStructs.CreditState.GoodStanding && cr.state != BaseStructs.CreditState.Approved)
            revert Errors.creditLineNotInStateForDrawdown();
        else if (cr.state == BaseStructs.CreditState.Approved) {
            // After the credit approval, if the pool has credit expiration for the 1st drawdown,
            // the borrower must complete the first drawdown before the expiration date, which
            // is set in cr.dueDate in approveCredit().
            // note For pools without credit expiration for first drawdown, cr.dueDate is 0
            // before the first drawdown, thus the cr.dueDate > 0 condition in the check
            if (cr.dueDate > 0 && block.timestamp > cr.dueDate)
                revert Errors.creditExpiredDueToFirstDrawdownTooLate();

            if (borrowAmount > _creditRecordStaticMapping[borrower].creditLimit)
                revert Errors.creditLineExceeded();
        }
    }

    function _drawdown(
        address borrower,
        BaseStructs.CreditRecord memory cr,
        uint256 borrowAmount
    ) internal virtual returns (uint256) {
        if (cr.state == BaseStructs.CreditState.Approved) {
            // Flow for first drawdown
            // Update total principal
            _creditRecordMapping[borrower].unbilledPrincipal = uint96(borrowAmount);

            // Generates the first bill
            // Note: the interest is calculated at the beginning of each pay period
            cr = _updateDueInfo(borrower, true, true);

            // Set account status in good standing
            cr.state = BaseStructs.CreditState.GoodStanding;
        } else {
            // Return drawdown flow
            // Bring the account current.
            if (block.timestamp > cr.dueDate) {
                cr = _updateDueInfo(borrower, false, true);
                if (cr.state != BaseStructs.CreditState.GoodStanding)
                    revert Errors.creditLineNotInGoodStandingState();
            }

            if (
                borrowAmount >
                (_creditRecordStaticMapping[borrower].creditLimit -
                    cr.unbilledPrincipal -
                    (cr.totalDue - cr.feesAndInterestDue))
            ) revert Errors.creditLineExceeded();

            // note Drawdown is not allowed in the final pay period since the payment due for
            // such drawdown will fall outside of the window of the credit line.
            // note since we bill at the beginning of a period, cr.remainingPeriods is zero
            // in the final period.
            if (cr.remainingPeriods == 0) revert Errors.creditExpiredDueToMaturity();

            // For non-first bill, we do not update the current bill, the interest for the rest of
            // this pay period is accrued in correction and will be added to the next bill.
            cr.correction += int96(
                uint96(
                    _calcCorrection(
                        cr.dueDate,
                        _creditRecordStaticMapping[borrower].aprInBps,
                        borrowAmount
                    )
                )
            );

            cr.unbilledPrincipal = uint96(cr.unbilledPrincipal + borrowAmount);
        }

        _setCreditRecord(borrower, cr);

        (uint256 netAmountToBorrower, uint256 platformFees) = _feeManager.distBorrowingAmount(
            borrowAmount
        );

        if (platformFees > 0) distributeIncome(platformFees);

        // Transfer funds to the _borrower
        _underlyingToken.safeTransfer(borrower, netAmountToBorrower);

        return netAmountToBorrower;
    }

    function _initiateCredit(
        address borrower,
        uint256 creditLimit,
        uint256 aprInBps,
        uint256 intervalInDays,
        uint256 remainingPeriods
    ) internal virtual {
        if (remainingPeriods == 0) revert Errors.requestedCreditWithZeroDuration();

        _protocolAndPoolOn();
        // Borrowers cannot have two credit lines in one pool. They can request to increase line.
        BaseStructs.CreditRecord memory cr = _getCreditRecord(borrower);

        if (cr.state != BaseStructs.CreditState.Deleted) {
            // If the user has an existing line, but there is no balance, close the old one
            // and initiate the new one automatically.
            cr = _updateDueInfo(borrower, false, true);
            if (cr.totalDue == 0 && cr.unbilledPrincipal == 0) {
                cr.state = BaseStructs.CreditState.Deleted;
                cr.remainingPeriods = 0;
                emit CreditLineClosed(
                    borrower,
                    msg.sender,
                    CreditLineClosureReason.OverwrittenByNewLine
                );
            } else {
                revert Errors.creditLineAlreadyExists();
            }
        }

        // Borrowing amount needs to be lower than max for the pool.
        _maxCreditLineCheck(creditLimit);

        _creditRecordStaticMapping[borrower] = BaseStructs.CreditRecordStatic({
            creditLimit: uint96(creditLimit),
            aprInBps: uint16(aprInBps),
            intervalInDays: uint16(intervalInDays),
            defaultAmount: uint96(0)
        });

        BaseStructs.CreditRecord memory ncr;
        ncr.remainingPeriods = uint16(remainingPeriods);
        ncr.state = BaseStructs.CreditState.Requested;

        _setCreditRecord(borrower, ncr);

        emit CreditInitiated(
            borrower,
            creditLimit,
            aprInBps,
            intervalInDays,
            remainingPeriods,
            false
        );
    }

    /// Checks if the given amount is higher than what is allowed by the pool
    function _maxCreditLineCheck(uint256 amount) internal view {
        if (amount > _poolConfig.maxCreditLine()) {
            revert Errors.greaterThanMaxCreditLine();
        }
    }

    function _updateDueInfo(
        address borrower,
        bool isFirstDrawdown,
        bool distributeChargesForLastCycle
    ) internal virtual returns (BaseStructs.CreditRecord memory cr) {
        cr = _getCreditRecord(borrower);
        if (isFirstDrawdown) cr.dueDate = 0;
        bool alreadyLate = cr.totalDue > 0 ? true : false;

        // Gets the up-to-date due information for the borrower. If the account has been
        // late or dormant for multiple cycles, getDueInfo() will bring it current and
        // return the most up-to-date due information.
        uint256 periodsPassed = 0;
        int96 newCharges;
        (
            periodsPassed,
            cr.feesAndInterestDue,
            cr.totalDue,
            cr.unbilledPrincipal,
            newCharges
        ) = _feeManager.getDueInfo(cr, _getCreditRecordStatic(borrower));

        if (periodsPassed > 0) {
            cr.correction = 0;
            // Distribute income
            if (cr.state != BaseStructs.CreditState.Defaulted) {
                if (!distributeChargesForLastCycle)
                    newCharges = newCharges - int96(cr.feesAndInterestDue);

                if (newCharges > 0) distributeIncome(uint256(uint96(newCharges)));
                else if (newCharges < 0) reverseIncome(uint256(uint96(0 - newCharges)));
            }

            uint16 intervalInDays = _creditRecordStaticMapping[borrower].intervalInDays;
            if (cr.dueDate > 0)
                cr.dueDate = uint64(
                    cr.dueDate + periodsPassed * intervalInDays * SECONDS_IN_A_DAY
                );
            else cr.dueDate = uint64(block.timestamp + intervalInDays * SECONDS_IN_A_DAY);

            // Adjusts remainingPeriods, special handling when reached the maturity of the credit line
            if (cr.remainingPeriods > periodsPassed) {
                cr.remainingPeriods = uint16(cr.remainingPeriods - periodsPassed);
            } else {
                cr.remainingPeriods = 0;
            }

            // Sets the right missedPeriods and state for the credit record
            if (alreadyLate) cr.missedPeriods = uint16(cr.missedPeriods + periodsPassed);
            else cr.missedPeriods = 0;

            if (cr.missedPeriods > 0) {
                if (cr.state != BaseStructs.CreditState.Defaulted) cr.state = BaseStructs.CreditState.Delayed;
            } else cr.state = BaseStructs.CreditState.GoodStanding;

            _setCreditRecord(borrower, cr);

            emit BillRefreshed(borrower, cr.dueDate, msg.sender);
        }
    }

    /// Shared setter to the credit record mapping for contract size consideration
    function _setCreditRecord(address borrower, BaseStructs.CreditRecord memory cr) internal {
        _creditRecordMapping[borrower] = cr;
    }

    /// Shared accessor for contract size consideration
    function _calcCorrection(
        uint256 dueDate,
        uint256 aprInBps,
        uint256 amount
    ) internal view returns (uint256) {
        return _feeManager.calcCorrection(dueDate, aprInBps, amount);
    }

    /// Shared accessor to the credit record mapping for contract size consideration
    function _getCreditRecord(address account) internal view returns (BaseStructs.CreditRecord memory) {
        return _creditRecordMapping[account];
    }

    /// Shared accessor to the credit record static mapping for contract size consideration
    function _getCreditRecordStatic(address account)
        internal
        view
        returns (BaseStructs.CreditRecordStatic memory)
    {
        return _creditRecordStaticMapping[account];
    }
}

