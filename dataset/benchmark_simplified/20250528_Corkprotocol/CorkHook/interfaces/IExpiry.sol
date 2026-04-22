// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title IExpiry Interface
 * @author Cork Team
 * @notice Minimal IExpiry interface. Intentionally does NOT inherit any IErrors interface to avoid
 * name collisions with this project's own `IErrors`.
 */
interface IExpiry {
    /// @notice returns true if the asset is expired
    function isExpired() external view returns (bool);

    /// @notice returns the expiry timestamp if 0 then it means it never expires
    function expiry() external view returns (uint256);

    /// @notice returns the timestamp when the asset was issued
    function issuedAt() external view returns (uint256);
}

