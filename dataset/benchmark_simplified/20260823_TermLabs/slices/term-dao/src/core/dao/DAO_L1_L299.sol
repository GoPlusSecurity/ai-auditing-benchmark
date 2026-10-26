// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165StorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";

import {IProtocolVersion} from "../../utils/protocol/IProtocolVersion.sol";
import {ProtocolVersion} from "../../utils/protocol/ProtocolVersion.sol";
import {PermissionManager} from "../permission/PermissionManager.sol";
import {CallbackHandler} from "../utils/CallbackHandler.sol";
import {hasBit, flipBit} from "../utils/BitMap.sol";
import {IEIP4824} from "./IEIP4824.sol";
import {IDAO} from "./IDAO.sol";

/// @title DAO
/// @author Aragon Association - 2021-2023
/// @notice This contract is the entry point to the Aragon DAO framework and provides our users a simple and easy to use public interface.
/// @dev Public API of the Aragon DAO framework.
contract DAO is
    IEIP4824,
    Initializable,
    IERC1271,
    ERC165StorageUpgradeable,
    IDAO,
    UUPSUpgradeable,
    ProtocolVersion,
    PermissionManager,
    CallbackHandler
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;

    /// @notice The ID of the permission required to call the `execute` function.
    bytes32 public constant EXECUTE_PERMISSION_ID = keccak256("EXECUTE_PERMISSION");

    /// @notice The ID of the permission required to call the `_authorizeUpgrade` function.
    bytes32 public constant UPGRADE_DAO_PERMISSION_ID = keccak256("UPGRADE_DAO_PERMISSION");

    /// @notice The ID of the permission required to call the `setMetadata` function.
    bytes32 public constant SET_METADATA_PERMISSION_ID = keccak256("SET_METADATA_PERMISSION");

    /// @notice The ID of the permission required to call the `setTrustedForwarder` function.
    bytes32 public constant SET_TRUSTED_FORWARDER_PERMISSION_ID =
        keccak256("SET_TRUSTED_FORWARDER_PERMISSION");

    /// @notice The ID of the permission required to call the `setSignatureValidator` function.
    bytes32 public constant SET_SIGNATURE_VALIDATOR_PERMISSION_ID =
        keccak256("SET_SIGNATURE_VALIDATOR_PERMISSION");

    /// @notice The ID of the permission required to call the `registerStandardCallback` function.
    bytes32 public constant REGISTER_STANDARD_CALLBACK_PERMISSION_ID =
        keccak256("REGISTER_STANDARD_CALLBACK_PERMISSION");

    /// @notice The internal constant storing the maximal action array length.
    uint256 internal constant MAX_ACTIONS = 256;

    /// @notice The first out of two values to which the `_reentrancyStatus` state variable (used by the `nonReentrant` modifier) can be set inidicating that a function was not entered.
    uint256 private constant _NOT_ENTERED = 1;

    /// @notice The second out of two values to which the `_reentrancyStatus` state variable (used by the `nonReentrant` modifier) can be set inidicating that a function was entered.
    uint256 private constant _ENTERED = 2;

    /// @notice The [ERC-1271](https://eips.ethereum.org/EIPS/eip-1271) signature validator contract.
    /// @dev Added in v1.0.0.
    IERC1271 public signatureValidator;

    /// @notice The address of the trusted forwarder verifying meta transactions.
    /// @dev Added in v1.0.0.
    address private trustedForwarder;

    /// @notice The [EIP-4824](https://eips.ethereum.org/EIPS/eip-4824) DAO URI.
    /// @dev Added in v1.0.0.
    string private _daoURI;

    /// @notice The state variable for the reentrancy guard of the `execute` function.
    /// @dev Added in v1.3.0. The variable can be of value `_NOT_ENTERED = 1` or `_ENTERED = 2` in usage and is initialized with `_NOT_ENTERED`.
    uint256 private _reentrancyStatus;

    /// @notice Thrown if a call is reentrant.
    error ReentrantCall();

    /// @notice Thrown if the action array length is larger than `MAX_ACTIONS`.
    error TooManyActions();

    /// @notice Thrown if action execution has failed.
    /// @param index The index of the action in the action array that failed.
    error ActionFailed(uint256 index);

    /// @notice Thrown if an action has insufficent gas left.
    error InsufficientGas();

    /// @notice Thrown if the deposit amount is zero.
    error ZeroAmount();

    /// @notice Thrown if there is a mismatch between the expected and actually deposited amount of native tokens.
    /// @param expected The expected native token amount.
    /// @param actual The actual native token amount deposited.
    error NativeTokenDepositAmountMismatch(uint256 expected, uint256 actual);

    /// @notice Thrown if an upgrade is not supported from a specific protocol version .
    error ProtocolVersionUpgradeNotSupported(uint8[3] protocolVersion);

    /// @notice Emitted when a new DAO URI is set.
    /// @param daoURI The new URI.
    event NewURI(string daoURI);

    /// @notice A modifier to protect a function from calling itself, directly or indirectly (reentrancy).
    /// @dev Currently, this modifier is only applied to the `execute()` function. If this is used multiple times, private `_beforeNonReentrant()` and `_afterNonReentrant()` functions should be created to prevent code duplication.
    modifier nonReentrant() {
        if (_reentrancyStatus == _ENTERED) {
            revert ReentrantCall();
        }
        _reentrancyStatus = _ENTERED;

        _;

        _reentrancyStatus = _NOT_ENTERED;
    }

    /// @notice Disables the initializers on the implementation contract to prevent it from being left uninitialized.
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the DAO by
    /// - setting the reentrancy status variable to `_NOT_ENTERED`
    /// - registering the [ERC-165](https://eips.ethereum.org/EIPS/eip-165) interface ID
    /// - setting the trusted forwarder for meta transactions
    /// - giving the `ROOT_PERMISSION_ID` permission to the initial owner (that should be revoked and transferred to the DAO after setup).
    /// @dev This method is required to support [ERC-1822](https://eips.ethereum.org/EIPS/eip-1822).
    /// @param _metadata IPFS hash that points to all the metadata (logo, description, tags, etc.) of a DAO.
    /// @param _initialOwner The initial owner of the DAO having the `ROOT_PERMISSION_ID` permission.
    /// @param _trustedForwarder The trusted forwarder responsible for verifying meta transactions.
    /// @param daoURI_ The DAO URI required to support [ERC-4824](https://eips.ethereum.org/EIPS/eip-4824).
    function initialize(
        bytes calldata _metadata,
        address _initialOwner,
        address _trustedForwarder,
        string calldata daoURI_
    ) external reinitializer(2) {
        _reentrancyStatus = _NOT_ENTERED; // added in v1.3.0

        _registerInterface(type(IDAO).interfaceId);
        _registerInterface(type(IERC1271).interfaceId);
        _registerInterface(type(IEIP4824).interfaceId);
        _registerInterface(type(IProtocolVersion).interfaceId); // added in v1.3.0
        _registerTokenInterfaces();

        _setMetadata(_metadata);
        _setTrustedForwarder(_trustedForwarder);
        _setDaoURI(daoURI_);
        __PermissionManager_init(_initialOwner);
    }

    /// @notice Initializes the DAO after an upgrade from a previous protocol version.
    /// @param _previousProtocolVersion The semantic protocol version number of the previous DAO implementation contract this upgrade is transitioning from.
    /// @param _initData The initialization data to be passed to via `upgradeToAndCall` (see [ERC-1967](https://docs.openzeppelin.com/contracts/4.x/api/proxy#ERC1967Upgrade)).
    function initializeFrom(
        uint8[3] calldata _previousProtocolVersion,
        bytes calldata _initData
    ) external reinitializer(2) {
        _initData; // Silences the unused function parameter warning.

        // Check that the contract is not upgrading from a different major release.
        if (_previousProtocolVersion[0] != 1) {
            revert ProtocolVersionUpgradeNotSupported(_previousProtocolVersion);
        }

        // Initialize `_reentrancyStatus` that was added in v1.3.0.
        // Register Interface `ProtocolVersion` that was added in v1.3.0.
        if (_previousProtocolVersion[1] <= 2) {
            _reentrancyStatus = _NOT_ENTERED;
            _registerInterface(type(IProtocolVersion).interfaceId);
        }
    }

    /// @inheritdoc PermissionManager
    function isPermissionRestrictedForAnyAddr(
        bytes32 _permissionId
    ) internal pure override returns (bool) {
        return
            _permissionId == EXECUTE_PERMISSION_ID ||
            _permissionId == UPGRADE_DAO_PERMISSION_ID ||
            _permissionId == SET_METADATA_PERMISSION_ID ||
            _permissionId == SET_TRUSTED_FORWARDER_PERMISSION_ID ||
            _permissionId == SET_SIGNATURE_VALIDATOR_PERMISSION_ID ||
            _permissionId == REGISTER_STANDARD_CALLBACK_PERMISSION_ID;
    }

    /// @notice Internal method authorizing the upgrade of the contract via the [upgradeability mechanism for UUPS proxies](https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable) (see [ERC-1822](https://eips.ethereum.org/EIPS/eip-1822)).
    /// @dev The caller must have the `UPGRADE_DAO_PERMISSION_ID` permission.
    function _authorizeUpgrade(address) internal virtual override auth(UPGRADE_DAO_PERMISSION_ID) {}

    /// @inheritdoc IDAO
    function setTrustedForwarder(
        address _newTrustedForwarder
    ) external override auth(SET_TRUSTED_FORWARDER_PERMISSION_ID) {
        _setTrustedForwarder(_newTrustedForwarder);
    }

    /// @inheritdoc IDAO
    function getTrustedForwarder() external view virtual override returns (address) {
        return trustedForwarder;
    }

    /// @inheritdoc IDAO
    function hasPermission(
        address _where,
        address _who,
        bytes32 _permissionId,
        bytes memory _data
    ) external view override returns (bool) {
        return isGranted(_where, _who, _permissionId, _data);
    }

    /// @inheritdoc IDAO
    function setMetadata(
        bytes calldata _metadata
    ) external override auth(SET_METADATA_PERMISSION_ID) {
        _setMetadata(_metadata);
    }

    /// @inheritdoc IDAO
    function execute(
        bytes32 _callId,
        Action[] calldata _actions,
        uint256 _allowFailureMap
    )
        external
        override
        nonReentrant
        auth(EXECUTE_PERMISSION_ID)
        returns (bytes[] memory execResults, uint256 failureMap)
    {
        // Check that the action array length is within bounds.
        if (_actions.length > MAX_ACTIONS) {
            revert TooManyActions();
        }

        execResults = new bytes[](_actions.length);

        uint256 gasBefore;
        uint256 gasAfter;

        for (uint256 i = 0; i < _actions.length; ) {
            gasBefore = gasleft();

            (bool success, bytes memory result) = _actions[i].to.call{value: _actions[i].value}(
                _actions[i].data
            );
            gasAfter = gasleft();

            // Check if failure is allowed
            if (!hasBit(_allowFailureMap, uint8(i))) {
                // Check if the call failed.
                if (!success) {
                    revert ActionFailed(i);
                }
            } else {
                // Check if the call failed.
                if (!success) {
                    // Make sure that the action call did not fail because 63/64 of `gasleft()` was insufficient to execute the external call `.to.call` (see [ERC-150](https://eips.ethereum.org/EIPS/eip-150)).
                    // In specific scenarios, i.e. proposal execution where the last action in the action array is allowed to fail, the account calling `execute` could force-fail this action by setting a gas limit
                    // where 63/64 is insufficient causing the `.to.call` to fail, but where the remaining 1/64 gas are sufficient to successfully finish the `execute` call.
                    if (gasAfter < gasBefore / 64) {
                        revert InsufficientGas();
                    }

                    // Store that this action failed.
                    failureMap = flipBit(failureMap, uint8(i));
                }
            }

            execResults[i] = result;

            unchecked {
                ++i;
            }
        }

        emit Executed({
            actor: msg.sender,
            callId: _callId,
            actions: _actions,
            allowFailureMap: _allowFailureMap,
            failureMap: failureMap,
            execResults: execResults
        });
    }

