// SPDX-License-Identifier: UNLICENSED
// Recovered by Decompiler Agent - NOT verified source code
// Contract: 0xcf92e7ef4a63d52dc15f45a24f4f815f00f299a7
// Method: agent-native decompilation from disassembly
// Confidence: medium
// Selectors covered: 6/6

pragma solidity ^0.8.0; // approximate

contract Recovered_cf92e7ef {
    // Runtime metadata observed by eth_call:
    // name() = "JB"; symbol() = "JB"; decimals() = 18
    // totalSupply() = 48408367382716369896047565
    //
    // Low storage slots observed on BNB mainnet:
    // slot_0  = owner/admin-like address 0xE95f3bBa0c1033EE1fEE23862C5E2897151f9635
    // slot_2  = packed fee config: low 16 bits BPS=10000, bits 16..31 sellFeeBps=300, bits 32..47 another fee=1500
    // slot_3  = totalSupply
    // slot_4  = AMM pair 0x43932cbb49c363F68655b5Ad2950ED4630CB49F8
    // slot_5  = PancakeSwap v2 router 0x10ED43C718714eb63d5aA57B78B54704E256024E
    // slot_6  = official trade/router authority 0x1B5732eB98911C25acf7BDFaffB9409782cAe6d7
    // slot_8  = auxiliary hook address 0x1B5732eB98911C25acf7BDFaffB9409782cAe6d7
    // slot_9  = address field 0x9ec62475B0FeF48B1fE31F03934E58280D838890
    // slot_10 = nodeProfile()/nodeAdd() 0x94741df7BF9dB91B172A4E195E9BeA79Ce3726cD
    // slot_11 = address field 0x06F6935D590C7448D327FbB76f0962C792ED35Ea
    // slot_12 = dead wallet 0x000000000000000000000000000000000000dEaD
    // slot_13 = address field 0x94741df7BF9dB91B172A4E195E9BeA79Ce3726cD
    //
    // Mapping storage recovered from SLOAD/SSTORE patterns:
    // slot_1  = mapping(address => bool) admins/privileged flags
    // slot_14 = mapping(address => uint256) balances
    // slot_15 = mapping(address => mapping(address => uint256)) allowances
    // slot_16 = mapping(address => bool) fee-exempt/route flags, read by isFeeExempt and 0x08f40fc0

    address private slot_0_owner;
    mapping(address => bool) private slot_1_admins;
    uint256 private slot_2_packedFees;
    uint256 private slot_3_totalSupply;
    address private slot_4_ammPair;
    address private slot_5_router;
    address private slot_6_tradeRouter;
    address private slot_7_unknownAddress;
    address private slot_8_auxHook;
    address private slot_9_unknownAddress;
    address private slot_10_nodeProfile;
    address private slot_11_unknownAddress;
    address private slot_12_deadWallet;
    address private slot_13_unknownAddress;
    mapping(address => uint256) private slot_14_balances;
    mapping(address => mapping(address => uint256)) private slot_15_allowances;
    mapping(address => bool) private slot_16_flags;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // Known topics from bytecode:
    // 0x8c5be1e5... = Approval(address,address,uint256)
    // Transfer is emitted through a CODECOPY-loaded topic, not a visible PUSH32.
    // 0xcd543d47a1acc2cdf207e879bb7db460993be51edf0bad0833e03437cff4135d is emitted after selector 0xfff6cae9 hook calls.
    // Other custom topics: 0xb64264b3..., 0xfc943c08..., 0xffeb65f7..., 0x0e227924..., 0x633693db..., 0x8d6a3816..., 0xb48ddcf2..., 0x4526a942..., 0x11b4daaa...

    modifier onlyOwnerOrAdminLike() {
        if (msg.sender != slot_0_owner && !slot_1_admins[msg.sender]) {
            // unresolved: exact revert string is packed/non-ASCII in bytecode for some admin checks.
            revert("JBToken: admin");
        }
        _;
    }

    modifier onlyTradeRouter() {
        require(msg.sender == slot_6_tradeRouter, "JBToken: not trade router");
        _;
    }

    // selector 0x06fdde03, signature from 4byte
    function name() external pure returns (string memory) {
        return "JB";
    }

    // selector 0x95d89b41, signature from 4byte
    function symbol() external pure returns (string memory) {
        return "JB";
    }

    // selector 0x313ce567, signature from ABI/4byte
    function decimals() external pure returns (uint8) {
        return 18;
    }

    // selector 0x18160ddd, signature from ABI/4byte
    function totalSupply() external view returns (uint256) {
        return slot_3_totalSupply;
    }

    // selector 0x8da5cb5b, signature from ABI/4byte
    function owner() external view returns (address) {
        return slot_0_owner;
    }

    // selector 0x1e70b7a9, signature from 4byte
    function ammPair() external view returns (address) {
        return slot_4_ammPair;
    }

    // selector 0x249d39e9, signature from 4byte
    function BPS() external view returns (uint16) {
        return uint16(slot_2_packedFees);
    }

    // selector 0x23cbe1f3, signature from 4byte
    function sellFeeBps() external view returns (uint16) {
        return uint16(slot_2_packedFees >> 16);
    }

    // selector 0x43ab4936, signature from 4byte/live eth_call
    function nodeProfile() external view returns (address) {
        return slot_10_nodeProfile;
    }

    // selector 0x5bc9a7a2, signature from 4byte/live eth_call
    function nodeAdd() external view returns (address) {
        return slot_10_nodeProfile;
    }

    // selector 0x70a08231, signature from ABI/pre-resolved
    function balanceOf(address account) external view returns (uint256) {
        return slot_14_balances[account];
    }

    // selector 0xdd62ed3e, signature from ABI/4byte
    function allowance(address owner_, address spender) external view returns (uint256) {
        return slot_15_allowances[owner_][spender];
    }

    // selector 0x095ea7b3, signature from ABI/pre-resolved
    function approve(address spender, uint256 amount) external returns (bool) {
        slot_15_allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // selector 0xa9059cbb, signature from ABI/pre-resolved
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    // selector 0x23b872dd, signature from ABI/pre-resolved
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = slot_15_allowances[from][msg.sender];
        if (currentAllowance < amount) revert("JBToken: allowance");

        unchecked {
            slot_15_allowances[from][msg.sender] = currentAllowance - amount;
        }
        emit Approval(from, msg.sender, slot_15_allowances[from][msg.sender]);

        _transfer(from, to, amount);
        return true;
    }

    // selector 0x08f40fc0, unresolved signature; argument shape recovered from calldata decoder.
    // Decodes (address account, bool routeSide) and returns three uint16 fee fields selected
    // from slot_2, unless slot_16_flags[account] suppresses them.
    function func_0x08f40fc0(address account, bool routeSide) external view returns (uint16, uint16, uint16) {
        if (slot_16_flags[account]) {
            return (0, 0, 0);
        }
        if (!routeSide) {
            return (uint16(slot_2_packedFees), 0, 0);
        }
        return (
            uint16(slot_2_packedFees),
            uint16(slot_2_packedFees >> 16),
            uint16(slot_2_packedFees >> 32)
        );
    }

    // selector 0xb1faeac6, unresolved signature; one uint256-like argument is read at calldata offset 0x04.
    // Trace-critical external call:
    //   CALL to slot_4_ammPair selector 0xfff6cae9 with calldata selector only.
    function func_0xb1faeac6(uint256 amount) external onlyTradeRouter returns (bool) {
        // The bytecode first burns `amount` from slot_4_ammPair, then calls the pair's
        // selector 0xfff6cae9. For UniswapV2/PancakeV2 pairs this selector is sync().
        _burn(slot_4_ammPair, amount);

        address pair = slot_4_ammPair;
        require(pair.code.length != 0, "JBToken: pair code");

        (bool ok, bytes memory ret) = pair.call(abi.encodeWithSelector(bytes4(0xfff6cae9)));
        if (!ok) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }

        // LOG1 topic 0xcd543d47a1acc2cdf207e879bb7db460993be51edf0bad0833e03437cff4135d
        // Data contains one 32-byte word from the surrounding stack.
        return true;
    }

    // selector 0x42966c68, signature from 4byte
    function burn(uint256 amount) external returns (bool) {
        _burn(msg.sender, amount);
        return true;
    }

    // selector 0x429b62e5, signature from 4byte
    function admins(address account) external view returns (bool) {
        return slot_1_admins[account];
    }

    // selector 0x3f4218e0, signature from 4byte
    function isFeeExempt(address account) external view returns (bool) {
        return slot_16_flags[account];
    }

    // selector 0x4b0bddd2, signature from 4byte
    function setAdmin(address account, bool enabled) external onlyOwnerOrAdminLike() returns (bool) {
        slot_1_admins[account] = enabled;
        // LOG2 topic 0x4526a942... emitted with account and enabled-like data.
        return true;
    }

    // selector 0x3c31fa62, signature from 4byte
    function setFeeRates(uint16 fee0, uint16 fee1, uint16 fee2) external onlyOwnerOrAdminLike() returns (bool) {
        require(fee0 <= 1000, "JBToken: profit too high");
        require(fee1 < 2500, "JBToken: profit too high");
        require(fee2 < 2500, "JBToken: profit too high");

        // Updates three packed uint16 fields in slot_2 and emits a custom LOG1 topic
        // 0x9d6b6311c1757be7e46d00eb801de3b57f27d77ed930a21aaf3fb03661f5bf0c.
        slot_2_packedFees =
            (slot_2_packedFees & ~uint256(0xffffffffffff)) |
            uint256(fee0) |
            (uint256(fee1) << 16) |
            (uint256(fee2) << 32);
        return true;
    }

    // selector 0x61a60d57, signature from 4byte
    function setDeadWallet(address deadWallet) external onlyOwnerOrAdminLike() returns (bool) {
        require(deadWallet != address(0), "JBToken: zero address");
        slot_12_deadWallet = deadWallet;
        // LOG3 topic 0xb48ddcf254756048b7b038c62cc51219269b4b9e3e1a1f808def50334f5121c4
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert("JBToken: zero from");
        if (to == address(0)) revert("JBToken: zero to");
        if (slot_14_balances[from] < amount) revert("JBToken: balance");

        _enforceTradeRoute(from, to);

        uint256 transferAmount = amount;
        uint256 feeAmount = _computeFee(from, to, amount);
        if (feeAmount != 0) {
            transferAmount = amount - feeAmount;
            slot_14_balances[from] -= feeAmount;
            slot_14_balances[slot_12_deadWallet] += feeAmount;
            emit Transfer(from, slot_12_deadWallet, feeAmount);
        }

        unchecked {
            slot_14_balances[from] -= transferAmount;
            slot_14_balances[to] += transferAmount;
        }
        emit Transfer(from, to, transferAmount);

        _afterTokenTransferHook(from, to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (slot_14_balances[from] < amount) revert("JBToken: burn balance");
        unchecked {
            slot_14_balances[from] -= amount;
            slot_3_totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    function _enforceTradeRoute(address from, address to) internal view {
        address pair = slot_4_ammPair;

        // Recovered branch at PC 0x1ccf:
        // - if neither side is the pair, no route restriction is applied.
        // - selling to pair requires msg.sender == slot_6_tradeRouter or msg.sender == slot_5_router,
        //   unless a slot_16 flag permits the account.
        // - buying from pair requires the official route / slot_16 flag path.
        if (to == pair && msg.sender != slot_6_tradeRouter && msg.sender != slot_5_router && !slot_16_flags[from]) {
            revert("JBToken: sell via official route");
        }
        if (from == pair && msg.sender != slot_6_tradeRouter && !slot_16_flags[to]) {
            revert("JBToken: buy via official router");
        }
    }

    function _computeFee(address from, address to, uint256 amount) internal view returns (uint256) {
        if (slot_16_flags[from] || slot_16_flags[to]) return 0;

        uint16 bps = uint16(slot_2_packedFees);
        uint16 sellBps = uint16(slot_2_packedFees >> 16);
        uint16 buyBps = uint16(slot_2_packedFees >> 32);

        if (to == slot_4_ammPair) {
            return (amount * sellBps) / bps;
        }
        if (from == slot_4_ammPair) {
            return (amount * buyBps) / bps;
        }
        return 0;
    }

    function _afterTokenTransferHook(address from, address to, uint256 amount) internal {
        amount;
        if (to == slot_4_ammPair) {
            // Multiple paths call slot_4_ammPair with selector 0xfff6cae9 and then emit topic
            // 0xcd543d47a1acc2cdf207e879bb7db460993be51edf0bad0833e03437cff4135d.
            (bool ok, bytes memory ret) = slot_4_ammPair.call(abi.encodeWithSelector(bytes4(0xfff6cae9)));
            if (!ok) {
                assembly {
                    revert(add(ret, 0x20), mload(ret))
                }
            }
        }

        if (slot_8_auxHook != address(0)) {
            // Disassembly shows calls to slot_8_auxHook with selector 0x20268daf.
            // unresolved: arguments and success handling around PC 0x0c6b/0x0cbb.
            slot_8_auxHook.call(abi.encodeWithSelector(bytes4(0x20268daf)));
        }
    }
}
