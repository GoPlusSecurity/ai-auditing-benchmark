// SPDX-License-Identifier: UNLICENSED
// DECOMPILED APPROXIMATION, NOT VERIFIED ORIGINAL SOURCE. See SOURCE.md.
// Selected declarations retain their published recovered bodies.

pragma solidity ^0.8.0;

contract Recovered_cf92e7ef {

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

    modifier onlyTradeRouter() {
        require(msg.sender == slot_6_tradeRouter, "JBToken: not trade router");
        _;
    }

    function totalSupply() external view returns (uint256) {
        return slot_3_totalSupply;
    }

    function ammPair() external view returns (address) {
        return slot_4_ammPair;
    }

    function balanceOf(address account) external view returns (uint256) {
        return slot_14_balances[account];
    }

    function func_0xb1faeac6(uint256 amount) external onlyTradeRouter returns (bool) {


        _burn(slot_4_ammPair, amount);

        address pair = slot_4_ammPair;
        require(pair.code.length != 0, "JBToken: pair code");

        (bool ok, bytes memory ret) = pair.call(abi.encodeWithSelector(bytes4(0xfff6cae9)));
        if (!ok) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }



        return true;
    }

    function _burn(address from, uint256 amount) internal {
        if (slot_14_balances[from] < amount) revert("JBToken: burn balance");
        unchecked {
            slot_14_balances[from] -= amount;
            slot_3_totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }
}
