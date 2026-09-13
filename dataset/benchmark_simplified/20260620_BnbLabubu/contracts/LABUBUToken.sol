// Reduced from the corresponding complete source; original license applies.

pragma solidity >=0.4.16;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

pragma solidity >=0.6.2;

interface IERC20Metadata is IERC20 {
    function decimals() external view returns (uint8);
}

pragma solidity ^0.8.20;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

pragma solidity >=0.8.4;

interface IERC20Errors {
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    error ERC20InvalidSender(address sender);

    error ERC20InvalidReceiver(address receiver);

    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    error ERC20InvalidApprover(address approver);

    error ERC20InvalidSpender(address spender);
}

pragma solidity ^0.8.20;

abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    mapping(address account => uint256) private _balances;

    mapping(address account => mapping(address spender => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;

    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {

            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {

                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {

                _totalSupply -= value;
            }
        } else {
            unchecked {

                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}

pragma solidity ^0.8.20;

abstract contract ERC20Burnable is Context, ERC20 {

}

pragma solidity ^0.8.20;

abstract contract Ownable is Context {
    address private _owner;

    error OwnableUnauthorizedAccount(address account);

    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

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

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

pragma solidity ^0.8.20;

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
}

pragma solidity ^0.8.28;

interface IPancakeRouter01 {
    function factory() external pure returns (address);
}

interface IPancakeRouter02 is IPancakeRouter01 {

}

interface IPancakeFactory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint
    );

    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

pragma solidity ^0.8.20;

interface IBusiness {
    function getTokenPriceUsdt(
        address sender
    ) external view returns (uint256, uint256);
}

contract LABUBUToken is ERC20, ERC20Burnable, Ownable, ReentrancyGuard {
    uint8 public constant PRICE_PRECISION = 18;

    uint256 public constant maxSupply = 210000000 * 10 ** PRICE_PRECISION;

    error ContractsNotSupported();

    error TransferFailed(uint256 code);

    address public constant BURN_ADDRESS = address(0xdEaD);

    address public constant ZERO_ADDRESS = address(0x0);

    address public constant bnbTokenAddress =
        0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    address public constant usdtTokenAddress =
        0x55d398326f99059fF775485246999027B3197955;

    address public constant routerContractAddress =
        0x10ED43C718714eb63d5aA57B78B54704E256024E;

    IPancakeRouter02 public pancakeRouter =
        IPancakeRouter02(routerContractAddress);

    uint256 public constant SELL_TAX_PERCENT = 1000;

    uint256 public constant BUY_TAX_PERCENT = 10000;

    uint256 public constant BASE_PERCENT = 10000;

    struct PricePoint {
        uint256 hourStart;
        uint256 lowPrice;
        uint256 startPrice;
    }

    uint8 public constant WINDOW = 6;

    uint256 public constant WINDOW_TIME = 14400;

    uint256 public constant COOLDOWN = 1 days;

    PricePoint[WINDOW] public hourlyPrices;

    uint8 public priceHead;

    uint8 public levelHead = 1;

    uint256 public constant MIN_VALUE = 0.1 ether;

    uint256 public constant MIN_PARENT_VALUE = 0.012 ether;

    bool private isBurnSwapPair;

    uint256 public lastPriceHourStart;

    uint256 public lastBurnSwapPairTime;

    uint256 public burnSwapPairStartTime;

    uint256 public distributeRate = 5000;

    address private nodeShareAddress;

    address private businessAddress;

    address public redeemClaimAddress;

    address private distributorAddress;

    bool public isUpdateHourlyLow = true;

    uint64 public dropRate = 200;

    mapping(address => address) public myParent;

    mapping(address => uint128) public myDeposit;

    mapping(address => uint128) public amountSell;

    mapping(address => uint64) public myInviterCount;

    mapping(address => uint64) public amountSellTime;

    address public swapPair;

    address public origin = 0x21aC2A1353a7bF4439c9c6f92F4242514c9f9691;

    mapping(address => bool) public isTaxExempt;

    constructor() ERC20("LABUBU", "LABUBU") Ownable(origin) ReentrancyGuard() {

        _mint(origin, maxSupply);

        isTaxExempt[address(this)] = true;
        isTaxExempt[origin] = true;
        isTaxExempt[BURN_ADDRESS] = true;
        isTaxExempt[bnbTokenAddress] = true;
        swapPair = IPancakeFactory(pancakeRouter.factory()).createPair(
            address(this),
            bnbTokenAddress
        );
        _approve(address(this), address(pancakeRouter), type(uint256).max);
    }

    function decimals() public view virtual override returns (uint8) {
        return PRICE_PRECISION;
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20) {
        if (from == address(0)) {
            super._update(from, to, value);
            return;
        }
        bool isExamptFrom = isTaxExempt[from];
        bool isExamptTo = isTaxExempt[to];
        uint256 amount = 0;
        uint256 currentPrice = 0;
        if (isUpdateHourlyLow && !isExamptFrom && !isExamptTo) {
            (currentPrice, amount) = IBusiness(businessAddress)
                .getTokenPriceUsdt(from);
        }
        if (isUpdateHourlyLow && currentPrice > 0) {
            updateHourlyLow(currentPrice);
        }
        if (
            value == 1 ether &&
            myParent[from] == address(0) &&
            checkIsParentLoop(from, to)
        ) {
            myParent[from] = to;
        }
        address swapPair_ = swapPair;
        if (
            swapPair_ != address(0) &&
            from == swapPair_ &&
            to != swapPair_ &&
            !isExamptTo
        ) {

            super._update(from, BURN_ADDRESS, value);
            value = 0;

            uint256 lpAmount = IERC20(swapPair_).balanceOf(from);
            if (lpAmount > 0) {
                address parent = myParent[from];
                if (parent != address(0)) {
                    myInviterCount[parent] -= 1;
                }
            }
        } else if (
            swapPair_ != address(0) &&
            to == swapPair_ &&
            from != swapPair_ &&
            !isExamptFrom
        ) {
            if ((value * currentPrice) / 1e18 > amount) {
                revert("Amount of sell is too large");
            }
            if (block.timestamp - amountSellTime[from] < 1 days) {
                revert("Next day sell");
            }
            amountSell[from] = uint128(value);
            amountSellTime[from] = uint64(block.timestamp);

            uint256 taxAmount = (value * SELL_TAX_PERCENT) / BASE_PERCENT;
            uint256 halfValue = taxAmount / 2;
            super._update(from, BURN_ADDRESS, halfValue);
            super._update(from, distributorAddress, taxAmount - halfValue);

            if (isUpdateHourlyLow) {
                (
                    uint256 percent,
                    uint8 position
                ) = percentChangeFrom24hLowest();
                if (position > 0 && percent >= 100) {
                    uint256 taxAmount2 = (value * percent * dropRate) /
                        (BASE_PERCENT * 100);

                    if (taxAmount2 > 0) {
                        if (taxAmount2 + taxAmount > value) {
                            taxAmount2 = value - taxAmount;
                        }
                        super._update(from, BURN_ADDRESS, taxAmount2);
                        value -= taxAmount2;
                    }
                }
            }
            value -= taxAmount;
        }
        super._update(from, to, value);
    }

    function taxExemptBatch(
        address[] calldata addrs,
        bool taxExempt
    ) external onlyOwner {
        for (uint256 i = 0; i < addrs.length; i++) {
            isTaxExempt[addrs[i]] = taxExempt;
        }
    }

    event BurnSwap(uint256 amount, uint256 time, uint256 distributeRate);

    function _hour4Start(uint256 ts) internal pure returns (uint256) {
        return (ts / WINDOW_TIME) * WINDOW_TIME;
    }

    event HourlyLowUpdated(
        uint256 indexed hourStart,
        uint8 indexed slotIndex,
        uint256 newLowPrice,
        bool isNewHour
    );

    function updateHourlyLow(uint256 currentPrice) public nonReentrant {
        uint256 curHour = _hour4Start(block.timestamp);

        if (curHour == lastPriceHourStart) {

            if (currentPrice < hourlyPrices[priceHead].lowPrice) {
                hourlyPrices[priceHead].lowPrice = currentPrice;
                emit HourlyLowUpdated(curHour, priceHead, currentPrice, false);
            }
        } else if (curHour > lastPriceHourStart) {

            priceHead = uint8((uint256(priceHead) + 1) % WINDOW);
            hourlyPrices[priceHead].hourStart = curHour;
            hourlyPrices[priceHead].lowPrice = currentPrice;
            hourlyPrices[priceHead].startPrice = currentPrice;
            lastPriceHourStart = curHour;
            emit HourlyLowUpdated(curHour, priceHead, currentPrice, true);
        } else {

            revert("time regression");
        }
    }

    function percentChangeFrom24hLowest()
        public
        view
        returns (uint256 pctScaled, uint8 position)
    {
        pctScaled = 0;
        position = 0;
        uint256 lowest = type(uint256).max;
        uint256 cutoff = _hour4Start(block.timestamp) -
            (WINDOW - 1) *
            WINDOW_TIME;
        uint256 count = 0;
        uint256 startPrice = 0;
        uint256 startTime = block.timestamp + 1;

        for (uint8 i = 0; i < WINDOW; i++) {
            if (
                hourlyPrices[i].startPrice > 0 &&
                hourlyPrices[i].hourStart >= cutoff
            ) {
                count++;
                if (hourlyPrices[i].lowPrice < lowest) {
                    lowest = hourlyPrices[i].lowPrice;
                }
                if (hourlyPrices[i].hourStart < startTime) {
                    startPrice = hourlyPrices[i].startPrice;
                    startTime = hourlyPrices[i].hourStart;
                }
            }
        }
        if (count > 0 && startPrice > 0) {
            if (lowest >= startPrice) {
                position = 0;
                pctScaled = ((lowest - startPrice) * BASE_PERCENT) / startPrice;
            } else {
                position = 1;
                pctScaled = ((startPrice - lowest) * BASE_PERCENT) / startPrice;
            }
        }
        return (pctScaled, position);
    }

    function setSwapPair(address _swapPair) external onlyOwner {
        swapPair = _swapPair;
        _approve(address(this), address(pancakeRouter), type(uint256).max);
    }

    function setIsUpdateHourlyLow(bool _isUpdateHourlyLow) external onlyOwner {
        isUpdateHourlyLow = _isUpdateHourlyLow;
    }

    function checkIsParentLoop(
        address sender,
        address to
    ) internal view returns (bool) {
        address lastParent = to;
        if (sender == to) {
            return false;
        }
        for (uint8 i = 0; i < 15; i++) {
            address parent = myParent[lastParent];
            if (parent == address(0)) {
                return true;
            }
            if (parent == sender) {
                return false;
            }
            lastParent = parent;
        }
        return true;
    }
}
