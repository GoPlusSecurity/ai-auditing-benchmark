// SPDX-License-Identifier: MIT
//9ecc02a53f8032a599c51cbc7f7c474835c40cb0e92543f7995708cce9e06df9
pragma solidity ^0.8.20;

// ---------------------------------------------------------------------------
// OpenZeppelin Contracts v5.4.0 (inlined from npm/@openzeppelin/contracts@5.4.0)
// ---------------------------------------------------------------------------

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 */
abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
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

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
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

// ---------------------------------------------------------------------------
// Project interfaces (inlined)
// ---------------------------------------------------------------------------

struct MintCyrusParams {
    uint256 strategyId;
    uint256 amount;
    uint256 start;
    uint256 finish;
}

struct PositionInfo {
    uint256 strategyId;
    uint256 amount;
    uint256 start;
    uint256 finish;
    uint256 totalClaimed;
    uint256 lastClaimed;
    uint256 unclaimed;
}

interface ICyrusPositionManager {
    function mint(address to, MintCyrusParams calldata params) external returns (uint256);

    function updatePosition(uint256 tokenId, PositionInfo calldata params) external;

    function getPosition(uint256 tokenId) external view returns (PositionInfo memory);

    function getPositions(uint256[] calldata tokenIds) external view returns (PositionInfo[] memory);

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function getPositionsValue(address addr) external view returns (uint256 value);

    function tokensOfOwner(address owner) external view returns (uint256[] memory);
}

struct MintParams {
    address token0;
    address token1;
    uint24 fee;
    int24 tickLower;
    int24 tickUpper;
    uint256 amount0Desired;
    uint256 amount1Desired;
    uint256 amount0Min;
    uint256 amount1Min;
    address recipient;
    uint256 deadline;
}

struct IncreaseLiquidityParams {
    uint256 tokenId;
    uint256 amount0Desired;
    uint256 amount1Desired;
    uint256 amount0Min;
    uint256 amount1Min;
    uint256 deadline;
}

struct DecreaseLiquidityParams {
    uint256 tokenId;
    uint128 liquidity;
    uint256 amount0Min;
    uint256 amount1Min;
    uint256 deadline;
}

struct CollectParams {
    uint256 tokenId;
    address recipient;
    uint128 amount0Max;
    uint128 amount1Max;
}

interface IPancakePositionManager {
    function mint(
        MintParams calldata params
    ) external payable returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    function positions(
        uint256 tokenId
    )
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    function increaseLiquidity(
        IncreaseLiquidityParams calldata params
    ) external payable returns (uint128 liquidity, uint256 amount0, uint256 amount1);

    function decreaseLiquidity(
        DecreaseLiquidityParams calldata params
    ) external payable returns (uint256 amount0, uint256 amount1);

    function collect(CollectParams calldata params) external payable returns (uint256 amount0, uint256 amount1);

    function burn(uint256 tokenId) external payable;

    function approve(address to, uint256 tokenId) external;

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function getApproved(uint256 tokenId) external view returns (address operator);

    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

interface ICyrusVault {
    function getAffiliate(address addr) external view returns (address);

    function getAffiliatesNumber(address addr) external view returns (uint256[] memory);

    function getAffiliateTurnover(address addr) external view returns (uint256);
}

interface IPancakeV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

interface IPancakePool {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint32 feeProtocol,
            bool unlocked
        );
}

// ---------------------------------------------------------------------------
// PancakeSwap util library (inlined from ./libs/PancakeSwapUtil.sol)
// ---------------------------------------------------------------------------

library PancakeSwapUtil {
    error T();
    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    uint8 internal constant RESOLUTION = 96;
    uint256 internal constant Q96 = 0x1000000000000000000000000;

    function getSqrtRatioAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
        unchecked {
            uint256 absTick = tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick));
            if (absTick > uint256(int256(MAX_TICK))) revert T();

            uint256 ratio = absTick & 0x1 != 0
                ? 0xfffcb933bd6fad37aa2d162d1a594001
                : 0x100000000000000000000000000000000;
            if (absTick & 0x2 != 0) ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
            if (absTick & 0x4 != 0) ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
            if (absTick & 0x8 != 0) ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
            if (absTick & 0x10 != 0) ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
            if (absTick & 0x20 != 0) ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
            if (absTick & 0x40 != 0) ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
            if (absTick & 0x80 != 0) ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
            if (absTick & 0x100 != 0) ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
            if (absTick & 0x200 != 0) ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
            if (absTick & 0x400 != 0) ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
            if (absTick & 0x800 != 0) ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
            if (absTick & 0x1000 != 0) ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
            if (absTick & 0x2000 != 0) ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
            if (absTick & 0x4000 != 0) ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
            if (absTick & 0x8000 != 0) ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
            if (absTick & 0x10000 != 0) ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
            if (absTick & 0x20000 != 0) ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
            if (absTick & 0x40000 != 0) ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
            if (absTick & 0x80000 != 0) ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

            if (tick > 0) ratio = type(uint256).max / ratio;
            sqrtPriceX96 = uint160((ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1));
        }
    }

    function mulDiv(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            uint256 prod0;
            uint256 prod1;
            assembly {
                let mm := mulmod(a, b, not(0))
                prod0 := mul(a, b)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            if (prod1 == 0) {
                require(denominator > 0);
                assembly {
                    result := div(prod0, denominator)
                }
                return result;
            }

            require(denominator > prod1);

            uint256 remainder;
            assembly {
                remainder := mulmod(a, b, denominator)
            }

            assembly {
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            uint256 twos = (0 - denominator) & denominator;

            assembly {
                denominator := div(denominator, twos)
            }

            assembly {
                prod0 := div(prod0, twos)
            }

            assembly {
                twos := add(div(sub(0, twos), twos), 1)
            }
            prod0 |= prod1 * twos;

            uint256 inv = (3 * denominator) ^ 2;

            inv *= 2 - denominator * inv;
            inv *= 2 - denominator * inv;
            inv *= 2 - denominator * inv;
            inv *= 2 - denominator * inv;
            inv *= 2 - denominator * inv;
            inv *= 2 - denominator * inv;

            result = prod0 * inv;
            return result;
        }
    }

    function toUint128(uint256 x) private pure returns (uint128 y) {
        require((y = uint128(x)) == x);
    }

    function getLiquidityForAmount0(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount0
    ) internal pure returns (uint128 liquidity) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        uint256 intermediate = mulDiv(sqrtRatioAX96, sqrtRatioBX96, Q96);
        unchecked {
            return toUint128(mulDiv(amount0, intermediate, sqrtRatioBX96 - sqrtRatioAX96));
        }
    }

    function getLiquidityForAmount1(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount1
    ) internal pure returns (uint128 liquidity) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        unchecked {
            return toUint128(mulDiv(amount1, Q96, sqrtRatioBX96 - sqrtRatioAX96));
        }
    }

    function getLiquidityForAmounts(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount0,
        uint256 amount1
    ) internal pure returns (uint128 liquidity) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        if (sqrtRatioX96 <= sqrtRatioAX96) {
            liquidity = getLiquidityForAmount0(sqrtRatioAX96, sqrtRatioBX96, amount0);
        } else if (sqrtRatioX96 < sqrtRatioBX96) {
            uint128 liquidity0 = getLiquidityForAmount0(sqrtRatioX96, sqrtRatioBX96, amount0);
            uint128 liquidity1 = getLiquidityForAmount1(sqrtRatioAX96, sqrtRatioX96, amount1);

            liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
        } else {
            liquidity = getLiquidityForAmount1(sqrtRatioAX96, sqrtRatioBX96, amount1);
        }
    }

    function getAmount0ForLiquidity(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount0) {
        unchecked {
            if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

            return mulDiv(uint256(liquidity) << RESOLUTION, sqrtRatioBX96 - sqrtRatioAX96, sqrtRatioBX96) / sqrtRatioAX96;
        }
    }

    function getAmount1ForLiquidity(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        unchecked {
            return mulDiv(liquidity, sqrtRatioBX96 - sqrtRatioAX96, Q96);
        }
    }

    function getAmountsForLiquidity(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        if (sqrtRatioX96 <= sqrtRatioAX96) {
            amount0 = getAmount0ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity);
        } else if (sqrtRatioX96 < sqrtRatioBX96) {
            amount0 = getAmount0ForLiquidity(sqrtRatioX96, sqrtRatioBX96, liquidity);
            amount1 = getAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioX96, liquidity);
        } else {
            amount1 = getAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity);
        }
    }
}

contract CyrusTreasury is Ownable, ReentrancyGuard {
    event Exited(
        address indexed user,
        uint256 amount,
        uint256 timestamp,
        uint256 tokenId
    );
    event AffRewardsAccrued(
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );

    ICyrusPositionManager public CyrusPositionManager;
    ICyrusVault public Vault;

    bool initialized = false;

    uint256[] private tokenIds;
    uint256[] private percents;
    uint256[20] private affPercents;
    uint256[20] private minAffValues;
    uint256[20] private minAffTurnovers;

    uint256 private lastWithdrawIndex;

    uint256 constant PERCENT_DIVIDER = 1000;
    uint256 public constant TIME_STEP = 1 days;
    uint256 public constant PERFOMANCE_FEE = 170; //17%

    IPancakePositionManager constant PancakePositionManager =
        IPancakePositionManager(0x46A15B0b27311cedF172AB29E4f4766fbE7F4364);
    IPancakeV3Factory constant PancakeFactory =
        IPancakeV3Factory(0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865);

    IERC20 public constant USDT =
        IERC20(0x55d398326f99059fF775485246999027B3197955);

    address public constant performanceFeeReceiver =
        address(0x6Cd7bbB8a8C0C1B24a449c3AD8F913974de7b009);

    // address => how many rewards earned from friends
    mapping(address => mapping(uint256 => uint256)) public affiliatesRewards;

    // address => how many unclaimed affiliate rewards user has
    mapping(address => uint256) public unclaimedAffRewards;

    //tokenId => usdtIsToken0
    mapping(uint256 => bool) public _usdtIsToken0;

    constructor(
        uint256[] memory _percents,
        uint256[20] memory _affPercents,
        uint256[20] memory _minAffValues,
        uint256[20] memory _minAffTurnovers
    ) Ownable(msg.sender) {
        require(_affPercents.length == 20, "Invalid affPercents length");
        require(_minAffValues.length == 20, "Invalid minAffValues length");
        require(
            _minAffTurnovers.length == 20,
            "Invalid minAffTurnovers length"
        );

        minAffValues = _minAffValues;
        minAffTurnovers = _minAffTurnovers;
        percents = _percents;
        affPercents = _affPercents;

        (bool success, bytes memory data) = address(USDT).call(
            abi.encodeWithSelector(
                USDT.approve.selector,
                address(PancakePositionManager),
                type(uint256).max
            )
        );

        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "USDT approve failed"
        );
    }

    function exit(uint256 tokenId) external nonReentrant {
        require(initialized, "Contract is not initialized");
        require(CyrusPositionManager.ownerOf(tokenId) == address(msg.sender));

        (
            uint256 totalAmount,
            PositionInfo memory positionInfo
        ) = getPendingRewards(tokenId);

        require(
            positionInfo.finish <= block.timestamp,
            "Position is not finished yet"
        );
        require(positionInfo.amount > 0, "Position is empty");

        PositionInfo memory updatedPosition = PositionInfo({
            strategyId: positionInfo.strategyId,
            amount: 0,
            start: positionInfo.start,
            finish: positionInfo.finish,
            totalClaimed: positionInfo.totalClaimed +
                totalAmount +
                positionInfo.amount,
            lastClaimed: block.timestamp,
            unclaimed: 0
        });

        if (totalAmount > 0) {
            updateAffRewards(totalAmount);
        }

        CyrusPositionManager.updatePosition(tokenId, updatedPosition);

        uint256 feeAmount = (totalAmount * PERFOMANCE_FEE) / PERCENT_DIVIDER;

        uint256 toWithdraw = totalAmount + positionInfo.amount - feeAmount;

        if (feeAmount > 0) {
            withdrawUSDTFromAny(feeAmount, performanceFeeReceiver);
        }

        withdrawUSDTFromAny(toWithdraw, msg.sender);

        emit Exited(msg.sender, toWithdraw, block.timestamp, tokenId);
    }

    /**
     * @notice Withdraws USDT from any available Pancake positions with up to 0.5% slippage tolerance.
     * @dev This function iterates over all tokenIds stored in Treasury and withdraws USDT liquidity proportionally.
     *      The final withdrawn amount may be up to 0.5% lower than requested due to price movement or rounding.
     * @param usdtAmountWithSlippage The target USDT amount to withdraw (0.5% slippage tolerance is accepted).
     * @param to The recipient address.
     */

    function withdrawUSDTFromAny(
        uint256 usdtAmountWithSlippage,
        address to
    ) internal {
        uint256 len = tokenIds.length;
        require(len > 0, "No positions");

        uint256 totalWithdrawn = 0;
        uint256 startIndex = lastWithdrawIndex % len;

        for (
            uint256 i = 0;
            i < len && totalWithdrawn < usdtAmountWithSlippage;
            i++
        ) {
            uint256 index = (startIndex + i) % len;
            uint256 tokenId = tokenIds[index];

            (
                ,
                address operator,
                address token0,
                address token1,
                uint24 fee,
                int24 tickLower,
                int24 tickUpper,
                uint128 liquidity,
                ,
                ,
                ,

            ) = PancakePositionManager.positions(tokenId);

            bool isToken0USDT = _usdtIsToken0[tokenId];
            address owner = PancakePositionManager.ownerOf(tokenId);
            bool isApprovedForAll = PancakePositionManager.isApprovedForAll(
                owner,
                address(this)
            );
            if (
                owner != address(this) &&
                operator != address(this) &&
                !isApprovedForAll
            ) continue;

            address pool = PancakeFactory.getPool(token0, token1, fee);
            if (pool == address(0)) continue;

            (uint160 sqrtPriceX96, , , , , , ) = IPancakePool(pool).slot0();
            uint160 sqrtRatioAX96 = PancakeSwapUtil.getSqrtRatioAtTick(
                tickLower
            );
            uint160 sqrtRatioBX96 = PancakeSwapUtil.getSqrtRatioAtTick(
                tickUpper
            );
            (uint256 amount0, uint256 amount1) = PancakeSwapUtil
                .getAmountsForLiquidity(
                    sqrtPriceX96,
                    sqrtRatioAX96,
                    sqrtRatioBX96,
                    liquidity
                );

            uint256 availableUSDT = isToken0USDT ? amount0 : amount1;
            if (availableUSDT == 0) continue;

            uint256 remaining = usdtAmountWithSlippage - totalWithdrawn;
            uint128 liquidityToUse = liquidity;
            if (availableUSDT > remaining) {
                liquidityToUse = uint128(
                    (uint256(liquidity) * remaining) / availableUSDT
                );
            }

            uint256 minAmount = (remaining * 995) / 1000;
            uint256 usdtReceived;

            if (isToken0USDT) {
                usdtReceived = decreaseLiquidity(
                    tokenId,
                    liquidityToUse,
                    minAmount,
                    0,
                    to
                );
            } else {
                usdtReceived = decreaseLiquidity(
                    tokenId,
                    liquidityToUse,
                    0,
                    minAmount,
                    to
                );
            }

            totalWithdrawn += usdtReceived;
        }

        lastWithdrawIndex = (startIndex + 1) % len;

        require(
            totalWithdrawn >= (usdtAmountWithSlippage * 995) / 1000,
            "Insufficient USDT withdrawn (slippage exceeded or low liquidity)"
        );
    }

    function decreaseLiquidity(
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        address to
    ) internal returns (uint256 usdtWithdrawn) {
        (uint256 amount0, uint256 amount1) = PancakePositionManager
            .decreaseLiquidity(
                DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: liquidity,
                    amount0Min: amount0Min,
                    amount1Min: amount1Min,
                    deadline: block.timestamp + 60
                })
            );

        require(amount0 > 0 || amount1 > 0, "DecreaseLiquidity failed");

        require(amount0 <= type(uint128).max, "amount0 overflow");
        require(amount1 <= type(uint128).max, "amount1 overflow");

        (uint256 amount00, uint256 amount11) = PancakePositionManager.collect(
            CollectParams({
                tokenId: tokenId,
                recipient: to,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        require(amount00 > 0 || amount11 > 0, "Collect failed");

        bool isToken0USDT = _usdtIsToken0[tokenId];

        usdtWithdrawn = isToken0USDT ? amount00 : amount11;
    }

    function updateAffRewards(uint256 amount) internal {
        address upline = Vault.getAffiliate(msg.sender);
        for (uint256 i = 0; i < 20; i++) {
            if (upline != address(0)) {
                uint256 userTurnover = getUserTurnover(upline);
                uint256 userValue = CyrusPositionManager.getPositionsValue(
                    upline
                );

                if (
                    userTurnover >= minAffTurnovers[i] &&
                    userValue >= minAffValues[i]
                ) {
                    uint256 rewards = (amount * affPercents[i]) /
                        PERCENT_DIVIDER;

                    affiliatesRewards[upline][i] += rewards;

                    unclaimedAffRewards[upline] += rewards;

                    emit AffRewardsAccrued(upline, rewards, block.timestamp);
                }

                upline = Vault.getAffiliate(upline);
            } else break;
        }
    }

    function init(
        ICyrusPositionManager _CyrusPositionManager,
        ICyrusVault _Vault
    ) external onlyOwner {
        require(!initialized, "Contract is already initialized");
        require(address(_CyrusPositionManager) != address(0));
        require(address(_Vault) != address(0));

        CyrusPositionManager = _CyrusPositionManager;
        Vault = _Vault;

        initialized = true;
    }

    function getUserTurnover(
        address user
    ) public view returns (uint256 turnover) {
        turnover = Vault.getAffiliateTurnover(user);
    }

    /**
     * @dev Compute user share between `from` and `to`.
     *      Note: integer division may cause a tiny loss of rewards.
     */
    function getPendingRewards(
        uint256 positionId
    ) public view returns (uint256 totalAmount, PositionInfo memory position) {
        position = CyrusPositionManager.getPosition(positionId);

        uint256 share = (position.amount * percents[position.strategyId]) /
            PERCENT_DIVIDER;
        uint256 from = position.start > position.lastClaimed
            ? position.start
            : position.lastClaimed;
        uint256 to = position.finish < block.timestamp
            ? position.finish
            : block.timestamp;

        if (from < to) {
            uint256 shareHighPrecision = share * 1e18;
            totalAmount =
                ((shareHighPrecision * (to - from)) / TIME_STEP) /
                1e18;
        }

        if (position.unclaimed > 0) {
            totalAmount += position.unclaimed;
        }

        return (totalAmount, position);
    }
}
