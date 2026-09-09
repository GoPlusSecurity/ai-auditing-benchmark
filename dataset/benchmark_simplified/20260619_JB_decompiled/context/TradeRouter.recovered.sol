// SPDX-License-Identifier: UNLICENSED
// Recovered by Decompiler Agent - NOT verified source code
// Contract: 0x1b5732eb98911c25acf7bdfaffb9409782cae6d7
// Method: agent-native decompilation from disassembly
// Confidence: low
// Selectors covered: 2/2

pragma solidity ^0.8.0; // approximate

interface IERC20Like {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IPancakeRouterLike {
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IParentControllerLike {
    // signature from cast 4byte
    function parent(address account) external view returns (address);

    // signature unresolved; observed calldata is selector + (address account, uint256 amount)
    function func_0x727ebe6d(address account, uint256 amount) external;

    // signature unresolved; observed calldata is selector + (address account, uint256 amount)
    function func_0x0e2aa265(address account, uint256 amount) external;
}

interface IReserveHelperLike {
    // signature from cast 4byte
    function updatePrice() external returns (uint256);
}

interface IJBTokenLike is IERC20Like {
    // selector 0x08f40fc0 is unresolved; trace returns three uint256 fee/config fields.
    function func_0x08f40fc0(address account, uint256 side) external view returns (uint256, uint256, uint256);

    // selector 0xb1faeac6 is unresolved; trace calls it after JB->USDT swap legs.
    function func_0xb1faeac6(uint256 amount) external;
}

abstract contract Recovered_1b5732eb {
    // Constant addresses embedded in bytecode.
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant JB_TOKEN = 0xcF92E7eF4A63D52dc15F45A24f4F815f00f299a7;
    address constant PANCAKE_ROUTER_FROM_TRACE = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address constant RESERVE_HELPER_FROM_TRACE = 0x06F6935D590C7448D327Fbb76F0962c792eD35eA;

    // Storage recovered from SLOAD/SSTORE sites.
    // slot 0: owner address
    address owner;

    // slot 1: mapping(address => bool), used as privileged/admin bitmap.
    mapping(address => bool) admins;

    // slot 2: low byte is reentrancy/status flag; bytes [1..20] hold pancakeRouter().
    bytes32 slot_02_packed_lock_and_router;

    // slot 3: ammPair()
    address ammPair;

    // slot 4: helper contract called with updatePrice().
    IReserveHelperLike reserveHelper;

    // slots 5, 6, 7, 8: parent/controller-style addresses. In current storage all equal
    // 0x94741df7bf9db91b172a4e195e9bea79ce3726cd; traced functions use them for
    // parent(), func_0x727ebe6d(), and func_0x0e2aa265().
    IParentControllerLike parentRegistry;
    IParentControllerLike parentControllerA;
    IParentControllerLike parentControllerB;
    IParentControllerLike parentControllerC;

    // slot 9: packed fee/config data. Low 160 bits decode to 0x28301fe4f3cc1f4f6da2ec2c6a7bb9c291cf6eb0.
    bytes32 slot_09_packed_fee_config;

    // slots 10-19: fee bps, thresholds, pool burn controls, and timestamps.
    bytes32 slot_10_packed_limits;
    uint256 burnInterval;      // slot 11
    uint256 lastPoolBurnAt;    // slot 12
    uint256 poolBurnCounter;   // slot 13
    uint256 slot_14_limit;
    uint256 slot_15_limit;
    bool poolBurnEnabled;      // slot 16, low byte

    // slot 17: mapping(address => bool), trade blacklist checked by traced entrypoints.
    mapping(address => bool) tradeBlacklist;

    // slot 20 and slot 21: traced functions update caller accounting.
    mapping(address => uint256) totalBuyUsdt;
    mapping(address => uint256) totalSellUsdt;

    event UnknownTradeEvent(bytes32 indexed topic, address indexed caller, uint256 amount0, uint256 amount1, uint256 amount2);

    modifier nonReentrantLike() {
        // SLOAD slot 2 low byte; revert if already set; set to 1 and clear before return.
        require((uint8(uint256(slot_02_packed_lock_and_router)) & 0xff) == 0, "reentrant");
        slot_02_packed_lock_and_router =
            bytes32((uint256(slot_02_packed_lock_and_router) & ~uint256(0xff)) | 1);
        _;
        slot_02_packed_lock_and_router =
            bytes32(uint256(slot_02_packed_lock_and_router) & ~uint256(0xff));
    }

    function pancakeRouter() public view returns (address) {
        // signature from cast 4byte; slot 2 shifted right by 8 bits.
        return address(uint160(uint256(slot_02_packed_lock_and_router) >> 8));
    }

    function feeWallet() internal view returns (address) {
        return address(uint160(uint256(slot_09_packed_fee_config)));
    }

    function _path(address tokenIn, address tokenOut) internal pure returns (address[] memory path) {
        path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
    }

    function _requireActiveCaller(uint256 deadline) internal view {
        // STATICCALL to parentRegistry.parent(msg.sender), selector 0xf1f9d8c9.
        address parent = parentRegistry.parent(msg.sender);
        require(parent != address(0), "JBTradeRouter: must bind parent");

        // mapping(address => bool) at slot 17; low byte true means blacklisted.
        require(!tradeBlacklist[msg.sender], "JBTradeRouter: trade blacklisted");
        require(deadline >= block.timestamp, "JBTradeRouter: expired");
    }

    function _safeApprove(address token, address spender, uint256 amount) internal {
        // Bytecode uses approve(spender, 0) before non-zero approve and validates boolean returns.
        bool okZero = IERC20Like(token).approve(spender, 0);
        require(okZero, "JBTradeRouter: approve zero failed");

        if (amount != 0) {
            bool ok = IERC20Like(token).approve(spender, amount);
            require(ok, "JBTradeRouter: approve failed");
        }
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        bool ok = IERC20Like(token).transfer(to, amount);
        require(ok, "SafeToken: transfer failed");
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        bool ok = IERC20Like(token).transferFrom(from, to, amount);
        require(ok, "SafeToken: transferFrom failed");
    }

    function _syncControllerWithJB(uint256 grossJbAmount, uint256 secondaryAmount) internal {
        // All calls below are visible in trace against 0x94741df7bf9db91b172a4e195e9bea79ce3726cd.
        _safeApprove(JB_TOKEN, address(parentControllerC), grossJbAmount);
        parentControllerC.func_0x727ebe6d(address(this), grossJbAmount);
        _safeApprove(JB_TOKEN, address(parentControllerC), 0);

        _safeApprove(JB_TOKEN, address(parentControllerC), secondaryAmount);
        parentControllerC.func_0x0e2aa265(address(this), secondaryAmount);
        _safeApprove(JB_TOKEN, address(parentControllerC), 0);
    }

    function _maybePoolBurn(uint256 amount) internal {
        if (!poolBurnEnabled) {
            lastPoolBurnAt = block.timestamp; // observed fallback path only updates slot 12
            return;
        }

        // The bytecode also reads totalSupply(), ammPair balance, slot_0d/slot_0f thresholds,
        // writes slot 0x0c/0x0d, and calls an unresolved JB-token selector 0xb1faeac6.
        // The trace shows 0xb1faeac6(uint256) once per repeated 0x53a9fcbc leg.
        IJBTokenLike(JB_TOKEN).func_0xb1faeac6(amount);
        lastPoolBurnAt = block.timestamp;
    }

    // selector 0xd680aabd
    // signature source: unresolved selector; inferred from trace calldata as
    // func_0xd680aabd(uint256 amountInUsdt, uint256 minOut, uint256 deadline).
    function func_0xd680aabd(uint256 amountInUsdt, uint256 minOut, uint256 deadline)
        external
        nonReentrantLike
        returns (uint256 jbReturned)
    {
        _requireActiveCaller(deadline);

        // CALL to reserve helper selector 0x673a7e28 before route execution.
        reserveHelper.updatePrice();

        uint256 usdtBefore = IERC20Like(USDT).balanceOf(address(this));
        uint256 jbBefore = IERC20Like(JB_TOKEN).balanceOf(address(this));

        _safeTransferFrom(USDT, msg.sender, address(this), amountInUsdt);
        uint256 receivedUsdt = IERC20Like(USDT).balanceOf(address(this)) - usdtBefore;
        require(receivedUsdt != 0, "JBTradeRouter: zero operation");

        _safeApprove(USDT, pancakeRouter(), receivedUsdt);
        IPancakeRouterLike(pancakeRouter()).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            receivedUsdt,
            minOut,
            _path(USDT, JB_TOKEN),
            address(this),
            deadline
        );
        _safeApprove(USDT, pancakeRouter(), 0);

        uint256 jbAfterSwap = IERC20Like(JB_TOKEN).balanceOf(address(this));
        uint256 boughtJb = jbAfterSwap - jbBefore;
        require(boughtJb != 0, "JBTradeRouter: zero operation");

        // The disassembly splits boughtJb into controller amounts and a fee transfer.
        // Exact arithmetic is complex; all observed external calls are preserved below.
        (uint256 parentAmount, uint256 secondaryAmount, uint256 feeAmount, uint256 userAmount) =
            _splitAmountsForControllerAndFee(boughtJb, true);

        _syncControllerWithJB(parentAmount, secondaryAmount);

        if (feeAmount != 0) {
            _safeTransfer(JB_TOKEN, feeWallet(), feeAmount);
        }

        jbReturned = userAmount;
        _safeTransfer(JB_TOKEN, msg.sender, jbReturned);

        totalBuyUsdt[msg.sender] += receivedUsdt;
        emit UnknownTradeEvent(
            0x0037e9e7c7bd732a5d744d98866d18d0cf3f0a1fced0bd21ec5f2439cc8a416d,
            msg.sender,
            receivedUsdt,
            boughtJb,
            jbReturned
        );

        // CALL to reserve helper selector 0x673a7e28 after route execution.
        reserveHelper.updatePrice();
        return jbReturned;
    }

    // selector 0x53a9fcbc
    // signature source: unresolved selector; inferred from trace calldata as
    // func_0x53a9fcbc(uint256 amountInJb, uint256 minOut, uint256 deadline).
    function func_0x53a9fcbc(uint256 amountInJb, uint256 minOut, uint256 deadline)
        external
        nonReentrantLike
        returns (uint256 usdtReturned)
    {
        _requireActiveCaller(deadline);

        // CALL to reserve helper selector 0x673a7e28 before route execution.
        reserveHelper.updatePrice();

        // STATICCALL to JB token selector 0x08f40fc0(msg.sender, 1) appears twice in this path.
        (uint256 feeA, uint256 feeB, uint256 feeC) = IJBTokenLike(JB_TOKEN).func_0x08f40fc0(msg.sender, 1);
        (feeA, feeB, feeC);

        // STATICCALL to Pancake router getAmountsOut(amountInJb, [JB, USDT]).
        uint256[] memory quoted = IPancakeRouterLike(pancakeRouter()).getAmountsOut(
            amountInJb,
            _path(JB_TOKEN, USDT)
        );
        require(quoted.length >= 2, "JBTradeRouter: router quote");

        uint256 usdtBefore = IERC20Like(USDT).balanceOf(address(this));
        _safeTransferFrom(JB_TOKEN, msg.sender, address(this), amountInJb);

        (uint256 parentAmount, uint256 secondaryAmount, uint256 feeAmount, uint256 swapAmount) =
            _splitAmountsForControllerAndFee(amountInJb, false);

        _syncControllerWithJB(parentAmount, secondaryAmount);

        if (feeAmount != 0) {
            _safeTransfer(JB_TOKEN, feeWallet(), feeAmount);
        }

        _safeApprove(JB_TOKEN, pancakeRouter(), swapAmount);
        IPancakeRouterLike(pancakeRouter()).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            swapAmount,
            minOut,
            _path(JB_TOKEN, USDT),
            address(this),
            deadline
        );
        _safeApprove(JB_TOKEN, pancakeRouter(), 0);

        uint256 usdtAfter = IERC20Like(USDT).balanceOf(address(this));
        usdtReturned = usdtAfter - usdtBefore;
        require(usdtReturned != 0, "JBTradeRouter: zero operation");

        _safeTransfer(USDT, msg.sender, usdtReturned);

        // The amount passed to 0xb1faeac6 is derived from current route/accounting state.
        // The trace shows one call per repeated 0x53a9fcbc leg.
        _maybePoolBurn(_derivePoolBurnAmount(amountInJb, swapAmount));

        totalSellUsdt[msg.sender] += usdtReturned;
        emit UnknownTradeEvent(
            // Pad to 32 bytes: the traced literal was 31 bytes; leading bytes are unrecoverable.
            0x0037e9e7c7bd732a5d744d98866d18d0cf3f0a1fced0bd21ec5f2439cc8a416d,
            msg.sender,
            amountInJb,
            swapAmount,
            usdtReturned
        );

        // CALL to reserve helper selector 0x673a7e28 after route execution.
        reserveHelper.updatePrice();
        return usdtReturned;
    }

    function _splitAmountsForControllerAndFee(uint256 amount, bool buySide)
        internal
        view
        returns (uint256 parentAmount, uint256 secondaryAmount, uint256 feeAmount, uint256 userOrSwapAmount)
    {
        // unresolved: exact arithmetic spans PCs 0x0adc..0x0b44 and 0x18cf..0x1983.
        // It uses fee/config values packed in slot 9 and slot 10 and emits a LOG3 trade event.
        // The recovered function preserves the resulting external-call shape:
        // approve -> parent 0x727ebe6d -> approve reset -> approve -> parent 0x0e2aa265
        // -> fee-wallet transfer -> user/router leg.
        // Pseudocode assignment only: these values are produced by unresolved arithmetic in the
        // bytecode, not by a recovered Solidity expression.
        (parentAmount, secondaryAmount, feeAmount, userOrSwapAmount) =
            _unresolvedFeeSplitFromPackedConfig(amount, buySide, slot_09_packed_fee_config, slot_10_packed_limits);
    }

    function _derivePoolBurnAmount(uint256 amountInJb, uint256 swapAmount) internal pure returns (uint256) {
        // unresolved: bytecode uses totalSupply(), ammPair balance, packed basis points, and counters.
        return _unresolvedPoolBurnAmount(amountInJb, swapAmount);
    }

    function _unresolvedFeeSplitFromPackedConfig(uint256 amount, bool buySide, bytes32 packed9, bytes32 packed10)
        internal
        pure
        virtual
        returns (uint256 parentAmount, uint256 secondaryAmount, uint256 feeAmount, uint256 userOrSwapAmount);

    function _unresolvedPoolBurnAmount(uint256 amountInJb, uint256 swapAmount)
        internal
        pure
        virtual
        returns (uint256 burnAmount);
    

    // Additional dispatcher selectors exist in the runtime but were not trace-selected for recovery.
    // Examples resolved by cast 4byte include:
    // owner(), transferOwnership(address), setAdmin(address,bool), admins(address),
    // pancakeRouter(), ammPair(), jbToken(), usdt(), poolBurnEnabled(), lastPoolBurnAt(),
    // setPancakeConfig(address,address), setTaxWallets(address,address), triggerPoolBurn(),
    // rescueToken(address,address,uint256), totalBuyUsdt(address), totalSellUsdt(address).
}
