//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {VaultMultiSigTimeLockContract} from "./VaultMultisignTimeLockContract.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {Math} from "./math/Math.sol";
import {SafeERC20} from "./math/SafeERC20.sol";
import {ReentrancyGuard} from "./utils/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract VaultContract is VaultMultiSigTimeLockContract, ReentrancyGuard, AccessControl {
    using SafeERC20 for IERC20;


    enum ModuleStatus {
        NONE,        // not registered
        REGISTERED,  // registered
        ACTIVE,      // normal operation
        READ_ONLY,   // can read storage, cannot move tokens or write
        DEPRECATED,  // old module during soft upgrade
        DISABLED     // fully blocked
    }

    enum ModuleTokenLimitType{
        VALUE,
        PERCENT
    }

    struct Module {
        string name;
        uint64 version;
        bytes32 storageId;
        ModulePermission permission;
        ModuleStatus status;
        mapping(address => ModuleTokenLimit) tokenLimit;
        uint256 createdAt;
    }

    struct ModulePermission {
        mapping(address => bool) moveTokens;
    }

    struct ModuleTokenLimit {
        ModuleTokenLimitType limitType;
        uint256 limit; // Limit by PERIOD: Amount, PERCENT: %
        uint256 spent;
        uint256 period; // period by seconds
        uint256 lastResetAt;
    }

    struct ModuleStorage {
        mapping(address => uint256) totalTokenIn;
        mapping(address => uint256) totalTokenOut;
        mapping(address => uint256) totalFeeCollected;
        uint256 lastInAt;
        uint256 lastOutAt;
//        Addition data
        mapping(bytes32 => uint256) uintStore;
        mapping(bytes32 => int256) intStore;
        mapping(bytes32 => address) addressStore;
        mapping(bytes32 => bool) booleanStore;
        mapping(bytes32 => bytes32) bytes32Store;
        mapping(bytes32 => bytes) bytesStore;
        mapping(bytes32 => string) stringStore;
    }

    struct ModuleView {
        address module;
        ModuleStatus status;
        bytes32 storageId;
        uint256 createdAt;
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    bytes32 public constant MODULE_ROLE = keccak256("MODULE");
    uint256 public constant TOKEN_LIMIT_PERCENT_DECIMAL_PRECISION = 10 ** 4; //basis points (1% = 100, 0.01% = 1)

    mapping(address => Module) internal modules;
    mapping(bytes32 => ModuleStorage) internal moduleStorage;
    address[] internal moduleList;
    mapping(address => uint256) internal moduleIndex; // 1-based index (0 = not exists)

    event VaultModuleDepositTokenEvent(address moduleAddress, address baseToken, uint256 amount, uint256 includedFee);
    event VaultModuleWithdrawalTokenEvent(address moduleAddress, address baseToken, address toAddress, uint256 amount);
    event VaultModuleWriteStorageEvent(address moduleAddress, bytes32 key);

    error VaultPermissionDeniedError();
    error VaultModuleExistedError();
    error VaultModuleNotExistError();
    error VaultModuleNotHaveWithdrawalTokenPermissionError(address tokenAddress);
    error VaultModuleExceedLimitTokenTransferError(address tokenAddress, uint256 limit, uint256 spent, uint256 available, uint256 request);
    error VaultModuleNotHaveWriteStoragePermissionError();
    error VaultModuleNotReadableError();
    error VaultModuleNotActiveError();
    error VaultModuleAlreadyInitialError();
    error VaultModuleTimeLockedError(uint256 lockTime);
    error VaultModuleIrreversibleStateError();
    error VaultModuleAddressInvalidError();
    error VaultModuleInvalidFeeAmount();
    error VaultModuleValueInvalidError();

    modifier onlyAdmin(){
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert VaultPermissionDeniedError();
        _;
    }

    modifier onlyModule(){
        if (!hasRole(MODULE_ROLE, msg.sender)) revert VaultPermissionDeniedError();
        _;
    }

    constructor(address[] memory signers){
        _initMultiSigTimeLock(signers, 2, 1 days);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    //Views function
    function getStats(address moduleAddress, address tokenAddress) external view returns (
        uint256 total_in,
        uint256 total_out,
        uint256 total_fee,
        uint256 withdraw_limit,
        uint256 withdrawable,
        ModuleStatus status,
        uint256 createdAt
    ){
        Module storage module = modules[moduleAddress];
        ModuleStorage storage mStorage = moduleStorage[module.storageId];
        total_in = mStorage.totalTokenIn[tokenAddress];
        total_out = mStorage.totalTokenOut[tokenAddress];
        total_fee = mStorage.totalFeeCollected[tokenAddress];
        (withdraw_limit, withdrawable) = _getModuleTokenLimit(moduleAddress, tokenAddress);
        status = module.status;
        createdAt = module.createdAt;
    }

    function getModules(uint256 startIndex, uint256 limit) external view returns (ModuleView[] memory moduleViews){
        if (startIndex >= moduleList.length) {
            return new ModuleView[](0);
        }
        uint256 remaining = moduleList.length - startIndex;
        uint256 actualLimit = Math.min(remaining, limit);
        moduleViews = new ModuleView[](actualLimit - 1);
        for (uint256 i = 1; i < actualLimit; i++) {
            address moduleAddress = moduleList[startIndex + i];
            Module storage module = modules[moduleAddress];
            moduleViews[i - 1] = ModuleView({
                module: moduleAddress,
                status: module.status,
                storageId: module.storageId,
                createdAt: module.createdAt
            });
        }
    }

    function getModuleCount() external view returns (uint256) {
        return moduleList.length;
    }

    //    ADMIN functions
    // @dev Multiple modules CAN share the same storageId if they need coordinated state
    function registerModule(address moduleAddress, string calldata name, uint64 version, bytes32 storageId) onlyAdmin external {
        if (hasRole(MODULE_ROLE, moduleAddress)) revert VaultModuleExistedError();
        if (moduleAddress == address(0)) revert VaultModuleAddressInvalidError();
        Module storage module = modules[moduleAddress];
        module.name = name;
        module.version = version;
        module.storageId = storageId;
        module.status = ModuleStatus.REGISTERED;
        module.createdAt = block.timestamp;

        moduleList.push(moduleAddress);
        moduleIndex[moduleAddress] = moduleList.length; // 1-based
    }

    function execActiveModule(address moduleAddress, bool readOnly) external onlyVault {
        Module storage module = modules[moduleAddress];
        if (module.status != ModuleStatus.REGISTERED) revert VaultModuleAlreadyInitialError();
        if (readOnly) module.status = ModuleStatus.READ_ONLY;
        else module.status = ModuleStatus.ACTIVE;
        _grantRole(MODULE_ROLE, moduleAddress);
    }

    function execUpdateModuleState(address moduleAddress, ModuleStatus status) external
    onlyVault {
        if (!hasRole(MODULE_ROLE, moduleAddress)) revert VaultModuleNotExistError();
        Module storage module = modules[moduleAddress];
        if (module.status < ModuleStatus.ACTIVE) revert VaultModuleNotActiveError();
        if (module.status < status)
            module.status = status;
        if (status == ModuleStatus.DISABLED)
            _removeModule(moduleAddress);
    }

    function execUpdateModulePermission(address moduleAddress, address[] calldata tokens, bool canMove) external
    onlyVault {
        if (!hasRole(MODULE_ROLE, moduleAddress)) revert VaultModuleExistedError();
        Module storage module = modules[moduleAddress];
        uint256 tokenLen = tokens.length;
        for (uint256 i; i < tokenLen; i++) {
            module.permission.moveTokens[tokens[i]] = canMove;
        }
    }

    function execSetModuleTokenLimit(address moduleAddress, address baseToken, ModuleTokenLimitType limitType, uint256 limitValue, uint256 limitPeriod) external
    onlyVault {
        if (baseToken == address(0)) revert VaultModuleAddressInvalidError();
        if (limitType == ModuleTokenLimitType.PERCENT && limitValue > TOKEN_LIMIT_PERCENT_DECIMAL_PRECISION) revert VaultModuleValueInvalidError();
        if (!hasRole(MODULE_ROLE, moduleAddress)) revert VaultModuleExistedError();
        Module storage module = modules[moduleAddress];
        ModuleTokenLimit storage tokenLimit = module.tokenLimit[baseToken];
        tokenLimit.limitType = limitType;
        tokenLimit.limit = limitValue;
        tokenLimit.period = limitPeriod;
        tokenLimit.spent = Math.min(tokenLimit.spent, limitValue);
    }

    //MODULE functions
    function moduleDepositToken(address baseToken, uint256 amount, uint256 includedFee) external onlyModule {
        if (baseToken == address(0)) revert VaultModuleAddressInvalidError();
        if (includedFee > amount) revert VaultModuleInvalidFeeAmount();
        address moduleAddress = msg.sender;
        _requireModuleActive(moduleAddress);
        _transferTokenToVault(moduleAddress, baseToken, amount);
        if (includedFee > 0) {
            Module storage module = modules[moduleAddress];
            ModuleStorage storage mStorage = moduleStorage[module.storageId];
            mStorage.totalFeeCollected[baseToken] += includedFee;
        }
        emit VaultModuleDepositTokenEvent(moduleAddress, baseToken, amount, includedFee);
    }

    function moduleWithdrawToken(address baseToken, address toAddress, uint256 amount) external nonReentrant onlyModule {
        if (baseToken == address(0) || toAddress == address(0)) revert VaultModuleAddressInvalidError();
        address moduleAddress = msg.sender;
        _requireModuleActive(moduleAddress);
        Module storage module = modules[moduleAddress];
        ModuleStorage storage mStorage = moduleStorage[module.storageId];
        //Check permission
        if (!module.permission.moveTokens[baseToken]) revert VaultModuleNotHaveWithdrawalTokenPermissionError(baseToken);
        //Check limit
        _checkModuleTokenLimit(moduleAddress, baseToken, amount);
        mStorage.totalTokenOut[baseToken] += amount;
        mStorage.lastOutAt = block.timestamp;
        IERC20(baseToken).safeTransfer(toAddress, amount);
        emit VaultModuleWithdrawalTokenEvent(msg.sender, baseToken, toAddress, amount);
    }

    function moduleRecordFee(address baseToken, uint256 fee) external onlyModule
    {
        if (baseToken == address(0)) revert VaultModuleAddressInvalidError();
        address moduleAddress = msg.sender;
        _requireModuleActive(moduleAddress);
        Module storage module = modules[moduleAddress];
        ModuleStorage storage ms = moduleStorage[module.storageId];
        ms.totalFeeCollected[baseToken] += fee;
    }

    //Read/Write storage
    function moduleReadStorageUint(bytes32 key) external view onlyModule returns (uint256)  {
        address moduleAddress = msg.sender;
        _requireModuleReadable(moduleAddress);
        Module storage module = modules[moduleAddress];
        return moduleStorage[module.storageId].uintStore[key];
    }

    function moduleWriteStorageUint(bytes32 key, uint256 value) external onlyModule {
        address moduleAddress = msg.sender;
        _requireModuleActive(moduleAddress);
        Module storage module = modules[moduleAddress];
        moduleStorage[module.storageId].uintStore[key] = value;
        emit VaultModuleWriteStorageEvent(moduleAddress, key);
    }

    function moduleReadStorageInt(bytes32 key) external view onlyModule returns (int256) {
        address moduleAddress = msg.sender;
        _requireModuleReadable(moduleAddress);
        Module storage module = modules[moduleAddress];
        return moduleStorage[module.storageId].intStore[key];
    }

    function moduleWriteStorageInt(bytes32 key, int256 value) external onlyModule {
        address moduleAddress = msg.sender;
        _requireModuleActive(moduleAddress);
        Module storage module = modules[moduleAddress];
        moduleStorage[module.storageId].intStore[key] = value;
        emit VaultModuleWriteStorageEvent(moduleAddress, key);
    }

    function moduleReadStorageByte(bytes32 key) external view onlyModule returns (bytes memory){
        address moduleAddress = msg.sender;
        _requireModuleReadable(moduleAddress);
        Module storage module = modules[moduleAddress];
        return moduleStorage[module.storageId].bytesStore[key];
    }

    function moduleWriteStorageByte(bytes32 key, bytes calldata value) onlyModule external {
        address moduleAddress = msg.sender;
        _requireModuleActive(moduleAddress);
        Module storage module = modules[moduleAddress];
        moduleStorage[module.storageId].bytesStore[key] = value;
        emit VaultModuleWriteStorageEvent(moduleAddress, key);
    }

    function moduleReadStorageByte32(bytes32 key) external view onlyModule returns (bytes32) {
        address moduleAddress = msg.sender;
        _requireModuleReadable(moduleAddress);
        Module storage module = modules[moduleAddress];
        return moduleStorage[module.storageId].bytes32Store[key];
    }

    function moduleWriteStorageByte32(bytes32 key, bytes32 value) onlyModule external {
        address moduleAddress = msg.sender;
        _requireModuleActive(moduleAddress);
        Module storage module = modules[moduleAddress];
        moduleStorage[module.storageId].bytes32Store[key] = value;
        emit VaultModuleWriteStorageEvent(moduleAddress, key);
    }

    function moduleReadStorageBool(bytes32 key) external view onlyModule returns (bool) {
        address moduleAddress = msg.sender;
        _requireModuleReadable(moduleAddress);
        Module storage module = modules[moduleAddress];
        return moduleStorage[module.storageId].booleanStore[key];
    }

    function moduleWriteStorageBool(bytes32 key, bool value) onlyModule external {
        Module storage module = modules[msg.sender];
        address moduleAddress = msg.sender;
        _requireModuleActive(moduleAddress);
        moduleStorage[module.storageId].booleanStore[key] = value;
        emit VaultModuleWriteStorageEvent(moduleAddress, key);
    }

    function moduleReadStorageString(bytes32 key) external view onlyModule returns (string memory) {
        address moduleAddress = msg.sender;
        _requireModuleReadable(moduleAddress);
        Module storage module = modules[moduleAddress];
        return moduleStorage[module.storageId].stringStore[key];
    }

    function moduleWriteStorageString(bytes32 key, string calldata value) onlyModule external {
        Module storage module = modules[msg.sender];
        address moduleAddress = msg.sender;
        _requireModuleActive(moduleAddress);
        moduleStorage[module.storageId].stringStore[key] = value;
        emit VaultModuleWriteStorageEvent(moduleAddress, key);
    }

    function _transferTokenToVault(address moduleAddress, address baseToken, uint256 amount) internal {
        Module storage module = modules[moduleAddress];
        ModuleStorage storage mStorage = moduleStorage[module.storageId];
        mStorage.totalTokenIn[baseToken] += amount;
        mStorage.lastInAt = block.timestamp;
        IERC20(baseToken).safeTransferFrom(moduleAddress, address(this), amount);
    }

    function _checkModuleTokenLimit(address moduleAddress, address baseToken, uint256 amount) internal {
        Module storage module = modules[moduleAddress];
        ModuleTokenLimit storage tokenLimit = module.tokenLimit[baseToken];
        if (tokenLimit.lastResetAt == 0) {
            tokenLimit.lastResetAt = block.timestamp;
        }
        uint256 elapsed = block.timestamp - tokenLimit.lastResetAt;
        if (elapsed >= tokenLimit.period) {
            tokenLimit.spent = 0;
            tokenLimit.lastResetAt = block.timestamp;
        }

        (, uint256 available) = _getModuleTokenLimit(moduleAddress, baseToken);
        if (available < amount)
            revert VaultModuleExceedLimitTokenTransferError(baseToken, tokenLimit.limit, tokenLimit.spent, available, amount);
        tokenLimit.spent += amount;
    }

    function _getModuleTokenLimit(address moduleAddress, address tokenAddress) internal view returns (uint256 limit, uint256 available){
        Module storage module = modules[moduleAddress];
        if (module.status != ModuleStatus.ACTIVE) return (0, 0);
        ModuleTokenLimit memory tokenLimit = module.tokenLimit[tokenAddress];
        uint256 elapsed = block.timestamp - tokenLimit.lastResetAt;
        available = 0;
        if (tokenLimit.limitType == ModuleTokenLimitType.VALUE)
            limit = tokenLimit.limit;
        else
            limit = (tokenLimit.limit * IERC20(tokenAddress).balanceOf(address(this))) / TOKEN_LIMIT_PERCENT_DECIMAL_PRECISION;
        if (elapsed < tokenLimit.period) {
            if (limit > tokenLimit.spent)
                available = limit - tokenLimit.spent;
        }
        else
            available = limit;

    }

    function _requireModuleActive(address module) internal view {
        ModuleStatus s = modules[module].status;
        if (s != ModuleStatus.ACTIVE) revert VaultModuleNotActiveError();
    }

    function _requireModuleReadable(address module) internal view {
        ModuleStatus s = modules[module].status;
        if (
            s != ModuleStatus.ACTIVE &&
            s != ModuleStatus.READ_ONLY &&
            s != ModuleStatus.DEPRECATED
        ) revert VaultModuleNotReadableError();
    }

    function _removeModule(address module) internal {
        uint256 idx = moduleIndex[module];
        if (idx == 0) return;

        uint256 lastIdx = moduleList.length;
        if (idx != lastIdx) {
            address last = moduleList[lastIdx - 1];
            moduleList[idx - 1] = last;
            moduleIndex[last] = idx;
        }

        moduleList.pop();
        moduleIndex[module] = 0;
    }

}