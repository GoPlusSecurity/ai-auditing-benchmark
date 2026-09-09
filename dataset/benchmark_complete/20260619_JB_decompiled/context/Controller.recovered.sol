// SPDX-License-Identifier: UNLICENSED
// Recovered by Decompiler Agent - NOT verified source code
// Contract: 0x94741df7bf9db91b172a4e195e9bea79ce3726cd
// Method: agent-native decompilation from disassembly
// Confidence: low
// Selectors covered: 3/3

pragma solidity ^0.8.0; // approximate

interface IERC20Like {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract Recovered_94741df7 {
    // Storage layout recovered from SLOAD/SSTORE indices. Names are inferred.
    // slot 0x00: owner/admin root address. Live value observed: 0xe95f3bba0c1033ee1fee23862c5e2897151f9635.
    address private slot_00_owner;

    // slot 0x02: packed config. Low byte is used as a ReentrancyGuard status.
    // The high 160 bits include the USDT address in live storage.
    uint256 private slot_02_packedConfig;

    // slot 0x03: reward/JB token used by the traced transferFrom calls.
    // Live value observed: 0xcf92e7ef4a63d52dc15f45a24f4f815f00f299a7.
    address private slot_03_rewardToken;

    // slot 0x04..0x08: configured wallets/helpers. Slot 0x06 is used as a sink in
    // reward accounting branches; slots 0x07/0x08 were helper-like addresses in storage.
    address private slot_04_paymentReceiver;
    address private slot_05_operationWallet;
    address private slot_06_nodePoolWallet;
    address private slot_07_helperA;
    address private slot_08_helperB;

    // mapping(address => flags/address/value) slots observed in trace-called paths.
    mapping(address => uint256) private slot_0f_parentPacked;      // keccak256(account, 0x0f)
    mapping(address => uint256) private slot_1a_rewardReporter;    // keccak256(account, 0x1a), low byte boolean
    mapping(address => uint256) private slot_1d_rewardDebtA;       // keccak256(account, 0x1d)
    mapping(address => uint256) private slot_1e_rewardDebtB;       // keccak256(account, 0x1e)

    // Aggregate counters changed in the incident trace.
    uint256 private slot_23_accRewardA;
    uint256 private slot_24_accRewardB;
    uint256 private slot_25_poolBalanceA;
    uint256 private slot_26_poolBalanceB;

    // Additional counters used by broader reward bookkeeping.
    uint256 private slot_27_pendingReward;
    uint256 private slot_28_userCountLike;
    uint256 private slot_29_totalLike;

    // Unresolved events. The bytecode emits LOG2/LOG3/LOG4 with constant topics;
    // topic names were not recoverable from verified ABI data.
    event RawRewardLog(bytes32 indexed topic0, address indexed caller, uint256 amountOrIndex);
    event RawAccountingLog(bytes32 indexed topic0, address indexed account, uint256 amount);

    // ---------------------------------------------------------------------
    // selector 0xf1f9d8c9: parent(address)
    // signature from cast 4byte
    // Entry PC: 0x090a
    // ---------------------------------------------------------------------
    function parent(address account) external view returns (address parent_) {
        // SLOAD keccak256(abi.encode(account, uint256(0x0f)))
        // Return low 160 bits.
        parent_ = address(uint160(slot_0f_parentPacked[account]));
    }

    // ---------------------------------------------------------------------
    // selector 0x727ebe6d: func_0x727ebe6d(address,uint256)
    // signature inferred from calldata in trace
    // Entry PC: 0x1d48
    //
    // Trace: called 17 times by 0x1b5732eb98911c25acf7bdfaffb9409782cae6d7.
    // Each observed call made exactly one external CALL:
    //   target   = slot_03_rewardToken (0xcf92e7ef4a63d52dc15f45a24f4f815f00f299a7)
    //   selector = 0x23b872dd transferFrom(address,address,uint256)
    //   args     = (account, address(this), amount)
    // ---------------------------------------------------------------------
    function func_0x727ebe6d(address account, uint256 amount) external {
        _enterNonReentrant();
        _requireRewardReporter(msg.sender);

        // The entry dispatches first to internal PC 0x378c, then to PC 0x3bf3.
        // The exact semantic split is unresolved, but the trace shows only one
        // token pull from account to this contract for this external function.
        _pullRewardToken(account, amount);
        _updateRewardPoolB(account, amount);
        _updateRewardPoolA(account, amount);

        _exitNonReentrant();
    }

    // ---------------------------------------------------------------------
    // selector 0x0e2aa265: func_0x0e2aa265(address,uint256)
    // signature inferred from calldata in trace
    // Entry PC: 0x2bc8
    //
    // Trace: called 17 times by 0x1b5732eb98911c25acf7bdfaffb9409782cae6d7.
    // Each observed call made exactly one external CALL:
    //   target   = slot_03_rewardToken (0xcf92e7ef4a63d52dc15f45a24f4f815f00f299a7)
    //   selector = 0x23b872dd transferFrom(address,address,uint256)
    //   args     = (account, address(this), amount)
    // ---------------------------------------------------------------------
    function func_0x0e2aa265(address account, uint256 amount) external {
        _enterNonReentrant();
        _requireRewardReporter(msg.sender);

        // The entry dispatches to internal PC 0x3806.
        _pullRewardToken(account, amount);
        _updateRewardPoolB(account, amount);

        _exitNonReentrant();
    }

    // ---------------------------------------------------------------------
    // Shared internal logic recovered from trace-called functions.
    // ---------------------------------------------------------------------

    function _enterNonReentrant() internal {
        // SLOAD/SSTORE slot 0x02 low byte.
        // Revert string in bytecode: "ReentrancyGuard: reentrant".
        require((slot_02_packedConfig & 0xff) == 0, "ReentrancyGuard: reentrant");
        slot_02_packedConfig = (slot_02_packedConfig & ~uint256(0xff)) | 1;
    }

    function _exitNonReentrant() internal {
        // SSTORE slot 0x02 low byte cleared after the body.
        slot_02_packedConfig = slot_02_packedConfig & ~uint256(0xff);
    }

    function _requireRewardReporter(address caller) internal view {
        // SLOAD keccak256(abi.encode(caller, uint256(0x1a))). Low byte boolean.
        // Revert string in bytecode: "JBNode: not reward reporter".
        require((slot_1a_rewardReporter[caller] & 0xff) != 0, "JBNode: not reward reporter");
    }

    function _pullRewardToken(address from, uint256 amount) internal {
        // Internal helper at PC 0x4333 builds calldata:
        //   0x23b872dd || from || address(this) || amount
        // and CALLs the token address read from slot 0x03.
        address token = slot_03_rewardToken;
        require(token != address(0), "SafeToken: zero to");

        (bool ok, bytes memory ret) = token.call(
            abi.encodeWithSelector(IERC20Like.transferFrom.selector, from, address(this), amount)
        );

        // The bytecode accepts empty returndata or a true boolean, and reverts
        // with "SafeToken: transferFrom failed" otherwise.
        require(ok && (ret.length == 0 || abi.decode(ret, (bool))), "SafeToken: transferFrom failed");
    }

    function _updateRewardPoolB(address account, uint256 amount) internal {
        // Internal PCs 0x378c/0x3806 update aggregate counters and per-account
        // debt using slots 0x24 and 0x26. Arithmetic uses a large fixed-point
        // precision constant and checked add/sub helpers at PCs 0x337b/0x34a1.
        //
        // Observed changed slots during the exploit transaction:
        //   slot 0x24: 0x...b6b561e6...00000000 -> 0x...1175fc24...00000000
        //   slot 0x26: 0x...01e5b8fa8fe2ac0000 -> 0x...03603e11b4f83c359aceb3
        //
        // Pseudocode approximation:
        slot_24_accRewardB = _checkedAdd(slot_24_accRewardB, _scaledReward(amount));
        slot_26_poolBalanceB = _checkedAdd(slot_26_poolBalanceB, amount);
        slot_1e_rewardDebtB[account] = slot_24_accRewardB;

        // LOG3 at PCs around 0x3887/0x38c4. Topic is copied from code and was
        // not resolved to a named event.
        emit RawRewardLog(bytes32(uint256(1)), msg.sender, amount);
    }

    function _updateRewardPoolA(address account, uint256 amount) internal {
        // Internal PC 0x3bf3 mirrors the reward accounting into slots 0x23 and
        // 0x25, with per-account slot 0x1d. It also checks low-byte flags in
        // mappings at slots 0x0d, 0x0e, and 0x1c before applying some branches.
        //
        // Observed changed slots during the exploit transaction:
        //   slot 0x23: 0x...1c1be7ad... -> 0x...2627f3fd...
        //   slot 0x25: 0x...05b12aefafa8040000 -> 0x...07ba01a1b6a2bd00482923
        //
        // Pseudocode approximation:
        slot_23_accRewardA = _checkedAdd(slot_23_accRewardA, _scaledReward(amount));
        slot_25_poolBalanceA = _checkedAdd(slot_25_poolBalanceA, amount);
        slot_1d_rewardDebtA[account] = slot_23_accRewardA;

        // LOG3 at PCs around 0x3c74/0x3cb1. Topic is copied from code and was
        // not resolved to a named event.
        emit RawAccountingLog(bytes32(uint256(2)), account, amount);
    }

    function _scaledReward(uint256 amount) internal pure returns (uint256) {
        // unresolved: exact scaling uses constant assembled as
        // 0x0c097ce7bc90715b34b9f1 << 0x24 and branch-specific divisors.
        return amount;
    }

    function _checkedAdd(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        require(c >= a, "arithmetic overflow");
    }

    // Other dispatcher functions are intentionally omitted in this
    // trace-guided recovery. The dispatcher contains many admin, node, reward,
    // migration, and view selectors, but they were outside the requested
    // trace_selectors and were not necessary to preserve the traced calls.
}
