// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IMokeLPDividend.sol";

interface IPancakeRouterLP {
    function WETH() external pure returns (address);
    function factory() external pure returns (address);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline
    ) external;
}

interface IPancakePairLP {
    function getReserves() external view returns (uint112, uint112, uint32);
    function token0() external view returns (address);
}

interface IPancakeFactoryLP {
    function getPair(address tokenA, address tokenB) external view returns (address);
}

/**
 * @title MokeLPDividend
 * @dev BNB dividend distribution proportional to LP token holdings.
 *      - Receives BNB from MokeToken tax distribution
 *      - Can also receive MOKE and swap to BNB
 *      - Uses lpToken.totalSupply() for fair per-LP calculation
 *      - LP balances synced via MokeToken._update hook + manual sync + claim-time sync
 */
contract MokeLPDividend is IMokeLPDividend, Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    IERC20 public mokeToken;
    IERC20 public lpToken;
    IPancakeRouterLP public router;

    uint256 public totalDividendPerLP;
    mapping(address => uint256) public userLPRecord;
    mapping(address => uint256) public userDividendDebt;
    mapping(address => uint256) public userPendingDividend;

    uint256 public minSwapAmount = 1e18;
    uint256 public minDistributeAmount = 0.001 ether;
    uint256 public swapSlippageBps = 1500;
    uint256 public constant BASIS_POINTS = 10000;

    uint256 public unprocessedBNB;
    bool private _swapping;

    address public mokeTokenContract;

    event DividendDistributed(uint256 bnbAmount, uint256 totalLP, uint256 perLP);
    event DividendClaimed(address indexed user, uint256 amount);
    event UserLPSynced(address indexed user, uint256 oldLP, uint256 newLP);
    event MinSwapAmountSet(uint256 amount);
    event MinDistributeAmountSet(uint256 amount);
    event EmergencyWithdraw(address indexed token, uint256 amount, address indexed to);
    event MokeTokenContractSet(address indexed mokeToken_);
    event RouterSet(address indexed router_);
    event LPTokenSet(address indexed lpToken_);

    constructor(
        address _mokeToken,
        address _lpToken,
        address _router
    ) Ownable(msg.sender) {
        mokeToken = IERC20(_mokeToken);
        mokeTokenContract = _mokeToken;
        lpToken = IERC20(_lpToken);
        router = IPancakeRouterLP(_router);
    }

    // ============ Admin Functions ============

