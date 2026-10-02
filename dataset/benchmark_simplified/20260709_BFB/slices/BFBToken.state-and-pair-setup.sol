// BFB Token.
contract BFBToken is IERC20, Ownable2Step {

    string public constant name = "BFB";
    string public constant symbol = "BFB";
    uint8 public constant decimals = 18;
    uint256 public totalSupply = 2100000000 * (10**decimals);
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public burnTotalRatio = 15;  // every hour burn ratio, denominator is 10000.
    uint256 public burnRatioInBurn = 5000;
    uint256 public burnRatioInLP = 4000;
    uint256 public burnRatioInFee = 1000;
    //uint256 public burnRatioInNFT;
    address public feeToAddress;

    uint256 public lastBurnTimeDays;  // last burn time days.
    address public CoreAddress;
    address public immutable Router_Address;
    address public immutable WBNB_Token_LP_Address;
    uint256 private immutable ONE_DAY_SECONDS;  // every hour.
    uint256 private constant DENOMINATOR = 10000;
    address public manager;
    address public managerV2;

    uint256 public fallLastPrice; // 1e18 token price how much bnb.
    uint256 public fallLastTime;
    uint256 public fallPriceRatio = 500;      // denominator is 10000.
    uint256 public fallPriceBurnRatio = 500;  // denominator is 10000.


    event BurnPool(uint256 burnTimeDays, uint256 burnAmount, uint256 nowTime);
    event PriceDeflPool(uint256 fallLastPrice, uint256 fallLastTime, uint256 nowPrice, uint256 nowTime, uint256 burnAmount);


    constructor() {
        manager = tx.origin;
        managerV2 = tx.origin;
        feeToAddress = address(0xD2a9f4b62dC947758B49AaB0BC5eE0F6102f14e9);
        ONE_DAY_SECONDS = 3600;
        lastBurnTimeDays = block.timestamp / ONE_DAY_SECONDS;
        CoreAddress = address(0xd1471cACEbf9e9529008b69835101C79A5AAd443);

        Router_Address = address(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        address factoryAddress = IPancakeRouter02(Router_Address).factory();
        address wbnbAddress = IPancakeRouter02(Router_Address).WETH();
        WBNB_Token_LP_Address = IUniswapV2Factory(factoryAddress).createPair(wbnbAddress, address(this));
       
        balanceOf[tx.origin] = totalSupply;
        emit Transfer(address(0), tx.origin, totalSupply);
    }
