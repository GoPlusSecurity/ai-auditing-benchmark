// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @dev The Uniswap v3 / PancakeSwap v3 position manager.
 */
interface INonfungiblePositionManager {
    /**
     * @dev Parameters of {mint}. `token0`, `token1` and `fee` identify the pool;
     * `tickLower`/`tickUpper` set the range; the `Desired` amounts are offered and the `Min`
     * amounts are the least the call may consume; `recipient` gets the NFT.
     */
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    /**
     * @dev Parameters of {increaseLiquidity}: the position, the amounts offered and the least
     * amounts the call may consume.
     */
    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    /**
     * @dev Parameters of {decreaseLiquidity}: the position, the liquidity to remove and the
     * least principal it must release.
     */
    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    /**
     * @dev Parameters of {collect}: the position, the receiver and caps on how much of what
     * is owed to take.
     */
    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    /**
     * @dev Creates a position and mints its NFT to `recipient`; returns the token id, the
     * liquidity and the amounts actually consumed.
     */
    function mint(
        MintParams calldata params
    ) external payable returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    /**
     * @dev Adds liquidity to an existing position. Checks no ownership: anyone paying the tokens
     * tops up whosever NFT it is — callers guard the owner themselves.
     */
    function increaseLiquidity(
        IncreaseLiquidityParams calldata params
    ) external payable returns (uint128 liquidity, uint256 amount0, uint256 amount1);

    /**
     * @dev Removes liquidity and returns the principal released; transfers nothing — the amounts
     * become owed to the position and are paid by {collect}.
     */
    function decreaseLiquidity(
        DecreaseLiquidityParams calldata params
    ) external payable returns (uint256 amount0, uint256 amount1);

    /**
     * @dev Transfers what the position is owed — released principal plus accrued fees — and
     * returns what was actually paid.
     */
    function collect(CollectParams calldata params) external payable returns (uint256 amount0, uint256 amount1);

    /**
     * @dev Burns the NFT of a position holding no liquidity and nothing owed.
     */
    function burn(uint256 tokenId) external payable;

    /**
     * @dev Returns the owner of position `tokenId` (plain ERC721).
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Returns the full book of position `tokenId`: the pool, the range, the liquidity and
     * what it is owed.
     */
    function positions(
        uint256 tokenId
    )
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );
}
