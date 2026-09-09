// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {ILBP} from "./interfaces/ILBP.sol";

contract RefVault is ReentrancyGuardTransient {
    error OnlyController();

    error ZeroAddress();

    error IndexOutOfRange();

    error TransferFailed();

    event RewardQueued(address indexed referrer, uint256 amount, uint128 queueIndex);

    event RewardPaid(address indexed referrer, uint256 amount, uint128 queueIndex);

    event ReferralRewardTriggered(address indexed downline, address indexed referrer);

    uint256 public constant MAX_BATCH = 15;

    ILBP public immutable token;

    address public immutable controller;

    struct QueueEntry {
        address user;
        uint96 amount;
    }

    mapping(uint256 => QueueEntry) public queue;

    uint128 public queueHead;

    uint128 public queueTail;

    constructor(address _controller) {
        if (_controller == address(0)) revert ZeroAddress();
        token = ILBP(_controller);
        controller = _controller;
    }

    modifier onlyController() {
        if (msg.sender != controller) revert OnlyController();
        _;
    }

    function triggerReward(address referrer, uint256 amount, address downline) external onlyController {
        if (referrer == address(0)) revert ZeroAddress();

        emit ReferralRewardTriggered(downline, referrer);

        if (amount == 0 || amount > type(uint96).max) return;

        uint128 tail = queueTail;
        queue[tail] = QueueEntry({user: referrer, amount: uint96(amount)});
        unchecked {
            queueTail = tail + 1;
        }
        emit RewardQueued(referrer, amount, tail);
    }

    function processQueue() external nonReentrant returns (uint256 processed) {
        return _processQueueInternal();
    }

    function _processQueueInternal() internal returns (uint256 processed) {
        uint128 head = queueHead;
        uint128 tail = queueTail;
        if (head == tail) return 0;

        uint256 currentBalance = token.rawBalanceOf(address(this));

        while (processed < MAX_BATCH && head < tail) {
            QueueEntry memory entry = queue[head];
            uint256 needed = uint256(entry.amount);

            if (currentBalance < needed) break;

            unchecked {
                currentBalance -= needed;
            }
            _transferToken(entry.user, needed);
            emit RewardPaid(entry.user, needed, head);

            unchecked {
                ++head;
                ++processed;
            }
        }

        if (head != queueHead) queueHead = head;
    }

    function _transferToken(address to, uint256 amount) internal {
        if (!token.transfer(to, amount)) revert TransferFailed();
    }
}
