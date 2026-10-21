// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.21;

uint256 constant QUOTER_PRECISION = 1e18;

/// @title IPriceQuoter
/// @notice Interface for price quoters that return token prices using various sources (e.g., TWAP, Chainlink)
interface IPriceQuoter {
    /// @notice Get the price of currencyIn in terms of currencyOut
    /// @param currencyIn The input currency address
    /// @param currencyOut The output currency address
    /// @param args Additional arguments for price lookup
    /// @return price The price as currencyOut per currencyIn (scaled by 10**(QUOTER_PRECISSION - currencyIn.decimals + currencyOut.decimals))
    function getPrice(address currencyIn, address currencyOut, bytes calldata args)
        external
        view
        returns (uint256 price);
}
