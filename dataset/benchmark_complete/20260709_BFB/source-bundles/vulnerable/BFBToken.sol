// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;


// safe transfer
library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        // (bool success,) = to.call.value(value)(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}

// Interface of the ERC20 standard as defined in the EIP.
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address from, address to) external view returns (uint256);
    function approve(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

interface IPancakeRouter01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IPancakeRouter02 is IPancakeRouter01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}


// owner
abstract contract Ownable2Step {
    address public owner;
    address public pendingOwner;


    constructor() {
        owner = tx.origin;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, 'Ownable2Step: owner error');
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        pendingOwner = newOwner;
    }

    function acceptOwnership() public {
        require(pendingOwner != address(0), 'Ownable2Step: pengding owner inexistence');
        require(msg.sender == pendingOwner, 'Ownable2Step: pending owner error');
        owner = pendingOwner;
        delete pendingOwner;
    }

    function burnOwnership() public onlyOwner {
        pendingOwner = address(0);
        owner = address(0);
    }
}


interface ICore {
    function mySuper(address user) external view returns (address);
    function myJuniorsArr(address user) external view returns (address[] memory);
    function myJuniorCount(address user) external view returns (uint256);
    function checkoutBound(address myAddress, address superAddress) external view returns(bool);
    function boundSuper(address myAddress, address superAddress) external returns(bool);
    function buyAndBonus(address account) external payable;
    function whetherFilter(address account) external view returns(bool);
}

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


    modifier onlyManager() {
        require(msg.sender == manager, 'Token: manager error');
        _;
    }
    modifier onlyManagerV2() {
        require(msg.sender == managerV2, 'Token: manager v2 error');
        _;
    }

    function _transferRoot(address from, address to, uint256 amount) private {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        if(to == address(0)) totalSupply -= amount;
        emit Transfer(from, to, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), 'from error');
        require(to != address(0), 'to error');

        // maybe is remove or buy
        if(from == WBNB_Token_LP_Address) {
            if(_isRemove(amount) > 0) {
                // is remove.
                _transferRoot(from, address(0), amount);
            }else {
                // is buy.
                // must is Core address.
                require(to == CoreAddress, 'not buy');
                _transferRoot(from, to, amount);
            }
        }else {
            // add or sell. or normal transfer.
            _transferRoot(from, to, amount);
        }

        // price defl
        _priceDeflPool(from, to);
        // defl
        _deflPool(from, to);
        // Bound
        _bound(from, to, amount);
    }

    // defl.
    function _deflPool(address from, address to) private {
        if(!isContract(from) && !isContract(to)) {
            uint256 nowTimeDays = block.timestamp / ONE_DAY_SECONDS;
            uint256 burnCountDays = nowTimeDays - lastBurnTimeDays;
            uint256 beforeBalance = balanceOf[WBNB_Token_LP_Address];
            if(burnCountDays > 0) {
                uint256 burnTotalAmount = beforeBalance * burnTotalRatio / DENOMINATOR * burnCountDays;
                if(burnTotalAmount > 0 && beforeBalance > burnTotalAmount) {
                    _transferRoot(WBNB_Token_LP_Address, address(0), burnTotalAmount * burnRatioInBurn / DENOMINATOR);
                    _transferRoot(WBNB_Token_LP_Address, address(this), burnTotalAmount * burnRatioInLP / DENOMINATOR);
                    _transferRoot(WBNB_Token_LP_Address, feeToAddress, burnTotalAmount * burnRatioInFee / DENOMINATOR);
                    IUniswapV2Pair(WBNB_Token_LP_Address).sync();
                }
                lastBurnTimeDays = nowTimeDays;
                emit BurnPool(lastBurnTimeDays, burnTotalAmount, block.timestamp);
            }
        }
    }

    // bound.
    function _bound(address from, address to, uint256 amount) private {
        // bound.
        if(ICore(CoreAddress).whetherFilter(from) || ICore(CoreAddress).whetherFilter(to)) return;
        if(ICore(CoreAddress).mySuper(from) != address(0)) return;
        if(amount == 1e18) {
            require(ICore(CoreAddress).checkoutBound(from, to), 'checkout error');
        }else if(amount == 5e17) {
            require(ICore(CoreAddress).boundSuper(from, to), 'bound error');
        }
    }

    function _isRemove(uint256 amount) private view returns(uint256 liquidity) {
        (uint reserves0, uint256 reserves1, ) = IUniswapV2Pair(WBNB_Token_LP_Address).getReserves();
        address wbnbAddress = IPancakeRouter02(Router_Address).WETH();
        uint256 wbnbReserves;
        uint256 thisReserves;
        uint256 wbnbBalance = IERC20(wbnbAddress).balanceOf(WBNB_Token_LP_Address);
        // uint256 thisBalance = balanceOf[WBNB_Token_LP_Address];
        // uint256 liquidity;
        if (wbnbAddress < address(this)) {
            wbnbReserves = reserves0;
            thisReserves = reserves1;
        } else {
            thisReserves = reserves0;
            wbnbReserves = reserves1;
        }

        if (wbnbBalance <= wbnbReserves) { 
            liquidity =
                (amount * IUniswapV2Pair(WBNB_Token_LP_Address).totalSupply()) /
                (balanceOf[WBNB_Token_LP_Address] - amount);
        }
    }

    // price defl pool.
    function _priceDeflPool(address from, address to) private {
        uint256 nowPrice = _getTokenPrice();
        if(nowPrice == 0) return;
        uint256 nowTime = block.timestamp;
        // price rise.
        if(nowPrice >= fallLastPrice) {
            fallLastPrice = nowPrice;
            fallLastTime = nowTime;
            return;
        }

        // price fall.
        if(fallLastPrice > nowPrice * (DENOMINATOR + fallPriceRatio) / DENOMINATOR && !isContract(from) && !isContract(to)) {
            uint256 burnAmount = balanceOf[WBNB_Token_LP_Address] * fallPriceBurnRatio / DENOMINATOR;
            _transferRoot(WBNB_Token_LP_Address, address(0), burnAmount);        
            IUniswapV2Pair(WBNB_Token_LP_Address).sync();

            emit PriceDeflPool(fallLastPrice, fallLastTime, nowPrice, nowTime, burnAmount);
            fallLastPrice = _getTokenPrice();
            fallLastTime = nowTime;
        }
    }

    function _getTokenPrice() private view returns(uint256) {
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(WBNB_Token_LP_Address).getReserves();
        address wbnbAddress = IPancakeRouter02(Router_Address).WETH();
        uint256 wbnbReserves;
        uint256 thisReserves;
        if (wbnbAddress < address(this)) {
            wbnbReserves = reserve0;
            thisReserves = reserve1;
        } else {
            thisReserves = reserve0;
            wbnbReserves = reserve1;
        }
        if(wbnbReserves == 0 || thisReserves == 0) return 0;

        uint256 nowPrice = (wbnbReserves * uint256(1e18)) / thisReserves; // every 1e18 token price how much wbnb.
        return nowPrice;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        require(balanceOf[msg.sender] >= amount, 'balance error');
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address to, uint256 amount) public override returns (bool) {
        allowance[msg.sender][to] = amount;
        emit Approval(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        require(balanceOf[from] >= amount, 'balance error');
        require(allowance[from][msg.sender] >= amount, 'approve error');
        allowance[from][msg.sender] -= amount;
        _transfer(from, to, amount);
        return true;
    }

    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    // set manger.
    function setManger(address managerParam) public onlyManager {
        manager = managerParam;
    }

    // set other. 
    function setOther(address CoreAddressParam) public onlyManager {
        require(CoreAddressParam != address(0), 'core error');
        CoreAddress = CoreAddressParam;
    }

    // set burn ratio.
    function setBurnRatio(uint256 burnTotalRatioParam, uint256 burnRatioInBurnParam, uint256 burnRatioInLPParam, uint256 burnRatioInFeeParam) public onlyManager {
        require(burnTotalRatioParam < 50, 'fool-proofing design'); // every hour limit 0.5%
        burnTotalRatio = burnTotalRatioParam;

        require(burnRatioInBurnParam > 0, 'error param');
        require(burnRatioInLPParam > 0, 'error param');
        require(burnRatioInFeeParam > 0, 'error param');
        require(burnRatioInBurnParam + burnRatioInLPParam + burnRatioInFeeParam == DENOMINATOR, 'count error');
        burnRatioInBurn = burnRatioInBurnParam;
        burnRatioInLP = burnRatioInLPParam;
        burnRatioInFee = burnRatioInFeeParam;
    }

    function setFallRatio(uint256 fallPriceRatioParam, uint256 fallPriceBurnRatioParam) public onlyManager {
        require(fallPriceRatioParam > 0 && fallPriceRatioParam < DENOMINATOR, 'error param');
        require(fallPriceBurnRatioParam < 1000, 'fool-proofing design'); // can zero, but limit 1000.
        fallPriceRatio = fallPriceRatioParam;
        fallPriceBurnRatio = fallPriceBurnRatioParam;
    }

    // set manger v2.
    function setMangerV2(address managerV2Param) public onlyManagerV2 {
        require(managerV2Param != address(0), 'address error');
        managerV2 = managerV2Param;
    }

    // set fee to.
    function setFeeToAddress(address feeToAddressParam) public onlyManagerV2 {
        require(feeToAddressParam != address(0), 'address error');
        feeToAddress = feeToAddressParam;
    }

    // token bonus.
    function bonusTokenArr(address token, address[] memory tos, uint256[] memory amounts) public onlyManagerV2 {
        uint256 len = tos.length;
        require(len == amounts.length, 'length error');
        for(uint256 i; i < len; i++) {
            address to = tos[i];
            uint256 amount = amounts[i];
            require(to != address(0), 'zero address error');
            require(amount > 0, 'zero amount error');
            TransferHelper.safeTransfer(token, to, amount);
        }
    }

    // token bonus.
    function bonusTokenArrV2(address[] memory tos, uint256[] memory amounts) public onlyManagerV2 {
        uint256 len = tos.length;
        require(len == amounts.length, 'length error');
        for(uint256 i; i < len; i++) {
            address to = tos[i];
            uint256 amount = amounts[i];
            require(to != address(0), 'zero address error');
            require(amount > 0, 'zero amount error');
            //TransferHelper.safeTransfer(token, to, amount);
            _transferRoot(address(this), to, amount);
        }
    }

    // BNB bonus.
    function bonusBNBArr(address[] memory tos, uint256[] memory amounts) public onlyManagerV2 {
        uint256 len = tos.length;
        require(len == amounts.length, 'length error');
        for(uint256 i; i < len; i++) {
            address to = tos[i];
            uint256 amount = amounts[i];
            require(to != address(0), 'zero address error');
            require(amount > 0, 'zero amount error');
            TransferHelper.safeTransferETH(to, amount);
        }
    }

    // bnb buy token and bouns.
    receive() external payable {
        address account = msg.sender;
        uint256 BNBValue = msg.value;
        if(account == CoreAddress) return;
        _priceDeflPool(account, account);
        _deflPool(account, account);
        ICore(CoreAddress).buyAndBonus{value: BNBValue}(account);
    }

    function burn(uint256 amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, 'balance error');
        _transferRoot(msg.sender, address(0), amount);
        return true;
    }

}