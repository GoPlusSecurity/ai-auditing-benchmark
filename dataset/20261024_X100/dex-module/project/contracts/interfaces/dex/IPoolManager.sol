// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @dev The Uniswap v4 `PoolManager`.
 */
interface IPoolManager {
    /**
     * @dev Identifies a pool: the two tokens sorted by address, the fee tier, its tick spacing
     * and the hooks contract (zero for a hookless pool).
     */
    struct PoolKey {
        address currency0;
        address currency1;
        uint24 fee;
        int24 tickSpacing;
        address hooks;
    }

    /**
     * @dev Parameters of {modifyLiquidity}: the tick range, the signed amount of liquidity to
     * add or remove, and a salt separating positions of one owner on the same range.
     */
    struct ModifyLiquidityParams {
        int24 tickLower;
        int24 tickUpper;
        int256 liquidityDelta;
        bytes32 salt;
    }

    /**
     * @dev Parameters of {swap}: `zeroForOne` picks the direction (true sells currency0),
     * `amountSpecified` is negative for exact input and positive for exact output,
     * `sqrtPriceLimitX96` is the price at which the swap stops.
     */
    struct SwapParams {
        bool zeroForOne;
        int256 amountSpecified;
        uint160 sqrtPriceLimitX96;
    }

    /**
     * @dev Opens the manager for the duration of one call to `msg.sender`'s `unlockCallback(data)`;
     * all pool operations happen inside, and every balance must be settled before it returns.
     */
    function unlock(bytes calldata data) external returns (bytes memory);

    /**
     * @dev Adds or removes liquidity. `callerDelta` is the full balance change including fees,
     * `feesAccrued` the fee part alone.
     */
    function modifyLiquidity(
        PoolKey memory key,
        ModifyLiquidityParams memory params,
        bytes calldata hookData
    ) external returns (int256 callerDelta, int256 feesAccrued);

    /**
     * @dev Swaps within one pool and returns the resulting balance delta.
     */
    function swap(PoolKey memory key, SwapParams memory params, bytes calldata hookData) external returns (int256 swapDelta);

    /**
     * @dev Snapshots the manager's balance of `currency` so the next {settle} can measure what was paid in.
     */
    function sync(address currency) external;

    /**
     * @dev Settles a debt with the tokens transferred in since {sync}; returns the amount credited.
     */
    function settle() external payable returns (uint256 paid);

    /**
     * @dev Pays out `amount` of `currency` owed to the caller.
     */
    function take(address currency, address to, uint256 amount) external;

    /**
     * @dev Reads a raw storage slot of the manager.
     */
    function extsload(bytes32 slot) external view returns (bytes32 value);
}

/**
 * @dev Implemented by callers of {IPoolManager.unlock}; the manager calls back with the same `data`.
 */
interface IUnlockCallback {
    function unlockCallback(bytes calldata data) external returns (bytes memory);
}
