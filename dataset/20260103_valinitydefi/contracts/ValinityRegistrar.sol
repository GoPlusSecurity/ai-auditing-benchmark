// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract ValinityRegistrar is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    mapping(bytes32 => address) private contracts;

    error InvalidAddress();
    error ContractNotFound();

    event RegistryUpdated(bytes32 indexed key, address indexed oldValue, address indexed newValue);

    /**
     * @dev Constructor that setup the owner of this contract.
     */
    constructor(address adminAddress) {
        if (adminAddress == address(0)) {
            revert InvalidAddress();
        }
        _grantRole(DEFAULT_ADMIN_ROLE, adminAddress);
        _grantRole(ADMIN_ROLE, adminAddress);
    }

    /**
     * @dev Check if a contract exists in the registry
     * @param key The hashed contract name (e.g., keccak256("ValinityLoanOfficer"))
     * @return Whether the contract exists
     */
    function hasContract(bytes32 key) external view returns (bool) {
        return contracts[key] != address(0);
    }

    /**
     * @dev Get contract address by key
     * @param key The hashed contract name (e.g., keccak256("ValinityLoanOfficer"))
     * @return The contract address
     */
    function getContract(bytes32 key) external view returns (address) {
        address contractAddress = contracts[key];
        if (contractAddress == address(0)) {
            revert ContractNotFound();
        }
        return contractAddress;
    }

    /**
     * @dev Set contract address by key
     * @param key The hashed contract name (e.g., keccak256("ValinityLoanOfficer"))
     * @param addr The contract address to set
     */
    function setContract(bytes32 key, address addr) external onlyRole(ADMIN_ROLE) {
        address oldValue = contracts[key];

        if (addr == address(0)) {
            revert InvalidAddress();
        }
        if (oldValue == addr) return;

        contracts[key] = addr;
        emit RegistryUpdated(key, oldValue, addr);
    }

    /**
     * @dev Remove contract from registry
     * @param key The hashed contract name (e.g., keccak256("ValinityLoanOfficer"))
     */
    function removeContract(bytes32 key) external onlyRole(ADMIN_ROLE) {
        address oldValue = contracts[key];
        if (oldValue == address(0)) {
            revert ContractNotFound();
        }
        delete contracts[key];
        emit RegistryUpdated(key, oldValue, address(0));
    }
}
