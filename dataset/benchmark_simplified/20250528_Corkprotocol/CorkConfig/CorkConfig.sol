// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

// =============================================================
// Inlined minimal dependencies (flattened)
// =============================================================

type Id is bytes32;

interface IErrors {
    error ZeroAddress();
    error OnlyConfigAllowed();
}

interface IExchangeRateProvider {
    function rate() external view returns (uint256);
    function rate(Id id) external view returns (uint256);
}

contract ExchangeRateProvider is IErrors, IExchangeRateProvider {
    address internal CONFIG;

    mapping(Id => uint256) internal exchangeRate;

    function onlyConfig() internal {
        if (msg.sender != CONFIG) {
            revert IErrors.OnlyConfigAllowed();
        }
    }

    constructor(address _config) {
        if (_config == address(0)) {
            revert IErrors.ZeroAddress();
        }
        CONFIG = _config;
    }

    function rate() external view returns (uint256) {
        return 0; // For future use
    }

    function rate(Id id) external view returns (uint256) {
        return exchangeRate[id];
    }

    function setRate(Id id, uint256 newRate) external {
        onlyConfig();

        exchangeRate[id] = newRate;
    }
}

abstract contract Pausable {
    event Paused(address account);
    event Unpaused(address account);

    bool private _paused;

    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    function paused() public view returns (bool) {
        return _paused;
    }

    function _pause() internal virtual {
        if (!_paused) {
            _paused = true;
            emit Paused(msg.sender);
        }
    }

    function _unpause() internal virtual {
        if (_paused) {
            _paused = false;
            emit Unpaused(msg.sender);
        }
    }
}

abstract contract AccessControl {
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    mapping(bytes32 => mapping(address => bool)) private _roles;
    mapping(bytes32 => bytes32) private _roleAdmins;

    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "AccessControl: missing role");
        _;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }

    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        bytes32 admin = _roleAdmins[role];
        return admin == bytes32(0) ? DEFAULT_ADMIN_ROLE : admin;
    }

    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal {
        bytes32 previous = getRoleAdmin(role);
        _roleAdmins[role] = adminRole;
        emit RoleAdminChanged(role, previous, adminRole);
    }

    function _grantRole(bytes32 role, address account) internal {
        if (!_roles[role][account]) {
            _roles[role][account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    function _revokeRole(bytes32 role, address account) internal {
        if (_roles[role][account]) {
            _roles[role][account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }
}

interface ModuleCore {
    function initializeModuleCore(
        address pa,
        address ra,
        uint256 initialArp,
        uint256 expiryInterval,
        address exchangeRateProvider
    ) external;

    function getId(address pa, address ra, uint256 initialArp, uint256 expiry, address exchangeRateProvider)
        external
        pure
        returns (Id);

    function updateVaultNavThreshold(Id id, uint256 newNavThreshold) external;
}

// The following are only used as types in storage.
interface IDsFlashSwapCore {}
interface IVault {}
interface CorkHook {}
interface ProtectedUnitFactory {}
interface ProtectedUnit {}

/**
 * @title Config Contract
 * @author Cork Team
 * @notice Config contract for managing pairs and configurations of Cork protocol
 */
contract CorkConfig is AccessControl, Pausable {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant RATE_UPDATERS_ROLE = keccak256("RATE_UPDATERS_ROLE");
    bytes32 public constant BASE_LIQUIDATOR_ROLE = keccak256("BASE_LIQUIDATOR_ROLE");

    ModuleCore public moduleCore;
    IDsFlashSwapCore public flashSwapRouter;
    CorkHook public hook;
    ProtectedUnitFactory public protectedUnitFactory;
    ExchangeRateProvider public defaultExchangeRateProvider;
    // Cork Protocol's treasury address. Other Protocol component should fetch this address directly from the config contract
    // instead of storing it themselves, since it'll be hard to update the treasury address in all the components if it changes vs updating it in the config contract once
    address public treasury;

    uint256 public rolloverPeriodInBlocks = 480;

    uint256 public defaultDecayDiscountRateInDays = 0;

    // this essentially means deposit will not be allowed if the NAV of the pair is below this threshold
    // the nav is updated every vault deposit
    uint256 public defaultNavThreshold = 90 ether;

    uint256 public constant WHITELIST_TIME_DELAY = 7 days;

    /// @notice liquidation address => timestamp when liquidation is allowed
    mapping(address => uint256) internal liquidationWhitelist;

    /// @notice thrown when caller is not manager/Admin of Cork Protocol
    error CallerNotManager();

    /// @notice thrown when passed Invalid/Zero Address
    error InvalidAddress();

    /// @notice Emitted when a moduleCore variable set
    /// @param moduleCore Address of Modulecore contract
    event ModuleCoreSet(address moduleCore);

    /// @notice Emitted when a flashSwapRouter variable set
    /// @param flashSwapRouter Address of flashSwapRouter contract
    event FlashSwapCoreSet(address flashSwapRouter);

    /// @notice Emitted when a hook variable set
    /// @param hook Address of hook contract
    event HookSet(address hook);

    /// @notice Emitted when a protectedUnitFactory variable set
    /// @param protectedUnitFactory Address of protectedUnitFactory contract
    event ProtectedUnitFactorySet(address protectedUnitFactory);

    /// @notice Emitted when a treasury is set
    /// @param treasury Address of treasury contract/address
    event TreasurySet(address treasury);

    modifier onlyManager() {
        if (!hasRole(MANAGER_ROLE, msg.sender)) {
            revert CallerNotManager();
        }
        _;
    }

    modifier onlyUpdaterOrManager() {
        if (!hasRole(RATE_UPDATERS_ROLE, msg.sender) && !hasRole(MANAGER_ROLE, msg.sender)) {
            revert CallerNotManager();
        }
        _;
    }

    constructor(address adminAdd, address managerAdd) {
        if (adminAdd == address(0) || managerAdd == address(0)) {
            revert InvalidAddress();
        }

        defaultExchangeRateProvider = new ExchangeRateProvider(address(this));

        _setRoleAdmin(MANAGER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(RATE_UPDATERS_ROLE, MANAGER_ROLE);
        _setRoleAdmin(BASE_LIQUIDATOR_ROLE, MANAGER_ROLE);
        _grantRole(DEFAULT_ADMIN_ROLE, adminAdd);
        _grantRole(MANAGER_ROLE, managerAdd);
    }

    /**
     * @dev Initialize Module Core
     * @param pa Address of PA
     * @param ra Address of RA
     * @param initialArp initial price of DS
     */
    function initializeModuleCore(
        address pa,
        address ra,
        uint256 initialArp,
        uint256 expiryInterval,
        address exchangeRateProvider
    ) external {
        moduleCore.initializeModuleCore(pa, ra, initialArp, expiryInterval, exchangeRateProvider);

        // auto assign nav threshold
        Id id = moduleCore.getId(pa, ra, initialArp, expiryInterval, exchangeRateProvider);
        moduleCore.updateVaultNavThreshold(id, defaultNavThreshold);
    }

}
