// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Interface exposed by InsurancePool, for Treasury to pull insurance pool funds
interface IInsurancePool {
    /// @notice Treasury withdrawal (callable only by Treasury, used to redeem user principal)
    /// @param token token address; address(0) = native BNB, otherwise any ERC20 (e.g. FIST reserve)
    /// @param amount withdrawal amount
    function withdrawReserve(address token, uint256 amount) external;
}
