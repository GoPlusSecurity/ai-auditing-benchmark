// Copyright (C) Polytope Labs Ltd.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// 	http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
pragma solidity ^0.8.17;

/**
 * NOTE: This file has been simplified to be self-contained.
 * Only the minimal set of types/interfaces/libraries needed by `handlePostRequests`
 * are inlined here.
 */

// -----------------------------
// Minimal OpenZeppelin utilities
// -----------------------------

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

abstract contract ERC165 {
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == 0x01ffc9a7; // IERC165
    }
}

// -----------------------------
// Minimal ISMP interfaces/types
// -----------------------------

enum FrozenStatus {
    None,
    Incoming,
    Outgoing,
    All
}

struct StateCommitment {
    bytes32 overlayRoot;
    // Other fields omitted
}

struct Proof {
    uint256 height;
    bytes multiproof;
    uint256 leafCount;
}

struct PostRequest {
    bytes dest;
    uint64 timeoutTimestamp;
    bytes data;
}

struct PostRequestLeaf {
    uint256 kIndex;
    uint256 index;
    PostRequest request;
}

struct PostRequestMessage {
    Proof proof;
    PostRequestLeaf[] requests;
}

interface IIsmpHost {
    function frozen() external view returns (FrozenStatus);

    function stateMachineCommitmentUpdateTime(uint256 height) external view returns (uint256);

    function challengePeriod() external view returns (uint256);

    function host() external view returns (bytes memory);

    function requestReceipts(bytes32 commitment) external view returns (address);

    function stateMachineCommitment(uint256 height) external view returns (StateCommitment memory);

    function dispatchIncoming(PostRequest calldata request, address relayer) external;
}

interface IHandler {
    function handlePostRequests(IIsmpHost host, PostRequestMessage calldata request) external;
}

// -----------------------------
// Minimal helper libraries
// -----------------------------

library Bytes {
    function equals(bytes memory a, bytes memory b) internal pure returns (bool) {
        if (a.length != b.length) return false;
        return keccak256(a) == keccak256(b);
    }

    function equals(bytes calldata a, bytes memory b) internal pure returns (bool) {
        if (a.length != b.length) return false;
        return keccak256(a) == keccak256(b);
    }
}

library Message {
    function timeout(PostRequest memory request) internal pure returns (uint256) {
        return uint256(request.timeoutTimestamp);
    }

    function timeout(PostRequest calldata request) internal pure returns (uint256) {
        return uint256(request.timeoutTimestamp);
    }

    function hash(PostRequest memory request) internal pure returns (bytes32) {
        return keccak256(abi.encode(request.dest, request.timeoutTimestamp, request.data));
    }

    function hash(PostRequest calldata request) internal pure returns (bytes32) {
        return keccak256(abi.encode(request.dest, request.timeoutTimestamp, request.data));
    }
}

struct MmrLeaf {
    uint256 kIndex;
    uint256 index;
    bytes32 value;
}

library MerkleMountainRange {
    // Cryptographic verification omitted in this simplified version.
    function VerifyProof(
        bytes32,
        bytes memory,
        MmrLeaf[] memory,
        uint256
    ) internal pure returns (bool) {
        return true;
    }
}

/**
 * @title The ISMP Message Handler.
 * @author Polytope Labs (hello@polytope.technology)
 *
 * @notice The Handler is responsible for verifying the cryptographic proofs needed
 * to confirm the validity of incoming requests/responses.
 * Refer to the official ISMP specification. https://docs.hyperbridge.network/protocol/ismp
 */
contract HandlerV1 is IHandler, ERC165, Context {
    using Bytes for bytes;
    using Message for PostRequest;

    // The IsmpHost has been frozen by the admin
    error HostFrozen();

    // Challenge period has not yet elapsed
    error ChallengePeriodNotElapsed();

    // The requested state commitment does not exist
    error StateCommitmentNotFound();

    // The message destination is not intended for this host
    error InvalidMessageDestination();

    // The provided message has now timed-out
    error MessageTimedOut();

    // The message has been previously processed
    error DuplicateMessage();

    // The provided proof is invalid
    error InvalidProof();

    /**
     * @dev Checks if the host permits incoming datagrams
     */
    modifier notFrozen(IIsmpHost host) {
        FrozenStatus state = host.frozen();
        if (state == FrozenStatus.Incoming || state == FrozenStatus.All) revert HostFrozen();
        _;
    }

    /**
     * @dev Checks the provided requests and their proofs, before dispatching them to their relevant destination modules
     * @param host - `IsmpHost`
     * @param request - batch post requests
     */
    function handlePostRequests(IIsmpHost host, PostRequestMessage calldata request) external notFrozen(host) {
        uint256 timestamp = block.timestamp;
        uint256 delay = timestamp - host.stateMachineCommitmentUpdateTime(request.proof.height);
        uint256 challengePeriod = host.challengePeriod();
        if (challengePeriod != 0 && challengePeriod > delay) revert ChallengePeriodNotElapsed();

        uint256 requestsLen = request.requests.length;
        MmrLeaf[] memory leaves = new MmrLeaf[](requestsLen);

        for (uint256 i = 0; i < requestsLen; ++i) {
            PostRequestLeaf memory leaf = request.requests[i];
            // check destination
            if (!leaf.request.dest.equals(host.host())) revert InvalidMessageDestination();
            // check time-out
            if (timestamp >= leaf.request.timeout()) revert MessageTimedOut();
            // duplicate request?
            bytes32 commitment = leaf.request.hash();
            if (host.requestReceipts(commitment) != address(0)) revert DuplicateMessage();

            leaves[i] = MmrLeaf(leaf.kIndex, leaf.index, commitment);
        }

        bytes32 root = host.stateMachineCommitment(request.proof.height).overlayRoot;
        if (root == bytes32(0)) revert StateCommitmentNotFound();
        bool valid = MerkleMountainRange.VerifyProof(root, request.proof.multiproof, leaves, request.proof.leafCount);
        if (!valid) revert InvalidProof();

        for (uint256 i = 0; i < requestsLen; ++i) {
            PostRequestLeaf memory leaf = request.requests[i];
            host.dispatchIncoming(leaf.request, _msgSender());
        }
    }
}
