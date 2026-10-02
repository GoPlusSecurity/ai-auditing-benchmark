contract VECAndETH is Ownable {
    using SafeMath for uint256;
    using Address for address;

    IPancakeRouter02 public pancakeRouter;
    IERC20 public VECToken;
    IERC20 public USDTToken;
    IERC20 public ETHToken;
    address public luancher;
    address public fundAddress;
    address public destidation;

    address public constant router = 0x10ED43C718714eb63d5aA57B78B54704E256024E; //0xD99D1c33F9fC3444f8101754aBC46c52416550D1; //;
    uint256 public minCapAmount = 30 ether;
    uint256 public maxCapAmount = 10000 ether;
    uint8 public outMultipul = 3;

    uint256 public intervalTime = 7 days;

    struct MEMBER {
        uint256 _stakeAmount;
        uint256 _balance;
        uint256 _remain;
        uint256 _received;
        uint256 _rewards;
        uint256 _lastUpdateTime;
        uint256 _stakeTime;
         uint256 _receivedTime;
    }
    mapping (address => MEMBER) public members;
    mapping (address => uint256) public teamPerformances;

    uint256 public totalSupply;

    uint256 public totalCap = 30000 ether;

    bool public state = false;
    uint256 public rewardRate = 82671957671;

    uint256 public withRate = 100;
    mapping (address => bool) public blist;

    event GetRewardPaid(address indexed account, uint256 reward, uint256 fee);
    event Donate(address indexed account, uint256 amount, uint256 stakeValue);
    event Withdraw(address account, uint256 amount, uint256 vecAmount);

    modifier _updateReward(address account) {
        MEMBER storage memberInfo = members[account];
        (uint256 currnetEarned, uint256 currentValue) = earned(account);
        memberInfo._rewards = memberInfo._rewards.add(currnetEarned);
        memberInfo._remain = memberInfo._remain > currentValue ? memberInfo._remain.sub(currentValue) : 0;
        memberInfo._received = memberInfo._received.add(currentValue);
        memberInfo._lastUpdateTime = block.timestamp;
        if (memberInfo._remain <= 0) {
            memberInfo._balance = 0;
            memberInfo._stakeAmount = 0;
        }
        _;
    }

    modifier onlyLuancher() {
        require(luancher == msg.sender, "Error: not allowed");
        _;
    }

    constructor(
        address _vecToken,
        address _ethToken,
        address _usdtTToken
    ) {
        VECToken = IERC20(_vecToken);
        ETHToken = IERC20(_ethToken);
        USDTToken = IERC20(_usdtTToken);
        pancakeRouter = IPancakeRouter02(router);

        luancher = msg.sender;
    }
