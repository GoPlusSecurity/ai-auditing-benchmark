// SPDX-License-Identifier: GPL-2.0-only

pragma solidity >=0.6.10 <0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";

import {IVerifier} from "./interfaces/IVerifier.sol";

import {IRollupProcessor} from "./interfaces/IRollupProcessor.sol";

import {Decoder} from "./Decoder.sol";

import './libraries/RollupProcessorLibrary.sol';

contract RollupProcessor is IRollupProcessor, Decoder, Ownable, Pausable {
    using SafeMath for uint256;

    bytes32 public dataRoot = 0x2708a627d38d74d478f645ec3b4e91afa325331acf1acebe9077891146b75e39;

    bytes32 public nullRoot = 0x2694dbe3c71a25d92213422d392479e7b8ef437add81e1e17244462e6edca9b1;

    bytes32 public rootRoot = 0x2d264e93dc455751a721aead9dba9ee2a9fef5460921aeede73f63f6210e6851;

    uint256 public dataSize;

    uint256 public nextRollupId;

    IVerifier public verifier;

    uint256 public constant numberOfAssets = 4;

    uint256 public constant txNumPubInputs = 12;

    uint256 public constant rollupNumPubInputs = 10 + numberOfAssets;

    uint256 public constant txPubInputLength = txNumPubInputs * 32;

    uint256 public constant rollupPubInputLength = rollupNumPubInputs * 32;

    uint256 public constant ethAssetId = 0;

    uint256 public immutable escapeBlockLowerBound;

    uint256 public immutable escapeBlockUpperBound;

    event RollupProcessed(
        uint256 indexed rollupId,
        bytes32 dataRoot,
        bytes32 nullRoot,
        bytes32 rootRoot,
        uint256 dataSize
    );

    event Deposit(uint256 assetId, address depositorAddress, uint256 depositValue);

    event Withdraw(uint256 assetId, address withdrawAddress, uint256 withdrawValue);

    event WithdrawError(bytes errorReason);

    event AssetAdded(uint256 indexed assetId, address indexed assetAddress);

    event RollupProviderUpdated(address indexed providerAddress, bool valid);

    event VerifierUpdated(address indexed verifierAddress);

    address[] public supportedAssets;

    mapping(address => bool) assetPermitSupport;

    mapping(uint256 => mapping(address => uint256)) public userPendingDeposits;

    mapping(address => mapping(bytes32 => bool)) public depositProofApprovals;

    mapping(address => bool) public rollupProviders;

    address public override feeDistributor;

    uint256[] public totalPendingDeposit;

    uint256[] public totalDeposited;

    uint256[] public totalWithdrawn;

    uint256[] public totalFees;

    constructor(
        address _verifierAddress,
        uint256 _escapeBlockLowerBound,
        uint256 _escapeBlockUpperBound,
        address _contractOwner
    ) public {
        verifier = IVerifier(_verifierAddress);
        escapeBlockLowerBound = _escapeBlockLowerBound;
        escapeBlockUpperBound = _escapeBlockUpperBound;
        rollupProviders[msg.sender] = true;
        totalPendingDeposit.push(0);
        totalDeposited.push(0);
        totalWithdrawn.push(0);
        totalFees.push(0);
        transferOwnership(_contractOwner);
    }

    function setVerifier(address _verifierAddress) public override onlyOwner {
        verifier = IVerifier(_verifierAddress);
        emit VerifierUpdated(_verifierAddress);
    }

    function getSupportedAsset(uint256 assetId) public view override returns (address) {
        if (assetId == ethAssetId) {
            return address(0x0);
        }

        return supportedAssets[assetId - 1];
    }

    function getEscapeHatchStatus() public view override returns (bool, uint256) {
        uint256 blockNum = block.number;

        bool isOpen = blockNum % escapeBlockUpperBound >= escapeBlockLowerBound;
        uint256 blocksRemaining = 0;
        if (isOpen) {

            blocksRemaining = escapeBlockUpperBound - (blockNum % escapeBlockUpperBound);
        } else {

            blocksRemaining = escapeBlockLowerBound - (blockNum % escapeBlockUpperBound);
        }
        return (isOpen, blocksRemaining);
    }

    function decreasePendingDepositBalance(
        uint256 assetId,
        address transferFromAddress,
        uint256 amount
    ) internal {
        uint256 userBalance = userPendingDeposits[assetId][transferFromAddress];
        require(userBalance >= amount, 'Rollup Processor: INSUFFICIENT_DEPOSIT');

        userPendingDeposits[assetId][transferFromAddress] = userBalance.sub(amount);
        totalPendingDeposit[assetId] = totalPendingDeposit[assetId].sub(amount);
        totalDeposited[assetId] = totalDeposited[assetId].add(amount);
    }

    function setSupportedAsset(address linkedToken, bool supportsPermit) external override onlyOwner {
        require(linkedToken != address(0x0), 'Rollup Processor: ZERO_ADDRESS');

        supportedAssets.push(linkedToken);
        assetPermitSupport[linkedToken] = supportsPermit;

        uint256 assetId = supportedAssets.length;
        require(assetId < numberOfAssets, 'Rollup Processor: MAX_ASSET_REACHED');

        totalPendingDeposit.push(0);
        totalDeposited.push(0);
        totalWithdrawn.push(0);
        totalFees.push(0);

        emit AssetAdded(assetId, linkedToken);
    }

    function setAssetPermitSupport(uint256 assetId, bool supportsPermit) external override onlyOwner {
        address assetAddress = getSupportedAsset(assetId);
        require(assetAddress != address(0x0), 'Rollup Processor: TOKEN_ASSET_NOT_LINKED');

        assetPermitSupport[assetAddress] = supportsPermit;
    }

    function escapeHatch(
        bytes calldata proofData,
        bytes calldata signatures,
        bytes calldata viewingKeys
    ) external override whenNotPaused {
        (bool isOpen, ) = getEscapeHatchStatus();
        require(isOpen, 'Rollup Processor: ESCAPE_BLOCK_RANGE_INCORRECT');

        processRollupProof(proofData, signatures, viewingKeys);
    }

    function processRollupProof(
        bytes memory proofData,
        bytes memory signatures,
        bytes calldata
    ) internal {
        uint256 numTxs = verifyProofAndUpdateState(proofData);
        processDepositsAndWithdrawals(proofData, numTxs, signatures);
    }

    function verifyProofAndUpdateState(bytes memory proofData) internal returns (uint256) {
        (
            bytes32 newDataRoot,
            bytes32 newNullRoot,
            uint256 rollupId,
            uint256 rollupSize,
            bytes32 newRootRoot,
            uint256 numTxs,
            uint256 newDataSize
        ) = validateMerkleRoots(proofData);

        bool proof_verified = false;
        address verifierAddress;
        uint256 temp1;
        uint256 temp2;
        uint256 temp3;
        assembly {

            let inputPtr := sub(proofData, 0x44)
            verifierAddress := sload(verifier_slot)

            temp1 := mload(inputPtr)
            temp2 := mload(add(inputPtr, 0x20))
            temp3 := mload(add(inputPtr, 0x40))

            mstore8(inputPtr, 0xac)
            mstore8(add(inputPtr, 0x01), 0x31)
            mstore8(add(inputPtr, 0x02), 0x8c)
            mstore8(add(inputPtr, 0x03), 0x5d)
            mstore(add(inputPtr, 0x04), 0x40)
            mstore(add(inputPtr, 0x24), rollupSize)

            let callSize := add(mload(proofData), 0x64)

            proof_verified := staticcall(gas(), verifierAddress, inputPtr, callSize, 0x00, 0x00)

            mstore(inputPtr, temp1)
            mstore(add(inputPtr, 0x20), temp2)
            mstore(add(inputPtr, 0x40), temp3)
        }

        require(proof_verified, 'proof verification failed');

        dataRoot = newDataRoot;
        nullRoot = newNullRoot;
        nextRollupId = rollupId.add(1);
        rootRoot = newRootRoot;
        dataSize = newDataSize;

        emit RollupProcessed(rollupId, dataRoot, nullRoot, rootRoot, dataSize);
        return numTxs;
    }

    function validateMerkleRoots(bytes memory proofData)
        internal
        view
        returns (
            bytes32,
            bytes32,
            uint256,
            uint256,
            bytes32,
            uint256,
            uint256
        )
    {
        (

            uint256[4] memory nums,
            bytes32 oldDataRoot,
            bytes32 newDataRoot,
            bytes32 oldNullRoot,
            bytes32 newNullRoot,
            bytes32 oldRootRoot,
            bytes32 newRootRoot
        ) = decodeProof(proofData, numberOfAssets);

        nums[3] = nums[1] == 0 ? 1 : nums[1];

        uint256 toInsert = nums[3].mul(2);
        if (dataSize % toInsert == 0) {
            require(nums[2] == dataSize, 'Rollup Processor: INCORRECT_DATA_START_INDEX');
        } else {
            uint256 expected = dataSize + toInsert - (dataSize % toInsert);
            require(nums[2] == expected, 'Rollup Processor: INCORRECT_DATA_START_INDEX');
        }

        require(oldDataRoot == dataRoot, 'Rollup Processor: INCORRECT_DATA_ROOT');
        require(oldNullRoot == nullRoot, 'Rollup Processor: INCORRECT_NULL_ROOT');
        require(oldRootRoot == rootRoot, 'Rollup Processor: INCORRECT_ROOT_ROOT');
        require(nums[0] == nextRollupId, 'Rollup Processor: ID_NOT_SEQUENTIAL');

        return (newDataRoot, newNullRoot, nums[0], nums[1], newRootRoot, nums[3], nums[2] + toInsert);
    }

    function processDepositsAndWithdrawals(
        bytes memory proofData,
        uint256 numTxs,
        bytes memory signatures
    ) internal {
        uint256 sigIndex = 0x00;
        uint256 proofDataPtr;
        assembly {
            proofDataPtr := add(proofData, 0x20)
        }
        proofDataPtr += rollupPubInputLength;
        uint256 end = proofDataPtr + (numTxs * txPubInputLength);
        uint256 stepSize = txPubInputLength;

        while (proofDataPtr < end) {

            uint256 proofId;
            uint256 publicInput;
            uint256 publicOutput;
            bool txNeedsProcessing;
            assembly {
                proofId := mload(proofDataPtr)
                publicInput := mload(add(proofDataPtr, 0x20))
                publicOutput := mload(add(proofDataPtr, 0x40))

                txNeedsProcessing := and(iszero(proofId), or(not(iszero(publicInput)), not(iszero(publicOutput))))
            }

            if (txNeedsProcessing) {

                uint256 assetId;
                assembly {
                    assetId := mload(add(proofDataPtr, 0x60))
                }

                if (publicInput > 0) {

                    address inputOwner;
                    bytes32 digest;
                    assembly {
                        inputOwner := mload(add(proofDataPtr, 0x140))

                        digest := keccak256(proofDataPtr, stepSize)
                    }
                    if (!depositProofApprovals[inputOwner][digest]) {

                        bytes memory signature;
                        uint256 temp;
                        assembly {

                            signature := add(signatures, sigIndex)

                            temp := mload(signature)

                            mstore(signature, 0x60)
                        }

                        RollupProcessorLibrary.validateUnpackedSignature(digest, signature, inputOwner);

                        assembly {
                            mstore(signature, temp)
                            sigIndex := add(sigIndex, 0x60)
                        }
                    }
                    decreasePendingDepositBalance(assetId, inputOwner, publicInput);
                }

                if (publicOutput > 0) {
                    address outputOwner;
                    assembly {
                        outputOwner := mload(add(proofDataPtr, 0x160))
                    }
                    withdraw(publicOutput, outputOwner, assetId);
                }
            }
            proofDataPtr += txPubInputLength;
        }
    }

    function withdraw(
        uint256 withdrawValue,
        address receiverAddress,
        uint256 assetId
    ) internal {
        require(receiverAddress != address(0), 'Rollup Processor: ZERO_ADDRESS');
        if (assetId == 0) {

            payable(receiverAddress).call{gas: 30000, value: withdrawValue}('');
        } else {
            address assetAddress = getSupportedAsset(assetId);
            IERC20(assetAddress).transfer(receiverAddress, withdrawValue);
        }
        totalWithdrawn[assetId] = totalWithdrawn[assetId].add(withdrawValue);
    }
}
