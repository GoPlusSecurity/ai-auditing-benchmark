// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IPoolManager} from "./interfaces/dex/IPoolManager.sol";

abstract contract DexBase {
    struct Config {
        address usdt;
        address usdc;
        address wbtc;
        address weth;
        address uniV3Factory;
        address uniV3PositionManager;
        address uniV3Router;
        address pancakeV3Factory;
        address pancakeV3PositionManager;
        address pancakeV3Router;
        address uniV4PoolManager;
    }

    enum Dex {
        UniswapV3,
        PancakeV3,
        UniswapV4
    }

    struct V3MintParams {
        Dex dex;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0;
        uint256 amount1;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    struct V4Position {
        IPoolManager.PoolKey key;
        int24 tickLower;
        int24 tickUpper;
        uint256 liquidity;
    }

    struct Store {
        address base;
        uint256 dexSellCap;
        uint256 dexSold;
        Config config;

        mapping(bytes32 positionId => V4Position) v4Positions;
    }

    // keccak256("dex.base.store") - 1
    bytes32 private constant STORE_SLOT = 0x61bd53f0a65728bdc7104173bbf7d4c06ffcedce7cc582891262b3e0cf8c62c6;

    event V3Minted(
        Dex indexed dex,
        uint256 indexed tokenId,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint256 liquidity,
        uint256 amount0,
        uint256 amount1
    );
    event V3Increased(Dex indexed dex, uint256 indexed tokenId, uint256 liquidity, uint256 amount0, uint256 amount1);

    event V3Decreased(
        Dex indexed dex,
        uint256 indexed tokenId,
        uint256 liquidity,
        uint256 amount0,
        uint256 amount1,
        uint256 fees0,
        uint256 fees1,
        bool burned
    );

    event V4PositionOpened(
        bytes32 indexed positionId,
        address currency0,
        address currency1,
        uint24 fee,
        int24 tickSpacing,
        int24 tickLower,
        int24 tickUpper
    );

    event V4Modified(
        bytes32 indexed positionId,
        int256 liquidityDelta,
        uint256 amount0,
        uint256 amount1,
        uint256 fees0,
        uint256 fees1
    );

    event V4PositionClosed(bytes32 indexed positionId);
    event Swapped(Dex indexed dex, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    error ZeroDexAddress();
    error ZeroDexAmount();
    error DexSellCapExceeded(uint256 sold, uint256 cap);
    error TokenNotAllowed(address token);
    error UnsortedPair(address token0, address token1);
    error SamePair(address token);
    error NotV3(Dex dex);
    error PoolNotFound();
    error HookedPool(address hooks);
    error InsufficientLiquidity(uint256 available, uint256 requested);
    error UnknownPosition(bytes32 positionId);
    error ForeignPosition(uint256 tokenId);
    error AmountExceedsMax(uint256 amount, uint256 max);
    error AmountBelowMin(uint256 amount, uint256 min);
    error NotPoolManager(address caller);
    error NotSelf(address caller);
    error AlreadyInitialized();

    function _store() internal pure returns (Store storage s) {
        assembly ("memory-safe") {
            s.slot := STORE_SLOT
        }
    }

    function isAllowedToken(address token) public view returns (bool) {
        Store storage s = _store();
        Config storage c = s.config;
        return token == s.base || token == c.usdt || token == c.usdc || token == c.wbtc || token == c.weth;
    }
}
