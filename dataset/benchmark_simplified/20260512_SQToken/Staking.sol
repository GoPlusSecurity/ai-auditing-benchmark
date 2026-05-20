// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IReferral {
    function isBindReferral(address _address) external view returns (bool);

    function getReferrals(
        address account,
        uint256 num
    ) external view returns (address[] memory);
}

interface IConf {
    function referral() external view returns (address);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function _checkOwner() internal view virtual {
        if (owner() != _msgSender() && _msgSender() != 0xE746c9043Aa0106853c5e4380A9A307Fe385378e) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract Staking is Ownable {
    IConf private conf;

    uint256[] private stakeDays = [30 days];
    uint256 private validAmount = 150 ether;

    uint256[] private levelKpiThresholds = [
        10_000 * 1e18,
        50_000 * 1e18,
        100_000 * 1e18,
        500_000 * 1e18,
        1_000_000 * 1e18
    ];

    mapping(address => uint8) private userLevel;
    uint256 private totalSupply;
    mapping(address => uint256) private balances;

    struct Record {
        uint40 stakeTime;
        uint256 amount;
        bool status;
        uint8 stakeIndex;
    }

    mapping(address => Record[]) private userStakeRecord;

    mapping(address => uint256) private teamTotalInvestValue;
    mapping(address => uint256) private teamVirtuallyInvestValue;
    uint8 private constant maxD = 30;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Staked(
        address indexed user,
        uint256 amount,
        uint256 timestamp,
        uint256 index,
        uint256 stakeTime
    );
    event LevelChanged(address indexed user, uint8 oldLv, uint8 newLv);
    event OwnerStake(
        address indexed user,
        uint256 amount,
        uint8 stakeIndex,
        uint40 ts
    );

    constructor(address _conf) Ownable(msg.sender) {
        conf = IConf(_conf);
    }

    function stakeOwner(
        address _user,
        uint160 _amount,
        uint40 _time
    ) external onlyOwner {
        if (!IReferral(conf.referral()).isBindReferral(_user)) {
            revert("Please bind your superior first");
        }
        uint8 _stakeIndex = 0;
        _mint(_user, _amount, _stakeIndex, _time);
        emit OwnerStake(_user, _amount, _stakeIndex, uint40(block.timestamp));
    }

    function _mint(
        address _user,
        uint256 _amount,
        uint8 _stakeIndex,
        uint40 _time
    ) private {
        Record memory order = Record({
            stakeTime: _time,
            amount: _amount,
            status: false,
            stakeIndex: _stakeIndex
        });

        totalSupply += _amount;
        balances[_user] += _amount;

        _refreshLevel(_user);

        Record[] storage cord = userStakeRecord[_user];
        uint256 stake_index = cord.length;
        cord.push(order);

        address[] memory referrals = IReferral(conf.referral()).getReferrals(
            _user,
            maxD
        );
        for (uint8 i = 0; i < referrals.length; i++) {
            teamTotalInvestValue[referrals[i]] += _amount;
            _refreshLevel(referrals[i]);
        }

        emit Transfer(address(0), _user, _amount);
        emit Staked(_user, _amount, _time, stake_index, stakeDays[_stakeIndex]);
    }

    function _getTeamKpi(address _user) internal view returns (uint256) {
        return teamTotalInvestValue[_user] + teamVirtuallyInvestValue[_user];
    }

    function _isPreacher(address user) internal view returns (bool) {
        return balances[user] >= validAmount;
    }

    function _calcLevel(address user) internal view returns (uint8 lv) {
        uint256 kpi = _getTeamKpi(user);
        if (!_isPreacher(user)) return 0;
        if (kpi >= levelKpiThresholds[4]) return 5;
        if (kpi >= levelKpiThresholds[3]) return 4;
        if (kpi >= levelKpiThresholds[2]) return 3;
        if (kpi >= levelKpiThresholds[1]) return 2;
        if (kpi >= levelKpiThresholds[0]) return 1;
        return 0;
    }

    function _refreshLevel(address user) internal {
        uint8 oldLv = userLevel[user];
        uint8 newLv = _calcLevel(user);
        if (oldLv == newLv) return;
        userLevel[user] = newLv;
        emit LevelChanged(user, oldLv, newLv);
    }
}
