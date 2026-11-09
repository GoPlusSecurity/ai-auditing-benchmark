// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";

abstract contract OperatorLockable is Context {
    mapping(address owner => mapping(address operator => bool approved)) private _approvals;

    mapping(uint256 id => address lockedFor) private _lockedFor;

    mapping(uint256 id => uint256 till) private _lockedTill;

    event OperatorApproved(address indexed owner, address indexed operator);

    event OperatorApproveRevoked(address indexed owner, address indexed operator);

    event Locked(uint256 indexed id, address indexed lockedFor, uint256 till);

    event Unlocked(uint256 indexed id);

    error NotApproved(address owner, address operator);

    error AlreadyLocked(uint256 id);

    error LockTillInPast();

    error NonexistentId(uint256 id);

    error OperatorNotPermitted(address operator);

    function approveOperator(address operator) public virtual {
        _requireOperatorPermitted(operator);

        _changeApprove(_msgSender(), operator, true);
    }

    function revokeOperatorApprove(address owner, address operator) public virtual {
        address sender = _msgSender();
        require(sender == owner || sender == operator, NotApproved(owner, operator));

        _changeApprove(owner, operator, false);
    }

    function isApprovedForAll(address owner, address operator) public view virtual returns (bool) {
        return _isApprovedForAll(owner, operator);
    }

    function lock(uint256 id) public virtual {
        lock(id, type(uint256).max);
    }

    function lock(uint256 id, uint256 lockTill) public virtual {
        address operator = _msgSender();
        address owner = _ownerOf(id);

        require(owner != address(0), NonexistentId(id));
        require(lockTill > block.timestamp, LockTillInPast());

        _requireLockAllowed(id, lockTill);

        _requireAllowance(owner, operator);
        _requireRelockAllowed(id, owner);

        _lock(id, owner, lockTill);
    }

    function unlock(uint256 id) public virtual {
        address lockedFor = _lockedForOf(id);
        if (lockedFor != address(0)) {
            _requireAllowance(lockedFor, _msgSender());
        }

        _unlock(id);
    }

    function isLocked(uint256 id) public view virtual returns (bool) {
        return _isLocked(id);
    }

    function lockTillOf(uint256 id) public view virtual returns (uint256) {
        return _lockedTillOf(id);
    }

    function lockedForOf(uint256 id) public view virtual returns (address) {
        return _lockedForOf(id);
    }

    function _isApprovedForAll(address owner, address operator) internal view virtual returns (bool) {
        return owner == operator || _approvals[owner][operator];
    }

    function _ownerOf(uint256 id) internal view virtual returns (address);

    function _lockedForOf(uint256 id) internal view virtual returns (address) {
        if (_isLocked(id)) {
            return _lockedFor[id];
        }

        return address(0);
    }

    function _lockedTillOf(uint256 id) internal view virtual returns (uint256) {
        return _lockedTill[id];
    }

    function _isLocked(uint256 id) internal view virtual returns (bool) {
        return _lockedTillOf(id) > block.timestamp;
    }

    function _operatorPermitted(address operator) internal view virtual returns (bool) {
        return operator != address(0);
    }

    function _requireAllowance(address owner, address operator) internal view virtual {
        if (owner == operator) {
            return;
        }
        _requireOperatorPermitted(operator);
        require(_isApprovedForAll(owner, operator), NotApproved(owner, operator));
    }

    function _requireRelockAllowed(uint256 id, address owner) internal view virtual {
        address beneficiary = _lockedForOf(id);
        require(beneficiary == address(0) || beneficiary == owner, AlreadyLocked(id));
    }

    function _requireOperatorPermitted(address operator) internal view virtual {
        require(_operatorPermitted(operator), OperatorNotPermitted(operator));
    }

    function _requireLockAllowed(uint256 id, uint256 till) internal view virtual {}

    function _lock(uint256 id, address lockedFor, uint256 lockedTill) internal virtual {
        _lockedFor[id] = lockedFor;
        _lockedTill[id] = lockedTill;

        emit Locked(id, lockedFor, lockedTill);
    }

    function _unlock(uint256 id) internal virtual {
        if (_lockedFor[id] == address(0)) {
            return;
        }
        delete _lockedFor[id];
        delete _lockedTill[id];

        emit Unlocked(id);
    }

    function _changeApprove(address owner, address operator, bool approved) internal virtual {
        _approvals[owner][operator] = approved;

        if (approved) {
            emit OperatorApproved(owner, operator);
        } else {
            emit OperatorApproveRevoked(owner, operator);
        }
    }
}
