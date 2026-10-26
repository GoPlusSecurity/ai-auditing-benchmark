// SPDX-License-Identifier: MIT
//9ecc02a53f8032a599c51cbc7f7c474835c40cb0e92543f7995708cce9e06df9
pragma solidity ^0.8.20;

import '../interfaces/ICyrusPositionManager.sol';
import '../interfaces/IPancakePositionManager.sol';
import '../interfaces/ICyrusVault.sol';
import '../interfaces/IPancakeV3Factory.sol';
import '../interfaces/IPancakePool.sol';
import './libs/PancakeSwapUtil.sol';
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "hardhat/console.sol";



contract CyrusTreasury is Ownable,  ReentrancyGuard {
    using SafeERC20 for IERC20;

    event ClaimedPositionRewards(address indexed user, uint256 amount, uint256 timestamp, uint256 tokenId);
    event ClaimedAffRewards(address indexed user, uint256 amount, uint256 timestamp);
    event PositionIncreased(address indexed user, uint256 amount, uint256 timestamp,uint256 tokenId);
    event Compounded(address indexed user, uint256 amount, uint256 timestamp, uint256 tokenId);
    event Exited(address indexed user, uint256 amount, uint256 timestamp, uint256 tokenId);
    event AffRewardsAccrued(address indexed user, uint256 amount, uint256 timestamp);

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
    uint256 constant public TIME_STEP = 1 days;
    uint256 constant public PERFOMANCE_FEE = 170; //17%
    

    IPancakePositionManager constant PancakePositionManager = IPancakePositionManager(0x46A15B0b27311cedF172AB29E4f4766fbE7F4364);
    IPancakeV3Factory constant PancakeFactory = IPancakeV3Factory(0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865);

    IERC20 public constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);

    address public constant performanceFeeReceiver = address(0x6Cd7bbB8a8C0C1B24a449c3AD8F913974de7b009);

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
        require(_minAffTurnovers.length == 20, "Invalid minAffTurnovers length");

        minAffValues = _minAffValues;
        minAffTurnovers = _minAffTurnovers;
        percents = _percents; 
        affPercents = _affPercents;  

        (bool success, bytes memory data) = address(USDT).call(
            abi.encodeWithSelector(USDT.approve.selector, address(PancakePositionManager), type(uint256).max)
        );
        
        require(success && (data.length == 0 || abi.decode(data, (bool))), "USDT approve failed");
    }

    function increase(uint256 tokenId, uint256 amount) external {
        require(initialized, "Contract is not initialized");
        require(CyrusPositionManager.ownerOf(tokenId) == address(msg.sender));
        require(tokenIds.length > 0, "No tokenIds available for liquidity");

        USDT.safeTransferFrom(msg.sender, address(this), amount);

        (uint256 totalAmount, PositionInfo memory positionInfo) = getPendingRewards(tokenId);

        PositionInfo memory updatedPosition = PositionInfo({
            strategyId: positionInfo.strategyId,
            amount: positionInfo.amount + amount,
            start: positionInfo.start,
            finish: positionInfo.finish,
            totalClaimed: positionInfo.totalClaimed,
            lastClaimed: block.timestamp,
            unclaimed: totalAmount
        });

        CyrusPositionManager.updatePosition(tokenId, updatedPosition);

        uint256 share = amount / tokenIds.length;
        uint256 len = tokenIds.length;

        for(uint256 i = 0; i < len; i++) {
            increaseLiquidity(tokenIds[i], share);
        }

        emit PositionIncreased(msg.sender, amount, block.timestamp,tokenId);
    }

    function compound(uint256 tokenId) external nonReentrant {
        require(initialized, "Contract is not initialized");
        require(CyrusPositionManager.ownerOf(tokenId) == address(msg.sender));

        (uint256 totalAmount, PositionInfo memory positionInfo) = getPendingRewards(tokenId);

        require(totalAmount > 0, "No rewards to compound");

        PositionInfo memory updatedPosition = PositionInfo({
            strategyId: positionInfo.strategyId,
            amount: positionInfo.amount + totalAmount,
            start: positionInfo.start,
            finish: positionInfo.finish,
            totalClaimed: positionInfo.totalClaimed,
            lastClaimed: block.timestamp,
            unclaimed: 0
        });

        updateAffRewards(totalAmount);

        CyrusPositionManager.updatePosition(tokenId, updatedPosition);

        emit Compounded(msg.sender, totalAmount, block.timestamp, tokenId);
    }


    function claimRewards(uint256 tokenId) external nonReentrant {
        require(initialized, "Contract is not initialized");
        require(CyrusPositionManager.ownerOf(tokenId) == address(msg.sender));

        (uint256 totalAmount, PositionInfo memory positionInfo) = getPendingRewards(tokenId);

        require(totalAmount > 0, "No pending rewards");

        PositionInfo memory updatedPosition = PositionInfo({
            strategyId: positionInfo.strategyId,
            amount: positionInfo.amount,
            start: positionInfo.start,
            finish: positionInfo.finish,
            totalClaimed: positionInfo.totalClaimed + totalAmount,
            lastClaimed: block.timestamp,
            unclaimed: 0
        });

        updateAffRewards(totalAmount);

        CyrusPositionManager.updatePosition(tokenId, updatedPosition);

        uint256 perfomanceFee = totalAmount * PERFOMANCE_FEE / PERCENT_DIVIDER;
        uint256 amountWithFee = totalAmount - perfomanceFee;

        if(perfomanceFee > 0) {
            withdrawUSDTFromAny(perfomanceFee, performanceFeeReceiver);
        }

        withdrawUSDTFromAny(amountWithFee, msg.sender);

        emit ClaimedPositionRewards(msg.sender, amountWithFee, block.timestamp,tokenId);
    }

    function exit(uint256 tokenId) external nonReentrant {
        require(initialized, "Contract is not initialized");
        require(CyrusPositionManager.ownerOf(tokenId) == address(msg.sender));
        
        (uint256 totalAmount, PositionInfo memory positionInfo) = getPendingRewards(tokenId);

        require(positionInfo.finish <= block.timestamp, "Position is not finished yet");
        require(positionInfo.amount > 0, "Position is empty");

        PositionInfo memory updatedPosition = PositionInfo({
                strategyId: positionInfo.strategyId,
                amount: 0,
                start: positionInfo.start,
                finish: positionInfo.finish,
                totalClaimed: positionInfo.totalClaimed + totalAmount + positionInfo.amount,
                lastClaimed: block.timestamp,
                unclaimed: 0
        });

        if(totalAmount > 0) {
            updateAffRewards(totalAmount);
        }

        CyrusPositionManager.updatePosition(tokenId, updatedPosition);

        uint256 feeAmount = totalAmount * PERFOMANCE_FEE / PERCENT_DIVIDER;

        uint256 toWithdraw = totalAmount + positionInfo.amount - feeAmount;

        if(feeAmount > 0) {
            withdrawUSDTFromAny(feeAmount, performanceFeeReceiver);
        }

        withdrawUSDTFromAny(toWithdraw, msg.sender);

        emit Exited(msg.sender, toWithdraw, block.timestamp,tokenId);
    }

    function claimAffRewards() external {
        require(initialized, "Contract is not initialized");
        uint256 rewards = unclaimedAffRewards[msg.sender];
        require(rewards > 0, "No rewards to claim");

        unclaimedAffRewards[msg.sender] = 0;

        withdrawUSDTFromAny(rewards, msg.sender);

        emit ClaimedAffRewards(msg.sender, rewards, block.timestamp);
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

    for (uint256 i = 0; i < len && totalWithdrawn < usdtAmountWithSlippage; i++) {
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
        bool isApprovedForAll = PancakePositionManager.isApprovedForAll(owner, address(this));
        if (owner != address(this) && operator != address(this) && !isApprovedForAll) continue;

        address pool = PancakeFactory.getPool(token0, token1, fee);
        if (pool == address(0)) continue;

        (uint160 sqrtPriceX96,,,,,,) = IPancakePool(pool).slot0();
        uint160 sqrtRatioAX96 = PancakeSwapUtil.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = PancakeSwapUtil.getSqrtRatioAtTick(tickUpper);
        (uint256 amount0, uint256 amount1) = PancakeSwapUtil.getAmountsForLiquidity(
            sqrtPriceX96, sqrtRatioAX96, sqrtRatioBX96, liquidity
        );

        uint256 availableUSDT = isToken0USDT ? amount0 : amount1;
        if (availableUSDT == 0) continue;

        uint256 remaining = usdtAmountWithSlippage - totalWithdrawn;
        uint128 liquidityToUse = liquidity;
        if (availableUSDT > remaining) {
            liquidityToUse = uint128((uint256(liquidity) * remaining) / availableUSDT);
        }

        uint256 minAmount = (remaining * 995) / 1000;
        uint256 usdtReceived;

        if (isToken0USDT) {
            usdtReceived = decreaseLiquidity(tokenId, liquidityToUse, minAmount, 0, to);
        } else {
            usdtReceived = decreaseLiquidity(tokenId, liquidityToUse, 0, minAmount, to);
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
   (uint256 amount0, uint256 amount1) = PancakePositionManager.decreaseLiquidity(
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

   function increaseLiquidity(uint256 tokenId, uint256 usdtAmountWithSlippage) internal {
    (
        ,
        ,
        address token0,
        address token1,
        ,
        ,
        ,
        ,
        ,
        ,
        ,
    ) = PancakePositionManager.positions(tokenId);

    bool usdtIsToken0;
    if (token0 == address(USDT)) {
        usdtIsToken0 = true;
    } else if (token1 == address(USDT)) {
        usdtIsToken0 = false;
    } else {
        revert("USDT not in position");
    }

    // Allow 0.5% slippage: minAmount = 99.5% of requested amount
    uint128 minAmount = uint128((usdtAmountWithSlippage * 995) / 1000);

    uint128 amount0Desired = usdtIsToken0 ? uint128(usdtAmountWithSlippage) : 0;
    uint128 amount1Desired = usdtIsToken0 ? 0 : uint128(usdtAmountWithSlippage);
    uint128 amount0Min = usdtIsToken0 ? minAmount : 0;
    uint128 amount1Min = usdtIsToken0 ? 0 : minAmount;

    (
        ,
        uint256 amount0,
        uint256 amount1
    ) = PancakePositionManager.increaseLiquidity(
        IncreaseLiquidityParams({
            tokenId: tokenId,
            amount0Desired: amount0Desired,
            amount1Desired: amount1Desired,
            amount0Min: amount0Min,
            amount1Min: amount1Min,
            deadline: block.timestamp
        })
    );

    require(amount0 > 0 || amount1 > 0, "IncreaseLiquidity failed");
    
    if (usdtIsToken0) {
        require(
            amount0 >= amount0Min,
            "Slippage exceeded: amount0 below permitted tolerance"
        );
    } else {
        require(
            amount1 >= amount1Min,
            "Slippage exceeded: amount1 below permitted tolerance"
        );
    }
   }


   function updateAffRewards(uint256 amount) internal {
        address upline = Vault.getAffiliate(msg.sender);
        for(uint256 i = 0; i < 20; i++) {
            if(upline != address(0)) {
                uint256 userTurnover = getUserTurnover(upline);
                uint256 userValue = CyrusPositionManager.getPositionsValue(upline);

                if (userTurnover >= minAffTurnovers[i] && userValue >= minAffValues[i]) {
                    uint256 rewards = amount * affPercents[i] / PERCENT_DIVIDER;

                    affiliatesRewards[upline][i]+= rewards;

                    unclaimedAffRewards[upline] += rewards;

                    emit AffRewardsAccrued(upline, rewards, block.timestamp);

                }

                upline = Vault.getAffiliate(upline);

                
            } else break;
        }

        
    }

    function init(
        ICyrusPositionManager _CyrusPositionManager, 
        ICyrusVault _Vault) external onlyOwner{
        
        require(!initialized, "Contract is already initialized");
        require(address(_CyrusPositionManager) != address(0));
        require(address(_Vault) != address(0));

        CyrusPositionManager = _CyrusPositionManager;
        Vault = _Vault; 

        initialized = true;
        
    }

    function addPercent(uint256 _percent) external onlyOwner {
    require(_percent > 0, "Percent must be greater than 0");
    require(_percent <= 1000, "Percent too high");
    
    percents.push(_percent);
}

    function addTokenId(uint256 _tokenId) public onlyOwner {
        require(_tokenId > 0, "Invalid tokenId");
        require(!isTokenIdExist(_tokenId), "TokenId already exist");

        (
            ,
            ,
            address token0,
            address token1,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
        ) = PancakePositionManager.positions(_tokenId);

        bool usdtIsToken0;
        if (token0 == address(USDT)) {
            usdtIsToken0 = true;
        } else if (token1 == address(USDT)) {
            usdtIsToken0 = false;
        } else {
            revert("USDT not in position");
        }

        _usdtIsToken0[_tokenId] = usdtIsToken0;
        

        tokenIds.push(_tokenId);
    }

    function setTokenIdByIndex(uint256 index,uint256 _tokenId) public onlyOwner {
        require(index < tokenIds.length, "Index out of range");
        require(_tokenId > 0, "Invalid tokenId");
        require(!isTokenIdExist(_tokenId), "TokenId already exist");

         (
            ,
            ,
            address token0,
            address token1,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
        ) = PancakePositionManager.positions(_tokenId);

        bool usdtIsToken0;
        if (token0 == address(USDT)) {
            usdtIsToken0 = true;
        } else if (token1 == address(USDT)) {
            usdtIsToken0 = false;
        } else {
            revert("USDT not in position");
        }

        _usdtIsToken0[_tokenId] = usdtIsToken0;

        tokenIds[index] = _tokenId;
    }

    function removeTokenIdByIndex(uint256 index) public onlyOwner {
        require(index < tokenIds.length, "Index out of range");

        uint256 tokenIdToRemove = tokenIds[index];
        delete _usdtIsToken0[tokenIdToRemove];

        for (uint256 i = index; i < tokenIds.length - 1; i++) {
            tokenIds[i] = tokenIds[i + 1];
        }

        tokenIds.pop();
    }

    function isTokenIdExist(uint256 _tokenId) internal view returns (bool) {
        for(uint256 i = 0; i < tokenIds.length; i++) {
            if(tokenIds[i] == _tokenId) {
                return true;
            }
        }
        return false;
    }

    function getTokenIds() external view onlyOwner returns (uint256[] memory) {
        return tokenIds;
    }

    function getPercents() external view returns (uint256[] memory) {
        return percents;
    }

    function getAffPercents() external view returns (uint256[20] memory) {
        return affPercents;
    }

    function availableAffLevels(address user) public view returns (uint256) {
        uint256 userTurnover = getUserTurnover(user);
        uint256 userValue = CyrusPositionManager.getPositionsValue(user);

        uint256 levels = 0;
        for(uint256 i = 0; i < affPercents.length; i++) {
            if (userTurnover >= minAffTurnovers[i] && userValue >= minAffValues[i]) {
                levels++;
            }
        }
        return levels;
    }

    function getUserTurnover(address user) public view returns (uint256 turnover) {
        turnover = Vault.getAffiliateTurnover(user);
    }

    function getTotalAffRewards(address user) public view returns (uint256) {
        uint256 totalAffRewards = 0;
        for(uint256 i = 0; i < 20; i++) {
            totalAffRewards += affiliatesRewards[user][i];
        }
        return totalAffRewards;
    }

    function getUserStats(address user) external view 
    returns (
        uint256 turnover, 
        uint256 value, 
        uint256 levels, 
        uint256 totalAffRewards, 
        uint256 claimableAffRewards,
        uint256[] memory affiliatesNumber,
        uint256[] memory rewardsFromAffiliates
        ) { 
        turnover = getUserTurnover(user);
        value = CyrusPositionManager.getPositionsValue(user);
        levels = availableAffLevels(user);
        totalAffRewards = getTotalAffRewards(user);
        affiliatesNumber = Vault.getAffiliatesNumber(user);
        claimableAffRewards = unclaimedAffRewards[user];

        uint256[]  memory _rewardsFromAffiliates = new uint256[](20);
        
        for(uint256 i = 0; i < 20; i++) {
            _rewardsFromAffiliates[i] = affiliatesRewards[user][i];
        }

        rewardsFromAffiliates = _rewardsFromAffiliates;
    }

    /**
     * @dev Compute user share between `from` and `to`.
     *      Note: integer division may cause a tiny loss of rewards.
     */
    function getPendingRewards(uint256 positionId) public view returns (uint256 totalAmount, PositionInfo memory position) {
        position = CyrusPositionManager.getPosition(positionId);

        uint256 share = position.amount * percents[position.strategyId] / PERCENT_DIVIDER;
        uint256 from = position.start > position.lastClaimed ? position.start : position.lastClaimed;
        uint256 to = position.finish < block.timestamp ? position.finish : block.timestamp;

        if (from < to) {
            uint256 shareHighPrecision = share * 1e18;
            totalAmount = (shareHighPrecision * (to - from) / TIME_STEP) / 1e18;
        }

        if(position.unclaimed > 0) {
            totalAmount += position.unclaimed;
        }

        return (totalAmount, position);
    }


    function getPendingRewardsBatch(uint256[] calldata positionIds) external view returns (uint256[] memory) {
        uint256[] memory pendingRewards = new uint256[](positionIds.length);

        PositionInfo[] memory positions = CyrusPositionManager.getPositions(positionIds);

        for (uint256 i = 0; i < positionIds.length; i++) {
            PositionInfo memory position = positions[i];
            uint256 share = position.amount * percents[position.strategyId] / PERCENT_DIVIDER;
            uint256 from = position.start > position.lastClaimed ? position.start : position.lastClaimed;
            uint256 to = position.finish < block.timestamp ? position.finish : block.timestamp;

            if (from < to) {
                pendingRewards[i] = share * (to - from) / TIME_STEP;
            }

            if(position.unclaimed > 0) {
                pendingRewards[i] += position.unclaimed;
            }
        }

        return pendingRewards;
    }


}