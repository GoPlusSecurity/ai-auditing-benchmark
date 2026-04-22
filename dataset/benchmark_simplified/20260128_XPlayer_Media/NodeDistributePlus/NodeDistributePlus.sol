// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IXPL {
    function DynamicBurnPool(uint256 _amount) external;
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        _status = NOT_ENTERED;
    }

    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

contract NodeDistributePlus is ReentrancyGuard {
    address public xplAddress;
    //创建销毁的时间
    mapping(string => uint256) public dayBurnTaskTimeList;
    //每日需要销毁总量
    mapping(string => uint256) public daytotalNeedBurnList;
    //每日销毁总量最后更新时间
    mapping(string => uint256) public dayLastBurnTimeList;
    //每日已销毁总量
    mapping(string => uint256) public dayTotalBurnedList;

    constructor(address _xplAddress) {
        xplAddress = _xplAddress;
    }

    function DynamicBurnPool(
        string memory date,
        uint256 _amount
    ) external nonReentrant {
        require(_amount > 0, "k001");
        require(daytotalNeedBurnList[date] > 0, "k002");
        // require(block.timestamp >= dayLastBurnTimeList[date] + 1 hours, "k003");
        require(block.timestamp <= dayBurnTaskTimeList[date] + 2 days, "k004");
        require(
            dayTotalBurnedList[date] + _amount <= daytotalNeedBurnList[date],
            "k005"
        );
        dayTotalBurnedList[date] += _amount;
        dayLastBurnTimeList[date] = block.timestamp;
        IXPL(xplAddress).DynamicBurnPool(_amount);
    }
}
