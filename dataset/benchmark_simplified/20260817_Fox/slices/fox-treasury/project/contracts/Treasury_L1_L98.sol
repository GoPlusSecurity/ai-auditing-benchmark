// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IMintableERC20 {
    function mint(address to, uint256 amount) external;
}

interface IFoxTimeLockPool {
    function timeLock(uint256 _timeLockId, address _user, uint256 _amount) external;
    function rebase() external;
}

interface IFulTimeLockPool {
    function timeLock(uint256 _timeLockId, address _user, uint256 _amount) external;
    function rebase() external;
}

contract Treasury is Initializable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
    uint256 public constant BASE_100 = 10000;
    uint256 public constant REWARD_RATIO = 1100;

    address public governance;

    address public usdtToken;
    address public foxToken;
    address public stakedFoxToken;
    address public rewardFoxToken;
    address public fulToken;
    address public lpFoxToken;

    address public foxDistributor;
    address public fulDistributor;
    address public rbsExecutor;

    bool public fulMingingStatus = false;

    mapping(address => bool) public stakingPoolMap;

    address[] public timeLockPoolList;    
    mapping(uint256 => address) public timeLockPoolMap1;
    mapping(address => bool) public timeLockPoolMap2;

    address[] public fulTimeLockPoolList;    
    mapping(uint256 => address) public fulTimeLockPoolMap;

    modifier onlyStakingPool() {
        require(stakingPoolMap[msg.sender], "Not staking pool");
        _;
    }    

    modifier onlyGovernance() {
        require(msg.sender == governance, "unauthorized access");
        _;
    }

    modifier onlyRBSExecutor() {
        require(msg.sender == rbsExecutor, "unauthorized access");
        _;
    }    

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(        
        address initialOwner,

        address _governance,

        address _usdtToken,
        address _foxToken,
        address _stakedFoxToken,
        address _rewardFoxToken,
        address _fulToken,
        address _lpFoxToken

    ) public initializer {        
        __Ownable_init(initialOwner);

        governance = _governance;

        usdtToken = _usdtToken;
        foxToken = _foxToken;
        stakedFoxToken = _stakedFoxToken;
        rewardFoxToken = _rewardFoxToken;
        fulToken = _fulToken;
        lpFoxToken = _lpFoxToken;   
    }

