// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// ============ OpenZeppelin contracts (inlined from node_modules @openzeppelin/contracts + contracts-upgradeable v5.0.x) ============

// --- @openzeppelin/contracts/utils/introspection/IERC165.sol ---
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// --- @openzeppelin/contracts/access/IAccessControl.sol ---
interface IAccessControl {
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
    error AccessControlBadConfirmation();

    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address callerConfirmation) external;
}

// --- @openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol ---
abstract contract Initializable {
    struct InitializableStorage {
        uint64 _initialized;
        bool _initializing;
    }

    bytes32 private constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    error InvalidInitialization();
    error NotInitializing();

    event Initialized(uint64 version);

    modifier initializer() {
        InitializableStorage storage $ = _getInitializableStorage();
        bool isTopLevelCall = !$._initializing;
        uint64 initialized = $._initialized;
        bool initialSetup = initialized == 0 && isTopLevelCall;
        bool construction = initialized == 1 && address(this).code.length == 0;

        if (!initialSetup && !construction) {
            revert InvalidInitialization();
        }
        $._initialized = 1;
        if (isTopLevelCall) {
            $._initializing = true;
        }
        _;
        if (isTopLevelCall) {
            $._initializing = false;
            emit Initialized(1);
        }
    }

    modifier reinitializer(uint64 version) {
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing || $._initialized >= version) {
            revert InvalidInitialization();
        }
        $._initialized = version;
        $._initializing = true;
        _;
        $._initializing = false;
        emit Initialized(version);
    }

    modifier onlyInitializing() {
        _checkInitializing();
        _;
    }

    function _checkInitializing() internal view virtual {
        if (!_isInitializing()) {
            revert NotInitializing();
        }
    }

    function _disableInitializers() internal virtual {
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing) {
            revert InvalidInitialization();
        }
        if ($._initialized != type(uint64).max) {
            $._initialized = type(uint64).max;
            emit Initialized(type(uint64).max);
        }
    }

    function _getInitializedVersion() internal view returns (uint64) {
        return _getInitializableStorage()._initialized;
    }

    function _isInitializing() internal view returns (bool) {
        return _getInitializableStorage()._initializing;
    }

    function _getInitializableStorage() private pure returns (InitializableStorage storage $) {
        assembly {
            $.slot := INITIALIZABLE_STORAGE
        }
    }
}

// --- @openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol ---
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing { }

    function __Context_init_unchained() internal onlyInitializing { }

    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// --- @openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol ---
abstract contract ERC165Upgradeable is Initializable, IERC165 {
    function __ERC165_init() internal onlyInitializing { }

    function __ERC165_init_unchained() internal onlyInitializing { }

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// --- @openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol ---
abstract contract AccessControlUpgradeable is Initializable, ContextUpgradeable, IAccessControl, ERC165Upgradeable {
    struct RoleData {
        mapping(address account => bool) hasRole;
        bytes32 adminRole;
    }

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    struct AccessControlStorage {
        mapping(bytes32 role => RoleData) _roles;
    }

    bytes32 private constant AccessControlStorageLocation = 0x02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800;

    function _getAccessControlStorage() private pure returns (AccessControlStorage storage $) {
        assembly {
            $.slot := AccessControlStorageLocation
        }
    }

    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    function __AccessControl_init() internal onlyInitializing { }

    function __AccessControl_init_unchained() internal onlyInitializing { }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    function hasRole(bytes32 role, address account) public view virtual returns (bool) {
        AccessControlStorage storage $ = _getAccessControlStorage();
        return $._roles[role].hasRole[account];
    }

    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert AccessControlUnauthorizedAccount(account, role);
        }
    }

    function getRoleAdmin(bytes32 role) public view virtual returns (bytes32) {
        AccessControlStorage storage $ = _getAccessControlStorage();
        return $._roles[role].adminRole;
    }

    function grantRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    function renounceRole(bytes32 role, address callerConfirmation) public virtual {
        if (callerConfirmation != _msgSender()) {
            revert AccessControlBadConfirmation();
        }

        _revokeRole(role, callerConfirmation);
    }

    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        AccessControlStorage storage $ = _getAccessControlStorage();
        bytes32 previousAdminRole = getRoleAdmin(role);
        $._roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    function _grantRole(bytes32 role, address account) internal virtual returns (bool) {
        AccessControlStorage storage $ = _getAccessControlStorage();
        if (!hasRole(role, account)) {
            $._roles[role].hasRole[account] = true;
            emit RoleGranted(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }

    function _revokeRole(bytes32 role, address account) internal virtual returns (bool) {
        AccessControlStorage storage $ = _getAccessControlStorage();
        if (hasRole(role, account)) {
            $._roles[role].hasRole[account] = false;
            emit RoleRevoked(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }
}

// --- @openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol ---
abstract contract PausableUpgradeable is Initializable, ContextUpgradeable {
    struct PausableStorage {
        bool _paused;
    }

    bytes32 private constant PausableStorageLocation = 0xcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f03300;

    function _getPausableStorage() private pure returns (PausableStorage storage $) {
        assembly {
            $.slot := PausableStorageLocation
        }
    }

    event Paused(address account);
    event Unpaused(address account);

    error EnforcedPause();
    error ExpectedPause();

    function __Pausable_init() internal onlyInitializing {
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal onlyInitializing {
        PausableStorage storage $ = _getPausableStorage();
        $._paused = false;
    }

    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    modifier whenPaused() {
        _requirePaused();
        _;
    }

    function paused() public view virtual returns (bool) {
        PausableStorage storage $ = _getPausableStorage();
        return $._paused;
    }

    function _requireNotPaused() internal view virtual {
        if (paused()) {
            revert EnforcedPause();
        }
    }

    function _requirePaused() internal view virtual {
        if (!paused()) {
            revert ExpectedPause();
        }
    }

    function _pause() internal virtual whenNotPaused {
        PausableStorage storage $ = _getPausableStorage();
        $._paused = true;
        emit Paused(_msgSender());
    }

    function _unpause() internal virtual whenPaused {
        PausableStorage storage $ = _getPausableStorage();
        $._paused = false;
        emit Unpaused(_msgSender());
    }
}

// --- @openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol ---
abstract contract ReentrancyGuardUpgradeable is Initializable {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    struct ReentrancyGuardStorage {
        uint256 _status;
    }

    bytes32 private constant ReentrancyGuardStorageLocation = 0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;

    function _getReentrancyGuardStorage() private pure returns (ReentrancyGuardStorage storage $) {
        assembly {
            $.slot := ReentrancyGuardStorageLocation
        }
    }

    error ReentrancyGuardReentrantCall();

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        $._status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        if ($._status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }
        $._status = ENTERED;
    }

    function _nonReentrantAfter() private {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        $._status = NOT_ENTERED;
    }

    function _reentrancyGuardEntered() internal view returns (bool) {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        return $._status == ENTERED;
    }
}

// ============ GatewayEVM application types & contract ============

/// @notice Struct containing revert context passed to onRevert.
/// @param sender Address of account that initiated smart contract call.
/// @param asset Address of asset.
/// @param amount Amount specified with the transaction.
/// @param revertMessage Arbitrary data sent back in onRevert.
struct RevertContext {
    address sender;
    address asset;
    uint256 amount;
    bytes revertMessage;
}

/// @title Revertable
/// @notice Interface for contracts that support revertable calls.
interface Revertable {
    /// @notice Called when a revertable call is made.
    /// @param revertContext Revert context to pass to onRevert.
    function onRevert(RevertContext calldata revertContext) external;
}

/// @notice Message context passed to execute function.
/// @param sender Sender from omnichain contract.
struct MessageContext {
    address sender;
}

/// @title IGatewayEVMEvents
/// @notice Interface for the events emitted by the GatewayEVM contract (execute path).
interface IGatewayEVMEvents {
    /// @notice Emitted when a contract call is executed.
    /// @param destination The address of the contract called.
    /// @param value The amount of ETH sent with the call.
    /// @param data The calldata passed to the contract call.
    event Executed(address indexed destination, uint256 value, bytes data);
}

/// @title IGatewayEVMErrors
/// @notice Interface for the errors used in the GatewayEVM contract (execute path).
interface IGatewayEVMErrors {
    /// @notice Error for failed execution.
    error ExecutionFailed();

    /// @notice Error for zero address input.
    error ZeroAddress();

    /// @notice Error when trying to call onCall method using arbitrary call.
    error NotAllowedToCallOnCall();

    /// @notice Error when trying to call onRevert method using arbitrary call.
    error NotAllowedToCallOnRevert();
}

/// @notice Interface implemented by contracts receiving authenticated calls.
interface Callable {
    function onCall(
        MessageContext calldata context,
        bytes calldata message
    )
        external
        payable
        returns (bytes memory);
}

/// @title IGatewayEVM
/// @notice Interface for the GatewayEVM contract (execute path).
interface IGatewayEVM is IGatewayEVMErrors, IGatewayEVMEvents {
    /// @notice Executes a call to a destination address without ERC20 tokens.
    /// @dev This function can only be called by the TSS address and it is payable.
    /// @param messageContext Message context containing sender and arbitrary call flag.
    /// @param destination Address to call.
    /// @param data Calldata to pass to the call.
    /// @return The result of the call.
    function execute(
        MessageContext calldata messageContext,
        address destination,
        bytes calldata data
    )
        external
        payable
        returns (bytes memory);
}

/// @title GatewayEVM
/// @notice The GatewayEVM contract is the endpoint to call smart contracts on external chains.
/// @dev The contract doesn't hold any funds and should never have active allowances.
contract GatewayEVM is
    Initializable,
    AccessControlUpgradeable,
    IGatewayEVM,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    /// @notice The address of the TSS (Threshold Signature Scheme) contract.
    address public tssAddress;

    /// @notice New role identifier for tss role.
    bytes32 public constant TSS_ROLE = keccak256("TSS_ROLE");
    /// @notice New role identifier for pauser role.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize with tss address. Admin account set as DEFAULT_ADMIN_ROLE.
    /// @dev Using admin to pause, and tss for tss role.
    function initialize(address tssAddress_, address admin_) public initializer {
        if (tssAddress_ == address(0)) {
            revert ZeroAddress();
        }
        __ReentrancyGuard_init();
        __AccessControl_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(PAUSER_ROLE, admin_);
        _grantRole(PAUSER_ROLE, tssAddress_);
        tssAddress = tssAddress_;
        _grantRole(TSS_ROLE, tssAddress_);
    }

    /// @notice Executes a call to a destination address without ERC20 tokens.
    /// @dev This function can only be called by the TSS address and it is payable.
    /// @param messageContext Message context containing sender.
    /// @param destination Address to call.
    /// @param data Calldata to pass to the call.
    /// @return The result of the call.
    function execute(
        MessageContext calldata messageContext,
        address destination,
        bytes calldata data
    )
        external
        payable
        nonReentrant
        onlyRole(TSS_ROLE)
        whenNotPaused
        returns (bytes memory)
    {
        if (destination == address(0)) revert ZeroAddress();
        bytes memory result;
        // Execute the call on the target contract
        // if sender is provided in messageContext call is authenticated and target is Callable.onCall
        // otherwise, call is arbitrary
        if (messageContext.sender == address(0)) {
            result = _executeArbitraryCall(destination, data);
        } else {
            result = _executeAuthenticatedCall(messageContext, destination, data);
        }

        emit Executed(destination, msg.value, data);

        return result;
    }

    /// @dev Private function to execute an arbitrary call to a destination address.
    /// @param destination Address to call.
    /// @param data Calldata to pass to the call.
    /// @return The result of the call.
    function _executeArbitraryCall(address destination, bytes calldata data) private returns (bytes memory) {
        _revertIfOnCallOrOnRevert(data);
        (bool success, bytes memory result) = destination.call{ value: msg.value }(data);
        if (!success) revert ExecutionFailed();

        return result;
    }

    /// @dev Private function to execute an authenticated call to a destination address.
    /// @param messageContext Message context containing sender and arbitrary call flag.
    /// @param destination Address to call.
    /// @param data Calldata to pass to the call.
    /// @return The result of the call.
    function _executeAuthenticatedCall(
        MessageContext calldata messageContext,
        address destination,
        bytes calldata data
    )
        private
        returns (bytes memory)
    {
        return Callable(destination).onCall{ value: msg.value }(messageContext, data);
    }

    // @dev prevent spoofing onCall and onRevert functions
    function _revertIfOnCallOrOnRevert(bytes calldata data) private pure {
        if (data.length >= 4) {
            bytes4 functionSelector;
            assembly {
                functionSelector := calldataload(data.offset)
            }

            if (functionSelector == Callable.onCall.selector) {
                revert NotAllowedToCallOnCall();
            }

            if (functionSelector == Revertable.onRevert.selector) {
                revert NotAllowedToCallOnRevert();
            }
        }
    }
}
