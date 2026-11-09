// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";

abstract contract Senate is Context {
    struct Node {
        address prev;
        address next;
        uint256 stake;
    }

    struct Proposal {
        address proposer;
        uint256 createdAt;
        uint256 deadline;
        bool executed;
        bool cancelled;
        bytes data;
        string description;
    }

    enum Vote {
        None,
        For,
        Against
    }

    enum ProposalState {
        Open,
        Executed,
        Cancelled,
        Expired
    }

    uint256 public constant MIN_SENATE = 3;
    uint256 public constant MAX_SENATE = 21;
    uint256 public constant LIST_CAP = 4 * MAX_SENATE;
    uint256 public constant MIN_VOTING_PERIOD = 1 days;
    uint256 public constant MAX_VOTING_PERIOD = 30 days;

    uint256 public constant MAX_DESCRIPTION_LENGTH = 255;

    uint256 public senateSize = MIN_SENATE;
    uint256 public votingPeriod = 3 days;
    uint256 public proposalCount;

    mapping(address account => bool) private _registered;
    mapping(address account => bool) private _listed;
    mapping(address account => Node) private _nodes;
    address private _head;
    address private _tail;
    uint256 private _listLength;

    mapping(uint256 id => Proposal) private _proposals;
    mapping(uint256 id => mapping(address voter => Vote)) private _votes;

    event Registered(address indexed account);
    event Ranked(address indexed account, uint256 stake);
    event Unranked(address indexed account);
    event SenateSizeChanged(uint256 oldSize, uint256 newSize);
    event VotingPeriodChanged(uint256 oldPeriod, uint256 newPeriod);
    event ProposalCreated(
        uint256 indexed id,
        address indexed proposer,
        bytes4 indexed selector,
        bytes data,
        string description,
        uint256 deadline
    );
    event Voted(uint256 indexed id, address indexed voter, bool support);
    event ProposalCancelled(uint256 indexed id);

    event ProposalExecuted(
        uint256 indexed id,
        address indexed executor,
        uint256 votesFor,
        uint256 senateSize,
        address[] senators
    );

    error AlreadyRegistered(address account);
    error NotRegistered(address account);
    error NotSenator(address account);
    error NotSenate(address caller);
    error NotProposable(bytes4 selector);
    error InvalidCalldata();
    error DescriptionTooLong(uint256 length, uint256 max);
    error NonexistentProposal(uint256 id);
    error ProposalNotOpen(uint256 id, ProposalState state);
    error AlreadyVoted(uint256 id, address voter);
    error NotProposer(uint256 id, address caller, address proposer);
    error NotPassed(uint256 id, uint256 votesFor, uint256 seats);
    error InvalidSenateSize(uint256 size, uint256 min, uint256 max);
    error InvalidVotingPeriod(uint256 period, uint256 min, uint256 max);
    error SameValue(uint256 value);

    modifier onlySenate() {
        require(_msgSender() == address(this), NotSenate(_msgSender()));
        _;
    }

    function applyForSenate() external {
        _register(_msgSender());
    }

    function refresh(address account) external {
        require(_registered[account], NotRegistered(account));

        _onStakeChanged(account);
    }

    function propose(bytes calldata data, string calldata description) external returns (uint256 id) {
        address sender = _msgSender();
        require(isSenator(sender), NotSenator(sender));
        require(data.length >= 4, InvalidCalldata());
        require(
            bytes(description).length <= MAX_DESCRIPTION_LENGTH,
            DescriptionTooLong(bytes(description).length, MAX_DESCRIPTION_LENGTH)
        );

        bytes4 selector = bytes4(data[:4]);
        require(_isProposable(selector), NotProposable(selector));

        id = ++proposalCount;

        Proposal storage proposal = _proposals[id];
        proposal.proposer = sender;
        proposal.createdAt = block.timestamp;
        proposal.deadline = block.timestamp + votingPeriod;
        proposal.data = data;
        proposal.description = description;

        _votes[id][sender] = Vote.For;

        emit ProposalCreated(id, sender, selector, data, description, proposal.deadline);
        emit Voted(id, sender, true);
    }

    function vote(uint256 id, bool support) external {
        address sender = _msgSender();
        _requireOpen(id);
        require(isSenator(sender), NotSenator(sender));
        require(_votes[id][sender] == Vote.None, AlreadyVoted(id, sender));

        _votes[id][sender] = support ? Vote.For : Vote.Against;

        emit Voted(id, sender, support);
    }

    function cancel(uint256 id) external {
        address sender = _msgSender();
        Proposal storage proposal = _requireProposal(id);
        require(proposal.proposer == sender, NotProposer(id, sender, proposal.proposer));
        ProposalState current = _state(proposal);
        require(
            current == ProposalState.Open || current == ProposalState.Expired,
            ProposalNotOpen(id, current)
        );

        proposal.cancelled = true;

        emit ProposalCancelled(id);
    }

    function execute(uint256 id) external {
        Proposal storage proposal = _requireOpen(id);

        uint256 size = senateSize;
        (uint256 support, address[] memory seats) = _tally(id);
        require(_isPassed(support), NotPassed(id, support, size));

        proposal.executed = true;

        (bool ok, bytes memory result) = address(this).call(proposal.data);
        if (!ok) {
            assembly ("memory-safe") {
                revert(add(result, 32), mload(result))
            }
        }

        _afterExecute(id);

        emit ProposalExecuted(id, _msgSender(), support, size, seats);
    }

    function setSenateSize(uint256 size) external onlySenate {
        require(size >= MIN_SENATE && size <= MAX_SENATE, InvalidSenateSize(size, MIN_SENATE, MAX_SENATE));

        uint256 previous = senateSize;
        require(size != previous, SameValue(size));
        senateSize = size;

        emit SenateSizeChanged(previous, size);
    }

    function setVotingPeriod(uint256 period) external onlySenate {
        require(
            period >= MIN_VOTING_PERIOD && period <= MAX_VOTING_PERIOD,
            InvalidVotingPeriod(period, MIN_VOTING_PERIOD, MAX_VOTING_PERIOD)
        );

        uint256 previous = votingPeriod;
        require(period != previous, SameValue(period));
        votingPeriod = period;

        emit VotingPeriodChanged(previous, period);
    }

    function isRegistered(address account) public view returns (bool) {
        return _registered[account];
    }

    function isListed(address account) public view returns (bool) {
        return _listed[account];
    }

    function listLength() public view returns (uint256) {
        return _listLength;
    }

    function listedStakeOf(address account) public view returns (uint256) {
        return _nodes[account].stake;
    }

    function isSenator(address account) public view returns (bool) {
        if (!_listed[account]) {
            return false;
        }

        address current = _head;
        for (uint256 seat = 0; seat < senateSize && current != address(0); ++seat) {
            if (current == account) {
                return true;
            }
            current = _nodes[current].next;
        }
        return false;
    }

    function senators() external view returns (address[] memory out) {
        uint256 seats = senateSize < _listLength ? senateSize : _listLength;
        out = new address[](seats);

        address current = _head;
        for (uint256 i = 0; i < seats; ++i) {
            out[i] = current;
            current = _nodes[current].next;
        }
    }

    function ranked() external view returns (address[] memory accounts, uint256[] memory stakes) {
        accounts = new address[](_listLength);
        stakes = new uint256[](_listLength);

        address current = _head;
        for (uint256 i = 0; i < _listLength; ++i) {
            accounts[i] = current;
            stakes[i] = _nodes[current].stake;
            current = _nodes[current].next;
        }
    }

    function getProposal(uint256 id) external view returns (Proposal memory) {
        return _requireProposal(id);
    }

    function state(uint256 id) public view returns (ProposalState) {
        return _state(_requireProposal(id));
    }

    function voteOf(uint256 id, address voter) external view returns (Vote) {
        return _votes[id][voter];
    }

    function votesFor(uint256 id) public view returns (uint256 support) {
        (support, ) = _tally(id);
    }

    function _tally(uint256 id) private view returns (uint256 support, address[] memory seats) {
        support = 0;
        seats = new address[](senateSize);

        uint256 seat = 0;
        address current = _head;
        for (; seat < senateSize && current != address(0); ++seat) {
            seats[seat] = current;
            if (_votes[id][current] == Vote.For) {
                ++support;
            }
            current = _nodes[current].next;
        }
        assembly ("memory-safe") {
            mstore(seats, seat)
        }
    }

    function isPassed(uint256 id) external view returns (bool) {
        return _isPassed(votesFor(id));
    }

    function _stakeOf(address account) internal view virtual returns (uint256);

    function _collectCandidacyFee(address payer) internal virtual;

    function _isProposable(bytes4 selector) internal view virtual returns (bool) {
        return selector == this.setSenateSize.selector || selector == this.setVotingPeriod.selector;
    }

    function _afterExecute(uint256 id) internal virtual {}

    function _register(address account) internal {
        require(!_registered[account], AlreadyRegistered(account));

        _registered[account] = true;
        _collectCandidacyFee(account);

        emit Registered(account);

        _onStakeChanged(account);
    }

    function _onStakeChanged(address account) internal {
        if (!_registered[account]) {
            return;
        }

        uint256 stake = _stakeOf(account);

        if (!_listed[account]) {
            if (stake == 0) {
                return;
            }
            if (_listLength == LIST_CAP) {
                address last = _tail;
                if (stake <= _nodes[last].stake) {
                    return;
                }
                _unlink(last);
                emit Unranked(last);
            }
            _link(account, stake, _tail, false);
            emit Ranked(account, stake);
            return;
        }

        if (stake == 0) {
            _unlink(account);
            emit Unranked(account);
            return;
        }

        Node storage node = _nodes[account];
        uint256 previous = node.stake;
        if (stake == previous) {
            return;
        }

        address prev = node.prev;
        address next = node.next;
        if (stake > previous && prev != address(0) && stake > _nodes[prev].stake) {
            _unlink(account);
            _link(account, stake, prev, false);
        } else if (stake < previous && next != address(0) && stake < _nodes[next].stake) {
            _unlink(account);
            _link(account, stake, next, true);
        } else {
            node.stake = stake;
        }

        emit Ranked(account, stake);
    }

    function _link(address account, uint256 stake, address hint, bool aboveEquals) private {
        address above = hint;
        while (above != address(0) && _nodes[above].stake < stake) {
            above = _nodes[above].prev;
        }
        address next = above == address(0) ? _head : _nodes[above].next;
        while (next != address(0) && (_nodes[next].stake > stake || (!aboveEquals && _nodes[next].stake == stake))) {
            above = next;
            next = _nodes[next].next;
        }

        _nodes[account] = Node({prev: above, next: next, stake: stake});

        if (above == address(0)) {
            _head = account;
        } else {
            _nodes[above].next = account;
        }
        if (next == address(0)) {
            _tail = account;
        } else {
            _nodes[next].prev = account;
        }

        _listed[account] = true;
        _listLength += 1;
    }

    function _unlink(address account) private {
        Node memory node = _nodes[account];

        if (node.prev == address(0)) {
            _head = node.next;
        } else {
            _nodes[node.prev].next = node.next;
        }
        if (node.next == address(0)) {
            _tail = node.prev;
        } else {
            _nodes[node.next].prev = node.prev;
        }

        delete _nodes[account];
        _listed[account] = false;
        _listLength -= 1;
    }

    function _isPassed(uint256 support) private view returns (bool) {
        return support * 2 > senateSize;
    }

    function _state(Proposal storage proposal) private view returns (ProposalState) {
        if (proposal.executed) {
            return ProposalState.Executed;
        }
        if (proposal.cancelled) {
            return ProposalState.Cancelled;
        }
        if (block.timestamp > proposal.deadline) {
            return ProposalState.Expired;
        }
        return ProposalState.Open;
    }

    function _requireProposal(uint256 id) private view returns (Proposal storage proposal) {
        proposal = _proposals[id];
        require(proposal.proposer != address(0), NonexistentProposal(id));
    }

    function _requireOpen(uint256 id) private view returns (Proposal storage proposal) {
        proposal = _requireProposal(id);
        ProposalState current = _state(proposal);
        require(current == ProposalState.Open, ProposalNotOpen(id, current));
    }
}
