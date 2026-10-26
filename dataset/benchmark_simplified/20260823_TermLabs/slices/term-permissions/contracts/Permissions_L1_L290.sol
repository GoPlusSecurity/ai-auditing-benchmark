// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";

enum ParameterType {
    Static,
    Dynamic,
    Dynamic32
}

enum Comparison {
    EqualTo,
    GreaterThan,
    LessThan,
    OneOf
}

enum ExecutionOptions {
    None,
    Send,
    DelegateCall,
    Both
}

enum Clearance {
    None,
    Target,
    Function
}

struct TargetAddress {
    Clearance clearance;
    ExecutionOptions options;
}

struct Role {
    mapping(address => bool) members;
    mapping(address => TargetAddress) targets;
    mapping(bytes32 => uint256) functions;
    mapping(bytes32 => bytes32) compValues;
    mapping(bytes32 => bytes32[]) compValuesOneOf;
}

library Permissions {
    uint256 internal constant SCOPE_MAX_PARAMS = 48;

    event AllowTarget(
        uint16 role,
        address targetAddress,
        ExecutionOptions options
    );
    event RevokeTarget(uint16 role, address targetAddress);
    event ScopeTarget(uint16 role, address targetAddress);
    event ScopeAllowFunction(
        uint16 role,
        address targetAddress,
        bytes4 selector,
        ExecutionOptions options,
        uint256 resultingScopeConfig
    );
    event ScopeRevokeFunction(
        uint16 role,
        address targetAddress,
        bytes4 selector,
        uint256 resultingScopeConfig
    );
    event ScopeFunction(
        uint16 role,
        address targetAddress,
        bytes4 functionSig,
        bool[] isParamScoped,
        ParameterType[] paramType,
        Comparison[] paramComp,
        bytes[] compValue,
        ExecutionOptions options,
        uint256 resultingScopeConfig
    );
    event ScopeFunctionExecutionOptions(
        uint16 role,
        address targetAddress,
        bytes4 functionSig,
        ExecutionOptions options,
        uint256 resultingScopeConfig
    );
    event ScopeParameter(
        uint16 role,
        address targetAddress,
        bytes4 functionSig,
        uint256 index,
        ParameterType paramType,
        Comparison paramComp,
        bytes compValue,
        uint256 resultingScopeConfig
    );
    event ScopeParameterAsOneOf(
        uint16 role,
        address targetAddress,
        bytes4 functionSig,
        uint256 index,
        ParameterType paramType,
        bytes[] compValues,
        uint256 resultingScopeConfig
    );
    event UnscopeParameter(
        uint16 role,
        address targetAddress,
        bytes4 functionSig,
        uint256 index,
        uint256 resultingScopeConfig
    );

    /// Sender is not a member of the role
    error NoMembership();

    /// Arrays must be the same length
    error ArraysDifferentLength();

    /// Function signature too short
    error FunctionSignatureTooShort();

    /// Role not allowed to delegate call to target address
    error DelegateCallNotAllowed();

    /// Role not allowed to call target address
    error TargetAddressNotAllowed();

    /// Role not allowed to call this function on target address
    error FunctionNotAllowed();

    /// Role not allowed to send to target address
    error SendNotAllowed();

    /// Role not allowed to use bytes for parameter
    error ParameterNotAllowed();

    /// Role not allowed to use bytes for parameter
    error ParameterNotOneOfAllowed();

    /// Role not allowed to use bytes less than value for parameter
    error ParameterLessThanAllowed();

    /// Role not allowed to use bytes greater than value for parameter
    error ParameterGreaterThanAllowed();

    /// only multisend txs with an offset of 32 bytes are allowed
    error UnacceptableMultiSendOffset();

    /// OneOf Comparison must be set via dedicated function
    error UnsuitableOneOfComparison();

    /// Not possible to define gt/lt for Dynamic types
    error UnsuitableRelativeComparison();

    /// CompValue for static types should have a size of exactly 32 bytes
    error UnsuitableStaticCompValueSize();

    /// CompValue for Dynamic32 types should be a multiple of exactly 32 bytes
    error UnsuitableDynamic32CompValueSize();

    /// Exceeds the max number of params supported
    error ScopeMaxParametersExceeded();

    /// OneOf Comparison requires at least two compValues
    error NotEnoughCompValuesForOneOf();

    /// The provided calldata for execution is too short, or an OutOfBounds scoped parameter was configured
    error CalldataOutOfBounds();

    /*
     *
     * CHECKERS
     *
     */

    /// @dev Entry point for checking the scope of a transaction.
    function check(
        Role storage role,
        address multisend,
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation
    ) public view {
        if (!role.members[msg.sender]) {
            revert NoMembership();
        }
        if (multisend == to) {
            checkMultisendTransaction(role, data);
        } else {
            checkTransaction(role, to, value, data, operation);
        }
    }

    /// @dev Splits a multisend data blob into transactions and forwards them to be checked.
    /// @param data the packed transaction data (created by utils function buildMultiSendSafeTx).
    /// @param role Role to check for.
    function checkMultisendTransaction(Role storage role, bytes memory data)
        internal
        view
    {
        Enum.Operation operation;
        address to;
        uint256 value;
        bytes memory out;
        uint256 dataLength;

        uint256 offset;
        assembly {
            offset := mload(add(data, 36))
        }
        if (offset != 32) {
            revert UnacceptableMultiSendOffset();
        }

        // transaction data (1st tx operation) reads at byte 100,
        // 4 bytes (multisend_id) + 32 bytes (offset_multisend_data) + 32 bytes multisend_data_length
        // increment i by the transaction data length
        // + 85 bytes of the to, value, and operation bytes until we reach the end of the data
        for (uint256 i = 100; i < data.length; i += (85 + dataLength)) {
            assembly {
                // First byte of the data is the operation.
                // We shift by 248 bits (256 - 8 [operation byte]) right since mload will always load 32 bytes (a word).
                // This will also zero out unused data.
                operation := shr(0xf8, mload(add(data, i)))
                // We offset the load address by 1 byte (operation byte)
                // We shift it right by 96 bits (256 - 160 [20 address bytes]) to right-align the data and zero out unused data.
                to := shr(0x60, mload(add(data, add(i, 0x01))))
                // We offset the load address by 21 byte (operation byte + 20 address bytes)
                value := mload(add(data, add(i, 0x15)))
                // We offset the load address by 53 byte (operation byte + 20 address bytes + 32 value bytes)
                dataLength := mload(add(data, add(i, 0x35)))
                // We offset the load address by 85 byte (operation byte + 20 address bytes + 32 value bytes + 32 data length bytes)
                out := add(data, add(i, 0x35))
            }
            checkTransaction(role, to, value, out, operation);
        }
    }

    /// @dev Inspects an individual transaction and performs checks based on permission scoping.
    /// Wildcarded indicates whether params need to be inspected or not. When true, only ExecutionOptions are checked.
    /// @param role Role to check for.
    /// @param targetAddress Destination address of transaction.
    /// @param value Ether value of module transaction.
    /// @param data Data payload of module transaction.
    /// @param operation Operation type of module transaction: 0 == call, 1 == delegate call.
    function checkTransaction(
        Role storage role,
        address targetAddress,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) internal view {
        if (data.length != 0 && data.length < 4) {
            revert FunctionSignatureTooShort();
        }

        TargetAddress storage target = role.targets[targetAddress];
        if (target.clearance == Clearance.None) {
            revert TargetAddressNotAllowed();
        }

        if (target.clearance == Clearance.Target) {
            checkExecutionOptions(value, operation, target.options);
            return;
        }

        if (target.clearance == Clearance.Function) {
            uint256 scopeConfig = role.functions[
                keyForFunctions(targetAddress, bytes4(data))
            ];

            if (scopeConfig == 0) {
                revert FunctionNotAllowed();
            }

            (ExecutionOptions options, bool isWildcarded, ) = unpackFunction(
                scopeConfig
            );

            checkExecutionOptions(value, operation, options);

            if (!isWildcarded) {
                checkParameters(role, scopeConfig, targetAddress, data);
            }
            return;
        }

        assert(false);
    }
