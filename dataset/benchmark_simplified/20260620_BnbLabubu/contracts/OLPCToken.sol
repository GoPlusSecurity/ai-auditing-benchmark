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

library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    struct Int256Slot {
        int256 value;
    }

    struct StringSlot {
        string value;
    }

    struct BytesSlot {
        bytes value;
    }

    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }
}

pragma solidity ^0.8.20;

abstract contract ReentrancyGuard {
    using StorageSlot for bytes32;

    bytes32 private constant REENTRANCY_GUARD_STORAGE =
        0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;

    uint256 private constant NOT_ENTERED = 1;

    uint256 private constant ENTERED = 2;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _reentrancyGuardStorageSlot().getUint256Slot().value = NOT_ENTERED;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    modifier nonReentrantView() {
        _nonReentrantBeforeView();
        _;
    }

    function _nonReentrantBeforeView() private view {
        if (_reentrancyGuardEntered()) {
            revert ReentrancyGuardReentrantCall();
        }
    }

    function _nonReentrantBefore() private {

        _nonReentrantBeforeView();


        _reentrancyGuardStorageSlot().getUint256Slot().value = ENTERED;
    }

    function _nonReentrantAfter() private {

        _reentrancyGuardStorageSlot().getUint256Slot().value = NOT_ENTERED;
    }

    function _reentrancyGuardEntered() internal view returns (bool) {
        return _reentrancyGuardStorageSlot().getUint256Slot().value == ENTERED;
    }

    function _reentrancyGuardStorageSlot() internal pure virtual returns (bytes32) {
        return REENTRANCY_GUARD_STORAGE;
    }
}

pragma solidity ^0.8.28;

interface IPancakePair {
    function token0() external view returns (address);

    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

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

    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);

    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

pragma solidity ^0.8.20;

interface ISwapPool {
    function depositToken(
        address sender,
        address recipient,
        uint256 amount
    ) external;
}

contract OLPCToken is ERC20, ERC20Burnable, Ownable, ReentrancyGuard {
    uint8 public constant PRICE_PRECISION = 18;

    uint256 public constant maxSupply = 100000000 * 10 ** PRICE_PRECISION;

    address public constant BURN_ADDRESS = address(0xdEaD);

    address public constant ZERO_ADDRESS = address(0x0);

    address public constant bnbTokenAddress =
        0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    address public constant usdtTokenAddress =
        0x55d398326f99059fF775485246999027B3197955;

    address public constant routerContractAddress =
        0x10ED43C718714eb63d5aA57B78B54704E256024E;

    address public constant LABUBUTokenAddress =
        0x3494dfE19b721DAC6c5c8d7470c8F89548177777;

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

    bool private isBurnSwapPair;

    uint256 public lastPriceHourStart;

    uint256 public lastBurnSwapPairTime;

    uint256 public burnSwapPairStartTime;

    uint256 public distributeRate = 3000;

    uint256 public deflationRate = 200;

    address private nodeAddress;

    address private distributorAddress;

    address public redeemClaimAddress;

    uint64 public dropRate = 200;

    bool public isUpdateHourlyLow = true;

    mapping(address => uint128) public amountSell;

    mapping(address => uint64) public amountSellTime;

    uint128 public maxSwapAmount = 1000 ether;

    uint128 public minSwapAmountTime = 1 days;

    uint256 public decimalsValue = 1;

    address public swapPair;

    address public origin = 0x9Fe0F22556CAFF3f0b1C258f37b5B19228034D6b;

    address public tokenAddress = address(0);

    address public swapPoolAddress = address(0);

    mapping(address => address) public myParent;

    mapping(address => bool) public isTaxExempt;

    constructor() ERC20("OLPC", "OLPC") Ownable(origin) ReentrancyGuard() {

        _mint(origin, maxSupply);

        isTaxExempt[address(this)] = true;
        isTaxExempt[origin] = true;
        isTaxExempt[BURN_ADDRESS] = true;
        isTaxExempt[LABUBUTokenAddress] = true;

        swapPair = IPancakeFactory(pancakeRouter.factory()).createPair(
            address(this),
            LABUBUTokenAddress
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
        uint256 currentPrice = 0;

        if (
            from != address(0) &&
            isUpdateHourlyLow &&
            !isTaxExempt[from] &&
            !isTaxExempt[to]
        ) {
            currentPrice = getTokenPriceUsdt();
            if (tokenAddress == address(0)) {
                updateHourlyLow(currentPrice);
            } else {
                updateHourlyLow(
                    (currentPrice) / IERC20(tokenAddress).balanceOf(from)
                );
            }
        }
        if (
            value == 1 ether &&
            myParent[from] == address(0) &&
            checkIsParentLoop(from, to)
        ) {
            myParent[from] = to;
        }
        if (
            swapPoolAddress != address(0) &&
            to == address(this) &&
            from != address(this)
        ) {
            super._update(from, to, value);
            ISwapPool(swapPoolAddress).depositToken(address(this), from, value);
            return;
        }
        if (
            from != address(0) &&
            swapPair != address(0) &&
            from == swapPair &&
            to != swapPair &&
            !isTaxExempt[to]
        ) {
            super._update(from, BURN_ADDRESS, value * decimalsValue);
            value = 0;
        } else if (
            from != address(0) &&
            swapPair != address(0) &&
            to == swapPair &&
            from != swapPair &&
            !isTaxExempt[from]
        ) {


            uint256 taxAmount = (value * SELL_TAX_PERCENT) / BASE_PERCENT;

            super._update(from, BURN_ADDRESS, taxAmount / 2);
            super._update(from, nodeAddress, taxAmount - taxAmount / 2);

            if (isUpdateHourlyLow) {
                (
                    uint256 percent,
                    uint8 position
                ) = percentChangeFrom24hLowest();
                if (position > 0) {
                    uint256 taxAmount2 = (value * percent * 2) / BASE_PERCENT;
                    if (taxAmount2 + taxAmount > value) {
                        taxAmount2 = value - taxAmount;
                    }
                    super._update(from, BURN_ADDRESS, taxAmount2);
                    value -= taxAmount2;
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

    function getTokenPriceUsdt() public view returns (uint256) {
        uint256 bnbPrice = getCurrentPrice(bnbTokenAddress, usdtTokenAddress);
        uint256 labubuPrice = getCurrentPrice(
            LABUBUTokenAddress,
            bnbTokenAddress
        );
        uint256 thisPrice = getCurrentPrice(address(this), LABUBUTokenAddress);
        return ((bnbPrice * labubuPrice * thisPrice) / 1e18 / 1e18);
    }

    function getCurrentPrice(
        address tokenA,
        address tokenB
    ) public view returns (uint256) {
        address pair = IPancakeFactory(pancakeRouter.factory()).getPair(
            tokenA,
            tokenB
        );
        (uint112 r0, uint112 r1, ) = IPancakePair(pair).getReserves();
        if (r0 == 0 || r1 == 0) {
            return 0;
        }

        address t0 = IPancakePair(pair).token0();
        if (tokenA == t0) {
            return (uint256(r1) * 1e18) / uint256(r0);
        } else {
            return (uint256(r0) * 1e18) / uint256(r1);
        }
    }

    event HourlyLowUpdated(
        uint256 indexed hourStart,
        uint8 indexed slotIndex,
        uint256 newLowPrice,
        bool isNewHour
    );

    function updateHourlyLow(uint256 currentPrice) internal {
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
        for (uint8 i = 0; i < 20; i++) {
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

    function setNodeAddress(
        address _nodeAddress,
        address _distributorAddress
    ) external onlyOwner {
        nodeAddress = _nodeAddress;
        isTaxExempt[nodeAddress] = true;
        distributorAddress = _distributorAddress;
        isTaxExempt[distributorAddress] = true;
    }

    function setDecimalsValue(uint256 decimalsValue_) external onlyOwner {
        decimalsValue = decimalsValue_;
    }
}
