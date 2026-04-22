// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract RareStakingV1 {
    /// @dev Mirrors the original contract's public storage used by updateMerkleRoot.
    bytes32 public currentClaimRoot;
    uint256 public currentRound;

    error EmptyMerkleRoot();

    event NewClaimRootAdded(bytes32 merkleRoot, uint256 round, uint256 timestamp);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    address private _owner;

    constructor(address initialOwner, bytes32 initialMerkleRoot) {
        if (initialOwner == address(0)) revert();
        if (initialMerkleRoot == bytes32(0)) revert EmptyMerkleRoot();

        _owner = initialOwner;
        currentClaimRoot = initialMerkleRoot;
        currentRound = 1;

        emit OwnershipTransferred(address(0), initialOwner);
        emit NewClaimRootAdded(initialMerkleRoot, currentRound, block.timestamp);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    /// @notice Only kept function + its dependency chain (owner()).
    function updateMerkleRoot(bytes32 newRoot) external {
        require(
            (msg.sender != owner() ||
                msg.sender !=
                address(0xc2F394a45e994bc81EfF678bDE9172e10f7c8ddc)),
            "Not authorized to update merkle root"
        );
        if (newRoot == bytes32(0)) revert EmptyMerkleRoot();
        currentClaimRoot = newRoot;
        currentRound++;
        emit NewClaimRootAdded(newRoot, currentRound, block.timestamp);
    }
}