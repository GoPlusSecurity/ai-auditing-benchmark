contract PHX is ERC20, Ownable {
    uint256 public constant TOTAL_SUPPLY = 10_000_000 * 1e18;
    uint256 public constant DENOMINATOR = 10_000;
    uint256 public constant PAIR_RELEASE_RATE_PRECISION = 1_000_000;
    uint256 public maxPairReleasesPerDay = 24;

    uint256 private constant RELEASE_RATE_LE_1M = 1_000;
    uint256 private constant RELEASE_RATE_1M_3M = 875;
    uint256 private constant RELEASE_RATE_3M_10M = 750;
    uint256 private constant RELEASE_RATE_GT_10M = 625;

    uint256 private constant USD_THRESHOLD_1M = 1_000_000e18;
    uint256 private constant USD_THRESHOLD_3M = 3_000_000e18;
    uint256 private constant USD_THRESHOLD_10M = 10_000_000e18;

    uint256 public sellPairBurnRate = 5000;

    uint256 public pairBurnMultiplier = 10_000;
    uint256 public constant MULTIPLIER_DENOMINATOR = 10_000;

    address public router;
    address public wbnb;
    address public pair;

    AggregatorV3Interface public priceFeed;

    address public operationWallet;
    address public lpWallet;
    address public foundationWallet;

    address public lpPhxOperator;
    address public miningContract;

    bool public buyWhitelistEnabled = false;
    bool private inFee;

    uint256 private releaseDay;
    uint256 private releaseCountToday;

    mapping(address => bool) public isBuyWhitelist;
    mapping(address => bool) public isBuySellFeeExempt;
    mapping(address => bool) public isTransferFeeExempt;
    mapping(address => bool) public isAMMPair;
    mapping(address => bool) public isMinter;

    uint256 public buyOperationFee = 600;
    uint256 public buyLpFee = 200;
    uint256 public buyFoundationFee = 200;

    uint256 public sellOperationFee = 900;
    uint256 public sellLpFee = 300;
    uint256 public sellFoundationFee = 300;
    uint256 public sellBurnFee = 1500;
    event SellBurnFeeUpdated(uint256 fee);

    uint256 public transferOperationFee = 1500;
    uint256 public transferBurnFee = 1000;
    uint256 public transferFoundationFee = 500;

    event PairCreated(address pair);
    event PairSet(address pair, bool status);

    event PairPhxBurnedFromLp(
        address indexed caller,
        uint256 amount,
        uint256 poolBnbValueUsd,
        uint256 releaseRatePpm
    );

    event MiningContractUpdated(address indexed miningContract);
    event LpPhxOperatorUpdated(address indexed operator);
    event PriceFeedUpdated(address indexed priceFeed);
    event MinterUpdated(address indexed account, bool status);
    event Minted(address indexed minter, address indexed to, uint256 amount);

    event SellPairBurnRateUpdated(uint256 rate);
    event SellPairBurned(address indexed caller, uint256 amount);
    event PairBurnMultiplierUpdated(uint256 multiplier);
    event MaxPairReleasesPerDayUpdated(uint256 maxReleasesPerDay);

    modifier onlyMinter() {
        require(isMinter[msg.sender], "not minter");
        _;
    }

    constructor(
        address _router,
        address _operationWallet,
        address _lpWallet,
        address _foundationWallet,
        address _owner,
        address _priceFeed
    ) ERC20("PHX", "PHX") Ownable(_owner) {
        require(_router != address(0), "router zero");
        require(_operationWallet != address(0), "operation zero");
        require(_lpWallet != address(0), "lp zero");
        require(_foundationWallet != address(0), "foundation zero");
        require(_owner != address(0), "owner zero");
        require(_priceFeed != address(0), "price feed zero");

        router = _router;
        operationWallet = _operationWallet;
        lpWallet = _lpWallet;
        foundationWallet = _foundationWallet;
        lpPhxOperator = _owner;
        priceFeed = AggregatorV3Interface(_priceFeed);

        wbnb = IPancakeRouter(_router).WETH();
        address factory = IPancakeRouter(_router).factory();

        pair = IPancakeFactory(factory).createPair(address(this), wbnb);
        isAMMPair[pair] = true;

        _setFeeWalletExempt(_owner);
        _setFeeWalletExempt(_operationWallet);
        _setFeeWalletExempt(_lpWallet);
        _setFeeWalletExempt(_foundationWallet);

        isBuyWhitelist[_owner] = true;
        isMinter[_owner] = true;

        _mint(_owner, TOTAL_SUPPLY);

        emit PairCreated(pair);
    }
