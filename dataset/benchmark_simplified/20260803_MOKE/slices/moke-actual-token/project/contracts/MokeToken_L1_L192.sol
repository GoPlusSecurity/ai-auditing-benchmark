// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IMokeToken.sol";
import "./interfaces/IMokeLPDividend.sol";

interface IPancakePairT {
    function getReserves() external view returns (uint112, uint112, uint32);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function mint(address to) external returns (uint256 liquidity);
    function sync() external;
}

interface IPancakeRouterT {
    function WETH() external pure returns (address);
    function factory() external pure returns (address);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn, uint256 amountOutMin, address[] calldata path,
        address to, uint256 deadline
    ) external;
}

interface IPancakeFactoryT {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

/**
 * @title SwapReceiver
 * @dev Swap relay contract — avoids triggering _update on swap output.
 *      Supports both ERC-20 tokens and native ETH/BNB.
 */
contract SwapReceiver {
    using SafeERC20 for IERC20;
    address public immutable owner;

    constructor() {
        owner = msg.sender;
    }

    function sweep(address token, address to) external {
        require(msg.sender == owner, "Not owner");
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).safeTransfer(to, balance);
        }
    }

    function sweepETH(address to) external {
        require(msg.sender == owner, "Not owner");
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool sent,) = payable(to).call{value: balance}("");
            require(sent, "ETH transfer failed");
        }
    }

    receive() external payable {}
}

// PancakeSwap V2 Router (BSC Mainnet)
address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

contract MokeToken is ERC20, Ownable, IMokeToken {
    using SafeERC20 for IERC20;

    uint256 public constant TOTAL_SUPPLY = 210_000_000 * 1e18;
    uint256 public constant RECEIVER_SUPPLY = 10_000_000 * 1e18;
    uint256 public constant RESERVE_SUPPLY = 200_000_000 * 1e18;
    uint256 public constant BASIS_POINTS = 10000;

    uint256 public lpDivRate = 200;
    uint256 public nftDivRate = 200;
    uint256 public marketingRate = 100;

    bool public tradingEnabled;
    address public marketingWallet;

    address public lpDividendPool;
    address public nftDividendPool;

    IPancakeRouterT public router;
    address public pancakePair;
    SwapReceiver public swapReceiver;

    mapping(address => bool) public isWhitelisted;
    mapping(address => bool) public isExcludedFromTax;
    mapping(address => bool) public isMarketPair;

    // --- Tax accumulation (TokenA pattern) ---
    uint256 public accumulatedLpTax;
    uint256 public accumulatedNftTax;
    uint256 public accumulatedMarketingTax;
    uint256 public swapThreshold = 10000 * 1e18;
    uint256 public maxSwapAmount = 100000 * 1e18;
    uint256 public swapSlippageBps = 1500;

    uint256 public pendingLpBNB;
    uint256 public pendingNftBNB;
    uint256 public pendingMarketingBNB;

    // --- Released MOKE restriction ---
    mapping(address => uint256) public releasedMokeBalance;
    address public releaseContract;
    mapping(address => bool) public isReleasedMokeHandler;
    mapping(address => bool) public canManageReleasedBalance;

    // --- LP Removal Burn Detection ---
    address public weth;
    bool public isWethToken0;
    bool public lpRemovalBurnEnabled;

    // --- X/MOKE Reserve Pool ---
    address public xMokePair;
    address public tokenXContract;

    bool private inSwap;

    event TradingEnabled(uint256 timestamp);
    event ReleaseContractSet(address indexed release);
    event ReleasedBalanceAdded(address indexed user, uint256 amount);
    event ReleasedBalanceReduced(address indexed user, uint256 amount);
    event TaxRateUpdated(uint256 lpRate, uint256 nftRate, uint256 marketingRate_);
    event MarketPairUpdated(address indexed pair, bool status);
    event MarketingWalletSet(address indexed wallet);
    event WhitelistSet(address indexed account, bool status);
    event ExcludedFromTaxSet(address indexed account, bool status);
    event LPDividendPoolSet(address indexed pool);
    event NFTDividendPoolSet(address indexed pool);
    event TaxCollected(address indexed from, address indexed to, uint256 lpAmount, uint256 nftAmount, uint256 marketingAmount);
    event TaxSwapped(uint256 tokensSwapped, uint256 bnbReceived);
    event TaxDistributed(uint256 lpBNB, uint256 nftBNB, uint256 marketingBNB);
    event EmergencyWithdraw(address indexed token, uint256 amount, address indexed to);
    event SwapThresholdUpdated(uint256 threshold);
    event MaxSwapAmountUpdated(uint256 maxAmount);
    event RouterSet(address indexed router_);
    event LPRemovalBurn(address indexed originalTo, uint256 amount);
    event ReleasedMokeHandlerSet(address indexed handler, bool status);
    event XMokePairSet(address indexed pair);
    event LPRemovalBurnToggled(bool enabled);
    event CanManageReleasedBalanceSet(address indexed addr, bool status);
    event ReservePoolSetup(address indexed pair, address indexed tokenX, uint256 mokeAmount, uint256 tokenXAmount);

    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor(
        address _marketingWallet,
        address _tokenReceiver
    ) ERC20("Moke", "MOKE") Ownable(msg.sender) {
        require(_marketingWallet != address(0), "Invalid marketing wallet");
        require(_tokenReceiver != address(0), "Invalid token receiver");
        marketingWallet = _marketingWallet;
        router = IPancakeRouterT(PANCAKE_ROUTER);
        weth = router.WETH();

        swapReceiver = new SwapReceiver();

        address factory = router.factory();
        address _pair = IPancakeFactoryT(factory).getPair(address(this), weth);
        if (_pair == address(0)) {
            _pair = IPancakeFactoryT(factory).createPair(address(this), weth);
        }
        pancakePair = _pair;
        isMarketPair[_pair] = true;
        isWethToken0 = IPancakePairT(_pair).token0() == weth;

        isExcludedFromTax[msg.sender] = true;
        isExcludedFromTax[address(this)] = true;
        isExcludedFromTax[address(swapReceiver)] = true;
        isExcludedFromTax[_marketingWallet] = true;
        isExcludedFromTax[_tokenReceiver] = true;

        isWhitelisted[msg.sender] = true;
        isWhitelisted[address(this)] = true;
        isWhitelisted[address(swapReceiver)] = true;
        isWhitelisted[_tokenReceiver] = true;

        _mint(_tokenReceiver, RECEIVER_SUPPLY);
        _mint(address(this), RESERVE_SUPPLY);
    }

    // ============ Admin Functions ============

