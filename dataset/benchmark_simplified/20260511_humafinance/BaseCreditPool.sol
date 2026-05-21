// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;



// Minimal OpenZeppelin (from @openzeppelin/)

// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)


/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
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

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
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

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
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



/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
     * constructor.
     *
     * Emits an {Initialized} event.
     */
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

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: setting the version to 255 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}

// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)


/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

library Address {
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");
        (bool success, bytes memory returndata) = target.call(data);
        if (success) return returndata;
        if (returndata.length > 0) {
            assembly {
                revert(add(32, returndata), mload(returndata))
            }
        }
        revert(errorMessage);
    }
}

library SafeERC20 {
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// Errors used by credit flow

contract Errors {
    error zeroAmountProvided();
    error protocolIsPaused();
    error poolIsNotOn();
    error evaluationAgentServiceAccountRequired();
    error creditLineOutstanding();
    error creditLineNotInStateForDrawdown();
    error creditExpiredDueToFirstDrawdownTooLate();
    error creditLineExceeded();
    error creditLineNotInGoodStandingState();
    error creditExpiredDueToMaturity();
    error requestedCreditWithZeroDuration();
    error creditLineAlreadyExists();
    error greaterThanMaxCreditLine();
    error notPool();
}



library BaseStructs {
    /**
     * @notice CreditRecord stores the overall info and status about a credit.
     * @dev amounts are stored in uint96, all counts are stored in uint16
     * @dev each struct can have no more than 13 elements.
     */
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

    /**
     * @notice ReceivableInfo stores receivable used for credits.
     * @dev receivableParam is used to store info such as NFT tokenId
     */
    struct ReceivableInfo {
        address receivableAsset;
        uint96 receivableAmount;
        uint256 receivableParam;
    }

    struct FlagedPaymentRecord {
        address paymentReceiver;
        uint256 amount;
    }

    enum CreditState {
        Deleted,
        Requested,
        Approved,
        GoodStanding,
        Delayed,
        Defaulted
    }
    enum PaymentStatus {
        NotReceived,
        ReceivedNotVerified,
        ReceivedAndVerified
    }
}



interface IFeeManager {
    function calcCorrection(uint256 dueDate, uint256 aprInBps, uint256 amount)
        external view returns (uint256 correction);
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
    function distBorrowingAmount(uint256 borrowAmount)
        external
        view
        returns (uint256 amtToBorrower, uint256 platformFees);
}

interface IHumaConfig {
    function paused() external view returns (bool);
    function eaServiceAccount() external view returns (address);
    function protocolFee() external view returns (uint16);
}



interface IBasePoolConfig {
    function distributeIncome(uint256 value) external returns (uint256 poolIncome);

    function reverseIncome(uint256 value) external returns (uint256 poolIncome);

    function maxCreditLine() external view returns (uint256);

    function poolAprInBps() external view returns (uint256);

    function creditApprovalExpirationInSeconds() external view returns (uint256);

    function getCoreData()
        external
        view
        returns (
            address underlyingToken_,
            address poolToken_,
            address humaConfig_,
            address feeManager_
        );
}


contract BasePoolStorage {
    uint256 internal constant SECONDS_IN_A_DAY = 1 days;

    enum PoolStatus {
        Off,
        On
    }

    IERC20 internal _underlyingToken;
    IBasePoolConfig internal _poolConfig;
    IHumaConfig internal _humaConfig;
    IFeeManager internal _feeManager;
    uint256 internal _totalPoolValue;
    PoolStatus internal _status;
    uint256[100] private __gap;
}



abstract contract BasePool is Initializable, BasePoolStorage {
    using SafeERC20 for IERC20;

    constructor() {
        _disableInitializers();
    }

    function initialize(address poolConfigAddr) external initializer {
        _poolConfig = IBasePoolConfig(poolConfigAddr);
        _updateCoreData();
        _status = PoolStatus.Off;
    }

    /// Required before requestCredit / drawdown (_protocolAndPoolOn).
    function enablePool() external {
        _status = PoolStatus.On;
    }

    function distributeIncome(uint256 value) internal virtual {
        uint256 poolIncome = _poolConfig.distributeIncome(value);
        _totalPoolValue += poolIncome;
    }

    function reverseIncome(uint256 value) internal virtual {
        uint256 poolIncome = _poolConfig.reverseIncome(value);
        if (_totalPoolValue > poolIncome) _totalPoolValue -= poolIncome;
        else _totalPoolValue = 0;
    }

    function _updateCoreData() private {
        (
            address underlyingTokenAddr,
            ,
            address humaConfigAddr,
            address feeManagerAddr
        ) = _poolConfig.getCoreData();
        _underlyingToken = IERC20(underlyingTokenAddr);
        _humaConfig = IHumaConfig(humaConfigAddr);
        _feeManager = IFeeManager(feeManagerAddr);
    }

    function _protocolAndPoolOn() internal view {
        if (_humaConfig.paused()) revert Errors.protocolIsPaused();
        if (_status != PoolStatus.On) revert Errors.poolIsNotOn();
    }
}



contract BaseCreditPoolStorage {
    mapping(address => BaseStructs.CreditRecord) internal _creditRecordMapping;
    mapping(address => BaseStructs.CreditRecordStatic) internal _creditRecordStaticMapping;
    uint256[100] private __gap;
}

contract BaseCreditPool is BasePool, BaseCreditPoolStorage {
    using SafeERC20 for IERC20;

    enum CreditLineClosureReason {
        Paidoff,
        CreditLimitChangedToBeZero,
        OverwrittenByNewLine
    }

    event BillRefreshed(address indexed borrower, uint256 newDueDate, address by);
    event CreditApproved(
        address indexed borrower,
        uint256 creditLimit,
        uint256 intervalInDays,
        uint256 remainingPeriods,
        uint256 aprInBps
    );
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

    function approveCredit(
        address borrower,
        uint256 creditLimit,
        uint256 intervalInDays,
        uint256 remainingPeriods,
        uint256 aprInBps
    ) public {
        _protocolAndPoolOn();
        onlyEAServiceAccount();
        _maxCreditLineCheck(creditLimit);
        BaseStructs.CreditRecordStatic memory crs = _getCreditRecordStatic(borrower);
        crs.creditLimit = uint96(creditLimit);
        crs.aprInBps = uint16(aprInBps);
        crs.intervalInDays = uint16(intervalInDays);
        _creditRecordStaticMapping[borrower] = crs;

        BaseStructs.CreditRecord memory cr = _getCreditRecord(borrower);
        cr.remainingPeriods = uint16(remainingPeriods);
        _setCreditRecord(borrower, _approveCredit(cr));

        emit CreditApproved(borrower, creditLimit, intervalInDays, remainingPeriods, aprInBps);
    }

    function drawdown(uint256 borrowAmount) external {
        address borrower = msg.sender;
        if (borrowAmount == 0) revert Errors.zeroAmountProvided();
        BaseStructs.CreditRecord memory cr = _getCreditRecord(borrower);

        _checkDrawdownEligibility(borrower, cr, borrowAmount);
        uint256 netAmountToBorrower = _drawdown(borrower, cr, borrowAmount);
        emit DrawdownMade(borrower, borrowAmount, netAmountToBorrower);
    }

    function requestCredit(
        uint256 creditLimit,
        uint256 intervalInDays,
        uint256 numOfPayments
    ) external {
        _initiateCredit(
            msg.sender,
            creditLimit,
            _poolConfig.poolAprInBps(),
            intervalInDays,
            numOfPayments,
            false
        );
    }

    function _approveCredit(BaseStructs.CreditRecord memory cr)
        internal
        view
        returns (BaseStructs.CreditRecord memory)
    {
        if (cr.state > BaseStructs.CreditState.Approved) revert Errors.creditLineOutstanding();

        uint256 validPeriod = _poolConfig.creditApprovalExpirationInSeconds();
        if (validPeriod > 0) cr.dueDate = uint64(block.timestamp + validPeriod);

        cr.state = BaseStructs.CreditState.Approved;
        return cr;
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
    ) internal returns (uint256) {
        if (cr.state == BaseStructs.CreditState.Approved) {
            _creditRecordMapping[borrower].unbilledPrincipal = uint96(borrowAmount);
            cr = _updateDueInfo(borrower, true, true);
            cr.state = BaseStructs.CreditState.GoodStanding;
        } else {
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

            if (cr.remainingPeriods == 0) revert Errors.creditExpiredDueToMaturity();

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

        _underlyingToken.safeTransfer(borrower, netAmountToBorrower);

        return netAmountToBorrower;
    }

    function _initiateCredit(
        address borrower,
        uint256 creditLimit,
        uint256 aprInBps,
        uint256 intervalInDays,
        uint256 remainingPeriods,
        bool preApproved
    ) internal {
        if (remainingPeriods == 0) revert Errors.requestedCreditWithZeroDuration();

        _protocolAndPoolOn();
        BaseStructs.CreditRecord memory cr = _getCreditRecord(borrower);

        if (cr.state != BaseStructs.CreditState.Deleted) {
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

        _maxCreditLineCheck(creditLimit);

        _creditRecordStaticMapping[borrower] = BaseStructs.CreditRecordStatic({
            creditLimit: uint96(creditLimit),
            aprInBps: uint16(aprInBps),
            intervalInDays: uint16(intervalInDays),
            defaultAmount: uint96(0)
        });

        BaseStructs.CreditRecord memory ncr;
        ncr.remainingPeriods = uint16(remainingPeriods);

        if (preApproved) {
            ncr = _approveCredit(ncr);
            emit CreditApproved(borrower, creditLimit, intervalInDays, remainingPeriods, aprInBps);
        } else ncr.state = BaseStructs.CreditState.Requested;

        _setCreditRecord(borrower, ncr);

        emit CreditInitiated(
            borrower,
            creditLimit,
            aprInBps,
            intervalInDays,
            remainingPeriods,
            preApproved
        );
    }

    function _maxCreditLineCheck(uint256 amount) internal view {
        if (amount > _poolConfig.maxCreditLine()) {
            revert Errors.greaterThanMaxCreditLine();
        }
    }

    function _updateDueInfo(
        address borrower,
        bool isFirstDrawdown,
        bool distributeChargesForLastCycle
    ) internal returns (BaseStructs.CreditRecord memory cr) {
        cr = _getCreditRecord(borrower);
        if (isFirstDrawdown) cr.dueDate = 0;
        bool alreadyLate = cr.totalDue > 0;

        uint256 periodsPassed;
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

            if (cr.remainingPeriods > periodsPassed) {
                cr.remainingPeriods = uint16(cr.remainingPeriods - periodsPassed);
            } else {
                cr.remainingPeriods = 0;
            }

            if (alreadyLate) cr.missedPeriods = uint16(cr.missedPeriods + periodsPassed);
            else cr.missedPeriods = 0;

            if (cr.missedPeriods > 0) {
                if (cr.state != BaseStructs.CreditState.Defaulted) cr.state = BaseStructs.CreditState.Delayed;
            } else cr.state = BaseStructs.CreditState.GoodStanding;

            _setCreditRecord(borrower, cr);

            emit BillRefreshed(borrower, cr.dueDate, msg.sender);
        }
    }

    function _setCreditRecord(address borrower, BaseStructs.CreditRecord memory cr) internal {
        _creditRecordMapping[borrower] = cr;
    }

    function _calcCorrection(
        uint256 dueDate,
        uint256 aprInBps,
        uint256 amount
    ) internal view returns (uint256) {
        return _feeManager.calcCorrection(dueDate, aprInBps, amount);
    }

    function _getCreditRecord(address account) internal view returns (BaseStructs.CreditRecord memory) {
        return _creditRecordMapping[account];
    }

    function _getCreditRecordStatic(address account)
        internal
        view
        returns (BaseStructs.CreditRecordStatic memory)
    {
        return _creditRecordStaticMapping[account];
    }

    function onlyEAServiceAccount() internal view {
        if (msg.sender != _humaConfig.eaServiceAccount())
            revert Errors.evaluationAgentServiceAccountRequired();
    }
}
