interface IPancakeFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IPancakeRouter {
    function factory() external view returns (address);
    function WETH() external view returns (address);
}

interface IPancakePair {
    function token0() external view returns (address);
    function token1() external view returns (address);

    function getReserves() external view returns (
        uint112 reserve0,
        uint112 reserve1,
        uint32 blockTimestampLast
    );

    function sync() external;
}
