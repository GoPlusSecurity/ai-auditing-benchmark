pragma solidity ^0.8.20;

import {IErrors} from "./IErrors.sol";

interface ICorkHook is IErrors {
    function swap(address ra, address ct, uint256 amountRaOut, uint256 amountCtOut, bytes calldata data)
        external
        returns (uint256 amountIn);

    event Swapped(
        address indexed input,
        address indexed output,
        uint256 amountIn,
        uint256 amountOut,
        address indexed who,
        uint256 baseFeePercentage,
        uint256 realizedFeePercentage,
        uint256 realizedFeeAmount
    );
}
