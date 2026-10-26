contract FHToken is ERC20, Ownable {
    using Address for address;

    // 新规则钱包地址
    address public constant CONTRACT_WALLET = 0x784C64502565865456d9ffBE7A5772171D119d65;//
    address public constant COMMUNITY_WALLET = 0xCB6c36D97f021d70bA23D526c6dae183FF61779F;
    address public constant SLIPPAGE_WALLET = 0x776a12796E7922F8930c2bf1F2Da59f3FA62dd42;
    address public constant TREASURY_WALLET = 0x36ac7a082237fBfee9847cc4A56Bf7d49ead90C5;

    // 手续费常量
    uint256 public constant BASE_FEE = 500;                 // 5%
    uint256 public constant FEE_DENOMINATOR = 10000;

    // 跌幅阈值
    uint256 public constant PRICE_DROP_10_PERCENT = 1000;   // 10%
    uint256 public constant PRICE_DROP_15_PERCENT = 1500;   // 15%
    uint256 public constant PRICE_DROP_20_PERCENT = 2000;   // 20%

    // 对应动态费率
    uint256 public constant FEE_10_PERCENT = 1500;          // 15%
    uint256 public constant FEE_15_PERCENT = 2000;          // 20%
    uint256 public constant FEE_20_PERCENT = 3000;          // 30%

    address public pair;
    address public router;
    address public usdt;

    uint256 public initialSupply = 21000000 * 10**18;      // 2100万
    uint256 public targetSupply = 2100000 * 10**18;        // 210万
    uint256 public totalBurned;

    uint256 public lastPrice;
    uint256 public priceUpdateTime;

    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public canAddLiquid;
    mapping(address => bool) public isBlacklisted;
    mapping(address => bool) public isPair;
    mapping(address => bool) public isBuyerWhitelist; 

    bool private inSwap;
    bool public tradingEnabled;

    event TokensBurned(address indexed burner, uint256 amount);
    event PriceUpdated(uint256 newPrice, uint256 timestamp);
    event SlippageUpdated(uint256 buySlippage, uint256 sellSlippage, uint256 priceDrop);
    event BlacklistUpdated(address indexed account, bool isBlacklisted);
    event WhitelistUpdated(address indexed account, bool isWhitelisted);
