// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {DexBase} from "./DexBase.sol";
import {IUniswapV3Factory} from "./interfaces/dex/IUniswapV3Factory.sol";
import {INonfungiblePositionManager} from "./interfaces/dex/INonfungiblePositionManager.sol";
import {IV3SwapRouter} from "./interfaces/dex/IV3SwapRouter.sol";
import {IPoolManager} from "./interfaces/dex/IPoolManager.sol";

contract DexModule is DexBase {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using SafeCast for int256;

    enum V4Op {
        Modify,
        Swap
    }

    uint160 private constant MIN_SQRT_PRICE = 4295128739;
    uint160 private constant MAX_SQRT_PRICE = 1461446703485210103287273052203988822378723970342;

    uint256 private constant POOLS_SLOT = 6;

    modifier onlySelf() {
        require(msg.sender == address(this), NotSelf(msg.sender));
        _;
    }

    function init(address base, uint256 dexSellCap, Config calldata config) external {
        Store storage s = _store();
        require(s.base == address(0), AlreadyInitialized());
        require(
            base != address(0) &&
                config.usdt != address(0) &&
                config.usdc != address(0) &&
                config.wbtc != address(0) &&
                config.weth != address(0) &&
                config.uniV3Factory != address(0) &&
                config.uniV3PositionManager != address(0) &&
                config.uniV3Router != address(0) &&
                config.pancakeV3Factory != address(0) &&
                config.pancakeV3PositionManager != address(0) &&
                config.pancakeV3Router != address(0) &&
                config.uniV4PoolManager != address(0),
            ZeroDexAddress()
        );

        s.base = base;
        s.dexSellCap = dexSellCap;
        s.config = config;
    }

    function v3Mint(V3MintParams calldata p) external onlySelf returns (uint256 tokenId, uint256 liquidity) {
        (, INonfungiblePositionManager positionManager, ) = _v3(p.dex);
        _requireV3Pool(p.dex, p.token0, p.token1, p.fee);

        IERC20(p.token0).forceApprove(address(positionManager), p.amount0);
        IERC20(p.token1).forceApprove(address(positionManager), p.amount1);

        uint256 used0;
        uint256 used1;
        (tokenId, liquidity, used0, used1) = positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: p.token0,
                token1: p.token1,
                fee: p.fee,
                tickLower: p.tickLower,
                tickUpper: p.tickUpper,
                amount0Desired: p.amount0,
                amount1Desired: p.amount1,
                amount0Min: p.amount0Min,
                amount1Min: p.amount1Min,
                recipient: address(this),
                deadline: block.timestamp
            })
        );

        IERC20(p.token0).forceApprove(address(positionManager), 0);
        IERC20(p.token1).forceApprove(address(positionManager), 0);

        _countSold(p.token0, used0);
        _countSold(p.token1, used1);

        emit V3Minted(p.dex, tokenId, p.token0, p.token1, p.fee, p.tickLower, p.tickUpper, liquidity, used0, used1);
    }

    function v3Increase(
        Dex dex,
        uint256 tokenId,
        uint256 amount0,
        uint256 amount1,
        uint256 amount0Min,
        uint256 amount1Min
    ) external onlySelf returns (uint256 liquidity, uint256 used0, uint256 used1) {
        (, INonfungiblePositionManager positionManager, ) = _v3(dex);
        require(positionManager.ownerOf(tokenId) == address(this), ForeignPosition(tokenId));

        (, , address token0, address token1, , , , , , , , ) = positionManager.positions(tokenId);
        _requirePair(token0, token1);

        IERC20(token0).forceApprove(address(positionManager), amount0);
        IERC20(token1).forceApprove(address(positionManager), amount1);

        (liquidity, used0, used1) = positionManager.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: amount0Min,
                amount1Min: amount1Min,
                deadline: block.timestamp
            })
        );

        IERC20(token0).forceApprove(address(positionManager), 0);
        IERC20(token1).forceApprove(address(positionManager), 0);

        _countSold(token0, used0);
        _countSold(token1, used1);

        emit V3Increased(dex, tokenId, liquidity, used0, used1);
    }

    function v3Decrease(
        Dex dex,
        uint256 tokenId,
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min
    ) external onlySelf returns (uint256 amount0, uint256 amount1, uint256 fees0, uint256 fees1) {
        (, INonfungiblePositionManager positionManager, ) = _v3(dex);

        (, , address token0, address token1, , , , uint128 total, , , , ) = positionManager.positions(tokenId);
        _requirePair(token0, token1);
        require(liquidity <= total, InsufficientLiquidity(total, liquidity));

        if (liquidity != 0) {
            (amount0, amount1) = positionManager.decreaseLiquidity(
                INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: liquidity.toUint128(),
                    amount0Min: amount0Min,
                    amount1Min: amount1Min,
                    deadline: block.timestamp
                })
            );
            _countBought(token0, amount0);
            _countBought(token1, amount1);
        }

        (fees0, fees1) = positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        fees0 = fees0 > amount0 ? fees0 - amount0 : 0;
        fees1 = fees1 > amount1 ? fees1 - amount1 : 0;

        bool burned = liquidity == total && total != 0;
        if (burned) {
            positionManager.burn(tokenId);
        }

        emit V3Decreased(dex, tokenId, liquidity, amount0, amount1, fees0, fees1, burned);
    }

    function v3Swap(
        Dex dex,
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) external onlySelf returns (uint256 amountOut) {
        require(amountIn != 0, ZeroDexAmount());
        (, , IV3SwapRouter router) = _v3(dex);
        (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);
        _requireV3Pool(dex, token0, token1, fee);

        uint256 before = IERC20(tokenIn).balanceOf(address(this));
        IERC20(tokenIn).forceApprove(address(router), amountIn);

        amountOut = router.exactInputSingle(
            IV3SwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee,
                recipient: address(this),
                amountIn: amountIn,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: 0
            })
        );

        IERC20(tokenIn).forceApprove(address(router), 0);
        uint256 spent = before - IERC20(tokenIn).balanceOf(address(this));

        _countSold(tokenIn, spent);
        _countBought(tokenOut, amountOut);

        emit Swapped(dex, tokenIn, tokenOut, spent, amountOut);
    }

    function v4Increase(
        IPoolManager.PoolKey calldata key,
        int24 tickLower,
        int24 tickUpper,
        uint256 liquidity,
        uint256 amount0Max,
        uint256 amount1Max
    ) external onlySelf returns (bytes32 positionId, uint256 amount0, uint256 amount1) {
        require(liquidity != 0, ZeroDexAmount());
        _requireV4Pool(key);

        uint256 fees0;
        uint256 fees1;
        (amount0, amount1, fees0, fees1) = _v4Modify(key, tickLower, tickUpper, liquidity.toInt256(), amount0Max, amount1Max);

        positionId = _positionId(key, tickLower, tickUpper);
        _open(positionId, key, tickLower, tickUpper);
        _store().v4Positions[positionId].liquidity += liquidity;

        _countSold(key.currency0, amount0);
        _countSold(key.currency1, amount1);

        emit V4Modified(positionId, liquidity.toInt256(), amount0, amount1, fees0, fees1);
    }

    function v4Decrease(
        bytes32 positionId,
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min
    ) external onlySelf returns (uint256 amount0, uint256 amount1) {
        Store storage s = _store();
        V4Position memory position = s.v4Positions[positionId];
        require(position.liquidity != 0, UnknownPosition(positionId));
        require(liquidity <= position.liquidity, InsufficientLiquidity(position.liquidity, liquidity));

        uint256 fees0;
        uint256 fees1;
        (amount0, amount1, fees0, fees1) = _v4Modify(
            position.key,
            position.tickLower,
            position.tickUpper,
            -liquidity.toInt256(),
            amount0Min,
            amount1Min
        );

        _countBought(position.key.currency0, amount0);
        _countBought(position.key.currency1, amount1);

        if (liquidity == position.liquidity) {
            delete s.v4Positions[positionId];
            emit V4PositionClosed(positionId);
        } else {
            s.v4Positions[positionId].liquidity -= liquidity;
        }

        emit V4Modified(positionId, -liquidity.toInt256(), amount0, amount1, fees0, fees1);
    }

    function v4Swap(
        IPoolManager.PoolKey calldata key,
        bool zeroForOne,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) external onlySelf returns (uint256 amountOut) {
        require(amountIn != 0, ZeroDexAmount());
        _requireV4Pool(key);

        bytes memory result = _poolManager().unlock(
            abi.encode(V4Op.Swap, abi.encode(key, zeroForOne, amountIn, amountOutMinimum))
        );

        uint256 spent;
        (spent, amountOut) = abi.decode(result, (uint256, uint256));

        (address tokenIn, address tokenOut) = zeroForOne
            ? (key.currency0, key.currency1)
            : (key.currency1, key.currency0);

        _countSold(tokenIn, spent);
        _countBought(tokenOut, amountOut);

        emit Swapped(Dex.UniswapV4, tokenIn, tokenOut, spent, amountOut);
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        IPoolManager poolManager = _poolManager();
        require(msg.sender == address(poolManager), NotPoolManager(msg.sender));

        (V4Op op, bytes memory payload) = abi.decode(data, (V4Op, bytes));

        if (op == V4Op.Modify) {
            return _modifyInsideUnlock(poolManager, payload);
        }
        return _swapInsideUnlock(poolManager, payload);
    }

    function _modifyInsideUnlock(IPoolManager poolManager, bytes memory payload) private returns (bytes memory) {
        (
            IPoolManager.PoolKey memory key,
            int24 tickLower,
            int24 tickUpper,
            int256 liquidityDelta,
            uint256 bound0,
            uint256 bound1
        ) = abi.decode(payload, (IPoolManager.PoolKey, int24, int24, int256, uint256, uint256));

        (int256 delta, int256 fees) = poolManager.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: liquidityDelta,
                salt: bytes32(0)
            }),
            ""
        );

        (int256 delta0, int256 delta1) = _split(delta);
        _settle(poolManager, key.currency0, delta0);
        _settle(poolManager, key.currency1, delta1);

        return _bounded(delta, fees, liquidityDelta, bound0, bound1);
    }

    function _bounded(
        int256 delta,
        int256 fees,
        int256 liquidityDelta,
        uint256 bound0,
        uint256 bound1
    ) private pure returns (bytes memory) {
        (int256 delta0, int256 delta1) = _split(delta);
        (int256 fees0, int256 fees1) = _split(fees);
        int256 principal0 = delta0 - fees0;
        int256 principal1 = delta1 - fees1;

        uint256 amount0;
        uint256 amount1;
        if (liquidityDelta > 0) {
            amount0 = principal0 < 0 ? uint256(-principal0) : 0;
            amount1 = principal1 < 0 ? uint256(-principal1) : 0;
            require(amount0 <= bound0, AmountExceedsMax(amount0, bound0));
            require(amount1 <= bound1, AmountExceedsMax(amount1, bound1));
        } else {
            amount0 = principal0 > 0 ? uint256(principal0) : 0;
            amount1 = principal1 > 0 ? uint256(principal1) : 0;
            require(amount0 >= bound0, AmountBelowMin(amount0, bound0));
            require(amount1 >= bound1, AmountBelowMin(amount1, bound1));
        }
        return abi.encode(amount0, amount1, uint256(fees0), uint256(fees1));
    }

    function _swapInsideUnlock(IPoolManager poolManager, bytes memory payload) private returns (bytes memory) {
        (IPoolManager.PoolKey memory key, bool zeroForOne, uint256 amountIn, uint256 amountOutMinimum) = abi.decode(
            payload,
            (IPoolManager.PoolKey, bool, uint256, uint256)
        );

        int256 delta = poolManager.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -amountIn.toInt256(),
                sqrtPriceLimitX96: zeroForOne ? MIN_SQRT_PRICE + 1 : MAX_SQRT_PRICE - 1
            }),
            ""
        );

        (int256 delta0, int256 delta1) = _split(delta);
        _settle(poolManager, key.currency0, delta0);
        _settle(poolManager, key.currency1, delta1);

        (int256 inDelta, int256 outDelta) = zeroForOne ? (delta0, delta1) : (delta1, delta0);
        uint256 spent = inDelta < 0 ? uint256(-inDelta) : 0;
        uint256 amountOut = outDelta > 0 ? uint256(outDelta) : 0;
        require(amountOut >= amountOutMinimum, AmountBelowMin(amountOut, amountOutMinimum));
        return abi.encode(spent, amountOut);
    }

    function _v3(Dex dex) private view returns (IUniswapV3Factory, INonfungiblePositionManager, IV3SwapRouter) {
        Config storage c = _store().config;
        if (dex == Dex.UniswapV3) {
            return (
                IUniswapV3Factory(c.uniV3Factory),
                INonfungiblePositionManager(c.uniV3PositionManager),
                IV3SwapRouter(c.uniV3Router)
            );
        }
        if (dex == Dex.PancakeV3) {
            return (
                IUniswapV3Factory(c.pancakeV3Factory),
                INonfungiblePositionManager(c.pancakeV3PositionManager),
                IV3SwapRouter(c.pancakeV3Router)
            );
        }
        revert NotV3(dex);
    }

    function _countSold(address token, uint256 amount) private {
        Store storage s = _store();
        if (token != s.base || amount == 0) {
            return;
        }
        uint256 sold = s.dexSold + amount;
        require(sold <= s.dexSellCap, DexSellCapExceeded(sold, s.dexSellCap));
        s.dexSold = sold;
    }

    function _countBought(address token, uint256 amount) private {
        Store storage s = _store();
        if (token != s.base || amount == 0) {
            return;
        }
        uint256 sold = s.dexSold;
        s.dexSold = amount >= sold ? 0 : sold - amount;
    }

    function _poolManager() private view returns (IPoolManager) {
        return IPoolManager(_store().config.uniV4PoolManager);
    }

    function _requirePair(address token0, address token1) private view {
        require(isAllowedToken(token0), TokenNotAllowed(token0));
        require(isAllowedToken(token1), TokenNotAllowed(token1));
        require(token0 != token1, SamePair(token0));
        require(token0 < token1, UnsortedPair(token0, token1));
    }

    function _requireV3Pool(Dex dex, address token0, address token1, uint24 fee) private view {
        _requirePair(token0, token1);
        (IUniswapV3Factory factory, , ) = _v3(dex);
        require(factory.getPool(token0, token1, fee) != address(0), PoolNotFound());
    }

    function _requireV4Pool(IPoolManager.PoolKey calldata key) private view {
        require(key.hooks == address(0), HookedPool(key.hooks));
        _requirePair(key.currency0, key.currency1);

        bytes32 poolId = keccak256(abi.encode(key));
        bytes32 slot0 = _poolManager().extsload(keccak256(abi.encodePacked(poolId, POOLS_SLOT)));
        require(uint160(uint256(slot0)) != 0, PoolNotFound());
    }

    function _v4Modify(
        IPoolManager.PoolKey memory key,
        int24 tickLower,
        int24 tickUpper,
        int256 liquidityDelta,
        uint256 bound0,
        uint256 bound1
    ) private returns (uint256 amount0, uint256 amount1, uint256 fees0, uint256 fees1) {
        bytes memory result = _poolManager().unlock(
            abi.encode(V4Op.Modify, abi.encode(key, tickLower, tickUpper, liquidityDelta, bound0, bound1))
        );
        return abi.decode(result, (uint256, uint256, uint256, uint256));
    }

    function _settle(IPoolManager poolManager, address currency, int256 amount) private {
        if (amount < 0) {
            poolManager.sync(currency);
            IERC20(currency).safeTransfer(address(poolManager), uint256(-amount));
            poolManager.settle();
        } else if (amount > 0) {
            poolManager.take(currency, address(this), uint256(amount));
        }
    }

    function _open(bytes32 positionId, IPoolManager.PoolKey calldata key, int24 tickLower, int24 tickUpper) private {
        V4Position storage position = _store().v4Positions[positionId];
        if (position.liquidity != 0) {
            return;
        }
        position.key = key;
        position.tickLower = tickLower;
        position.tickUpper = tickUpper;
        emit V4PositionOpened(positionId, key.currency0, key.currency1, key.fee, key.tickSpacing, tickLower, tickUpper);
    }

    function _positionId(
        IPoolManager.PoolKey memory key,
        int24 tickLower,
        int24 tickUpper
    ) private pure returns (bytes32) {
        return keccak256(abi.encode(key, tickLower, tickUpper));
    }

    function _split(int256 delta) private pure returns (int256 amount0, int256 amount1) {
        amount0 = int256(int128(delta >> 128));
        amount1 = int256(int128(delta));
    }
}
