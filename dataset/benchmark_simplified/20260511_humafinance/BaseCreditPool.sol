// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

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

// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)


/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/utils/SafeERC20.sol)



/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
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

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
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

// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)


/**
 * @dev Collection of functions related to the address type
 */
library Address {
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
        return functionCall(target, data, "Address: low-level call failed");
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
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
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
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
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

contract Errors {
    error zeroAmountProvided(); // 0x71799f2a
    error notPool(); // 0x26d29bbf
    error protocolIsPaused(); // 0x8f6fa2d4
    error poolIsNotOn(); // 0x69b355df
    error creditExpiredDueToFirstDrawdownTooLate(); // 0x9fac7390
    error creditExpiredDueToMaturity(); // 0xa52f3c3f
    error creditLineNotInGoodStandingState(); // 0x96e79474
    error creditLineNotInStateForDrawdown(); // 0x4ff95a6d
    error creditLineExceeded(); // 0xef7d66ff
    error borrowingAmountLessThanPlatformFees(); // 0x97fde118
}

library BaseStructs {
    struct CreditRecord {
        uint96 unbilledPrincipal;
        uint64 dueDate;
        int96 correction;
        uint96 totalDue;
        uint96 feesAndInterestDue;
        uint16 missedPeriods;
        uint16 remainingPeriods;
        CreditState state;
    }

    struct CreditRecordStatic {
        uint96 creditLimit;
        uint16 aprInBps;
        uint16 intervalInDays;
        uint96 defaultAmount;
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

interface IHDT {
    function withdrawableFundsOf(address owner) external view returns (uint256);
    function mintAmount(address account, uint256 amount) external returns (uint256 shares);
    function burnAmount(address account, uint256 amount) external returns (uint256 shares);
    function assetToken() external view returns (address);
}

/**
 * @notice Huma protocol global configuration deployed separately from the pool.
 * @dev Implementation: contracts/HumaConfig.sol
 */
interface IHumaConfig {
    function paused() external view returns (bool);
}

/**
 * @notice External fee manager contract deployed separately from the pool.
 * @dev Implementation: contracts/BaseFeeManager.sol
 */
interface IBaseFeeManager {
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
/**
 * @notice External pool configuration contract deployed separately from the pool.
 * @dev Implementation: contracts/BasePoolConfig.sol
 */
interface IBasePoolConfig {
    function distributeIncome(uint256 value) external returns (uint256 poolIncome);

    function reverseIncome(uint256 value) external returns (uint256 poolIncome);

    function poolDefaultGracePeriodInSeconds() external view returns (uint256);
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
    IBaseFeeManager internal _feeManager;

    // The amount of underlying token belongs to lenders
    uint256 internal _totalPoolValue;

    // Tracks the last deposit time for each lender in this pool
    mapping(address => uint256) internal _lastDepositTime;

    // Whether the pool is ON or OFF
    PoolStatus internal _status;

    // The addresses that are allowed to lend to this pool. Configurable only by the pool owner
    mapping(address => bool) internal _approvedLenders;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[100] private __gap;
}

abstract contract BasePool is BasePoolStorage {
    using SafeERC20 for IERC20;

    /// "Modifier" function that limits access only when both protocol and pool are on.
    /// Did not use modifier for contract size consideration.
    function _protocolAndPoolOn() internal view {
        if (_humaConfig.paused()) revert Errors.protocolIsPaused();
        if (_status != PoolStatus.On) revert Errors.poolIsNotOn();
    }


    /**
     * @notice Distributes income to token holders.
     */
    function distributeIncome(uint256 value) internal {
        uint256 poolIncome = _poolConfig.distributeIncome(value);
        _totalPoolValue += poolIncome;
    }


    /**
     * @notice Reverse income to token holders.
     * @param value the amount of income to be reverted
     * @dev this is needed when the user pays off early. We collect and distribute interest
     * at the beginning of the pay period. When the user pays off early, the interest
     * for the remainder of the period will be automatically subtraced from the payoff amount.
     * The portion of the income will be reversed. We can also change the parameter of
     * distributeIncome to int256. Choose to use a separate function for better readability.
     */
    function reverseIncome(uint256 value) internal {
        uint256 poolIncome = _poolConfig.reverseIncome(value);
        if (_totalPoolValue > poolIncome) _totalPoolValue -= poolIncome;
        else _totalPoolValue = 0;
    }
}

contract BaseCreditPoolStorage {
    /// mapping from wallet address to the credit record
    mapping(address => BaseStructs.CreditRecord) internal _creditRecordMapping;
    mapping(address => BaseStructs.CreditRecordStatic) internal _creditRecordStaticMapping;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[100] private __gap;
}

contract BaseCreditPool is BasePool, BaseCreditPoolStorage {
    using SafeERC20 for IERC20;

    event BillRefreshed(address indexed borrower, uint256 newDueDate, address by);
    event DrawdownMade(
        address indexed borrower,
        uint256 borrowAmount,
        uint256 netAmountToBorrower
    );

    /// Shared accessor for contract size consideration
    function _calcCorrection(
        uint256 dueDate,
        uint256 aprInBps,
        uint256 amount
    ) internal view returns (uint256) {
        return _feeManager.calcCorrection(dueDate, aprInBps, amount);
    }


    /**
     * @notice Checks if drawdown is allowed for the credit line at this point of time
     * @dev the requester can be the borrower or the EA
     * @dev requires the credit line to be in Approved (first drawdown) or
     * Good Standing (return drawdown) state.
     * @dev for first drawdown, after the credit line is approved, it needs to happen within
     * the expiration window configured by the pool
     * @dev the drawdown should not put the account over the approved credit limit
     * @dev Please note cr.dueDate is the credit expiration date for the first drawdown.
     */
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


    /**
     * @notice helper function for drawdown
     * @param borrower the borrower
     * @param borrowAmount the amount to borrow
     */
    function _drawdown(
        address borrower,
        BaseStructs.CreditRecord memory cr,
        uint256 borrowAmount
    ) internal returns (uint256) {
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


    /// Shared setter to the credit record mapping for contract size consideration
    function _setCreditRecord(address borrower, BaseStructs.CreditRecord memory cr) internal {
        _creditRecordMapping[borrower] = cr;
    }


    /**
     * @notice updates CreditRecord for `_borrower` using the most up to date information.
     * @dev this is used in both makePayment() and drawdown() to bring the account current
     * @dev getDueInfo() gets the due information of the most current cycle. This function
     * updates the record in creditRecordMapping for `_borrower`
     * @param borrower the address of the borrwoer
     * @param isFirstDrawdown whether this request is for the first drawdown of the credit line
     * @param distributeChargesForLastCycle whether to distribute income to different parties
     * (protocol, poolOwner, EA, and the pool). A `false` value is used in special cases
     * like `default` when we do not pause the accrue and distribution of fees.
     */
    function _updateDueInfo(
        address borrower,
        bool isFirstDrawdown,
        bool distributeChargesForLastCycle
    ) internal returns (BaseStructs.CreditRecord memory cr) {
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


    /**
     * @notice allows the borrower to borrow against an approved credit line.
     * The borrower can borrow and pay back as many times as they would like.
     * @param borrowAmount the amount to borrow
     */
    function drawdown(uint256 borrowAmount) external {
        address borrower = msg.sender;
        // Open access to the borrower
        if (borrowAmount == 0) revert Errors.zeroAmountProvided();
        BaseStructs.CreditRecord memory cr = _getCreditRecord(borrower);

        _checkDrawdownEligibility(borrower, cr, borrowAmount);
        uint256 netAmountToBorrower = _drawdown(borrower, cr, borrowAmount);
        emit DrawdownMade(borrower, borrowAmount, netAmountToBorrower);
    }


    /**
     * @notice checks if the credit line is ready to be triggered as defaulted
     */
    function isDefaultReady(address borrower) public view returns (bool) {
        uint16 intervalInDays = _creditRecordStaticMapping[borrower].intervalInDays;
        return
            _creditRecordMapping[borrower].missedPeriods * intervalInDays * SECONDS_IN_A_DAY >
                _poolConfig.poolDefaultGracePeriodInSeconds()
                ? true
                : false;
    }


    /**
     * @notice Updates the account and brings its billing status current
     * @dev If the account is defaulted, no need to update the account anymore.
     * @dev If the account is ready to be defaulted but not yet, update the account without
     * distributing the income for the upcoming period. Otherwise, update and distribute income
     * note the reason that we do not distribute income for the final cycle anymore since
     * it does not make sense to distribute income that we know cannot be collected to the
     * administrators (e.g. protocol, pool owner and EA) since it will only add more losses
     * to the LPs. Unfortunately, this special business consideration added more complexity
     * and cognitive load to _updateDueInfo(...).
     */
    function refreshAccount(address borrower)
        external
        returns (BaseStructs.CreditRecord memory cr)
    {
        if (_creditRecordMapping[borrower].state != BaseStructs.CreditState.Defaulted) {
            if (isDefaultReady(borrower)) return _updateDueInfo(borrower, false, false);
            else return _updateDueInfo(borrower, false, true);
        }
    }
}
