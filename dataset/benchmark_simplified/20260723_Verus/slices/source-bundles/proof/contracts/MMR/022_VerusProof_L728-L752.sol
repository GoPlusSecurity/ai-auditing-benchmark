    function getLastConfirmedVRSCStateRoot() public view returns (bytes32) {

        bytes storage tempArray = bestForks[0];
        if (tempArray.length == 0)
        {
            return bytes32(0);
        }

        bytes32 stateRoot;
        uint32 height;
        bytes32 slot;

        assembly {
                    mstore(add(slot, 32),tempArray.slot)
                    height := shr(FORKS_DATA_OFFSET_FOR_HEIGHT, sload(add(keccak256(add(slot, 32), 32), FORKS_PROPOSER_SLOT)))
        }
        tempArray = proofs[bytes32(uint256(height))];

        assembly {
                mstore(add(slot, 32),tempArray.slot)
                stateRoot := sload(add(keccak256(add(slot, 32), 32), 0))
        }

        return stateRoot;
    }
