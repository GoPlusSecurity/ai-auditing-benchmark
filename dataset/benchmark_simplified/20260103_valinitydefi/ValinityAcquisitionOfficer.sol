// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function decimals() external view returns (uint8);
}

library MathLib {
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            uint256 prod0;
            uint256 prod1;
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            if (prod1 == 0) {
                return prod0 / denominator;
            }

            require(denominator > prod1, "mulDiv overflow");

            uint256 remainder;
            assembly {
                remainder := mulmod(x, y, denominator)
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            uint256 twos = denominator & (~denominator + 1);
            assembly {
                denominator := div(denominator, twos)
                prod0 := div(prod0, twos)
                twos := add(div(sub(0, twos), twos), 1)
            }
            prod0 |= prod1 * twos;

            uint256 inverse = (3 * denominator) ^ 2;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;

            result = prod0 * inverse;
            return result;
        }
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

    modifier nonReentrant() {
        require(_status != _ENTERED, "reentrant");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

interface IUniswapV2Router02 {
    function factory() external view returns (address);
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        returns (uint256[] memory amounts);
}

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

interface IUniswapV3Pool {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );

    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
}

interface IUniswapV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

interface IValinityRegistrar {
    function getContract(bytes32 key) external view returns (address);
}

interface IValinityAssetRegistry {
    struct AssetConfig {
        bool acquisitionPaused;
    }

    function getAssets() external view returns (address[] memory);
    function getConfig(address asset) external view returns (AssetConfig memory);
}

interface IValinityCapOfficer {
    function increaseAssetCap(address asset, uint256 amount) external;
    function getAssetCap(address asset) external view returns (uint256);
}

interface IValinityLoanOfficer {
    function getLTV(address asset) external view returns (uint256);
}

interface IValinityAcquisitionTreasury {
    function transferToken(address to, uint256 amount) external;
}

interface IValinityToken is IERC20 {
    function mintTo(address to, uint256 amount) external;
}

contract ValinityAcquisitionOfficer is ReentrancyGuard {
    uint16 internal constant BPS_MULTIPLIER = 10_000;
    uint24 internal constant DEFAULT_FEE_TIER = 3000;
    uint8 internal constant DEFAULT_DECIMALS = 18;

    IValinityRegistrar internal immutable _registrar;

    address internal feeRecipient;
    address internal usdcAddress;

    uint32 internal ltvDisparityFeeBps;
    uint32 internal ltvDisparityCooldown;
    uint256 internal lastLTVDisparityTrigger;
    uint256 internal lowestLTVTriggerMultiplier;

    mapping(address => uint24) internal assetPoolFeeTiers;

    ISwapRouter internal uniswapV3Router;
    IUniswapV2Router02 internal uniswapV2Router;
    IUniswapV3Factory internal uniswapV3Factory;

    bytes32 internal constant VCO = keccak256("ValinityCapOfficer");
    bytes32 internal constant VLO = keccak256("ValinityLoanOfficer");
    bytes32 internal constant VRT = keccak256("ValinityReserveTreasury");
    bytes32 internal constant VAR = keccak256("ValinityAssetRegistry");
    bytes32 internal constant VAT = keccak256("ValinityAcquisitionTreasury");
    bytes32 internal constant VY = keccak256("ValinityToken");

    // Events
    enum TriggerReason {
        LTVDisparity // 0
    }

    event Acquired(
        address indexed asset,
        TriggerReason triggerReason,
        uint256 vyMinted,
        uint256 vyNet,
        uint256 vyFee,
        uint256 assetAmount,
        uint256 triggerAssetPriceUSD,
        uint256 triggerLTV,
        uint256 executionVYPriceUSD,
        uint256 executionAssetPriceUSD,
        uint256 executionLTV
    );

    // Errors
    error InsufficientEnabledAssets();
    error InsufficientLTVDisparity();
    error InvalidAddress();
    error InvalidDexParams();
    error InvalidTargetToken();
    error NoAcquisitionNeeded();
    error NoValidAsset();
    error PoolDoesNotExist();
    error SwapFailed();
    error TriggerCooldownActive();

    struct LTVDisparityTrigger {
        address lowestAsset;
        address highestAsset;
        uint256 lowestLTV;
        uint256 highestLTV;
        uint256 triggerAssetPriceUSDLow;
        uint256 triggerAssetPriceUSDHigh;
    }
    struct LTVEmitParams {
        address lowestAsset;
        uint256 triggerAssetPriceUSDLow;
        uint256 triggerLowestLTV;
        uint256 netVY;
        uint256 fee;
        uint256 vyMinted;
        uint256 assetReceived;
        uint256 usdcAmount;
    }

    constructor(
        address registrarAddress,
        address uniswapV2RouterAddress,
        address uniswapV3RouterAddress,
        address uniswapV3FactoryAddress,
        address usdcAddr,
        address feeRecipientAddress,
        uint32 ltvFeeBps,
        uint32 ltvCooldown,
        uint256 lowestTriggerMultiplier
    ) {
        if (
            registrarAddress == address(0) ||
            uniswapV2RouterAddress == address(0) ||
            uniswapV3RouterAddress == address(0) ||
            uniswapV3FactoryAddress == address(0) ||
            usdcAddr == address(0)
        ) {
            revert InvalidAddress();
        }

        _registrar = IValinityRegistrar(registrarAddress);
        usdcAddress = usdcAddr;
        feeRecipient = feeRecipientAddress;

        uniswapV2Router = IUniswapV2Router02(uniswapV2RouterAddress);
        uniswapV3Router = ISwapRouter(uniswapV3RouterAddress);
        uniswapV3Factory = IUniswapV3Factory(uniswapV3FactoryAddress);

        ltvDisparityFeeBps = ltvFeeBps;
        ltvDisparityCooldown = ltvCooldown;
        lowestLTVTriggerMultiplier = lowestTriggerMultiplier;
    }

    // ─────────────────────────────────────────────
    // Trigger — LTV Disparity Rebalancing
    // ─────────────────────────────────────────────

    /// @notice Simplified version: keep only this function and its call chain.
    /// @dev Original codebase used `acquireByLTVDisparity`; this contract keeps the same internal call chain.
    function acquireByLTanVDisparity() external nonReentrant returns (bool success) {
        if (block.timestamp < lastLTVDisparityTrigger + ltvDisparityCooldown) {
            revert TriggerCooldownActive();
        }

        address[] memory assets = _getEnabledAssets();
        if (assets.length < 2) {
            revert InsufficientEnabledAssets();
        }

        LTVDisparityTrigger memory trigger = _findLTVDisparity(assets);
        _validateLTVDisparity(trigger);

        uint256 delta = _calculateLTVDisparityDelta(trigger);

        if (delta == 0) {
            revert NoAcquisitionNeeded();
        }

        uint256 totalVY = MathLib.mulDiv(delta, BPS_MULTIPLIER, BPS_MULTIPLIER - ltvDisparityFeeBps);
        uint256 fee = totalVY - delta;

        uint256 vyMinted = _mintDeficitVYToVAT(totalVY);

        _executeAndEmitLTVAcquisition(
            trigger.lowestAsset,
            trigger.highestAsset,
            trigger.triggerAssetPriceUSDLow,
            trigger.lowestLTV,
            delta, // net VY to sell
            fee,
            totalVY,
            vyMinted
        );

        lastLTVDisparityTrigger = block.timestamp;

        return true;
    }

    // ─────────────────────────────────────────────
    // Core Logic (required by LTV disparity path)
    // ─────────────────────────────────────────────

    function _getEnabledAssets() internal view returns (address[] memory) {
        IValinityAssetRegistry registry = IValinityAssetRegistry(_registrar.getContract(VAR));
        address[] memory assets = registry.getAssets();
        address[] memory enabledAssets = new address[](assets.length);

        uint256 count;
        for (uint256 i; i < assets.length; ++i) {
            if (!registry.getConfig(assets[i]).acquisitionPaused) {
                enabledAssets[count++] = assets[i];
            }
        }

        // Truncate to actual length
        // solhint-disable-next-line no-inline-assembly
        assembly {
            mstore(enabledAssets, count)
        }
        return enabledAssets;
    }

    function _executeSwaps(uint256 netVY, uint256 fee, uint256 totalVY, address targetAsset) internal returns (uint256 usdcAmount, uint256 assetReceived) {
        // Transfer VY from VAT to this contract
        IValinityAcquisitionTreasury(_registrar.getContract(VAT)).transferToken(address(this), totalVY);

        if (feeRecipient != address(0) && fee > 0) {
            IValinityToken(_registrar.getContract(VY)).transfer(feeRecipient, fee);
        }

        // Swap VY to USDC using V2
        usdcAmount = _swapV2(_registrar.getContract(VY), usdcAddress, address(this), netVY);

        // Swap USDC to Asset using V3 (send directly to VRT)
        assetReceived = _swapV3(usdcAddress, targetAsset, _registrar.getContract(VRT), usdcAmount);
    }

    function _swapV2(address tokenIn, address tokenOut, address recipient, uint256 amountIn) internal returns (uint256 amountOut) {
        IERC20(tokenIn).approve(address(uniswapV2Router), amountIn);

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        uint256[] memory amounts = uniswapV2Router.swapExactTokensForTokens(amountIn, 0, path, recipient, block.timestamp + 300);

        amountOut = amounts[amounts.length - 1];
        if (amountOut == 0) {
            revert SwapFailed();
        }
    }

    function _swapV3(address tokenIn, address tokenOut, address recipient, uint256 amountIn) internal returns (uint256 amountOut) {
        uint24 feeTier = assetPoolFeeTiers[tokenOut];
        if (feeTier == 0) {
            feeTier = DEFAULT_FEE_TIER;
        }

        address poolAddress = uniswapV3Factory.getPool(tokenIn, tokenOut, feeTier);
        if (poolAddress == address(0)) {
            revert PoolDoesNotExist();
        }

        IERC20(tokenIn).approve(address(uniswapV3Router), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: feeTier,
            recipient: recipient,
            deadline: block.timestamp + 300,
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        amountOut = uniswapV3Router.exactInputSingle(params);
        if (amountOut == 0) {
            revert SwapFailed();
        }
    }

    function _mintDeficitVYToVAT(uint256 requiredAmount) internal returns (uint256 amountMinted) {
        address vatAddress = _registrar.getContract(VAT);
        IValinityToken vyToken = IValinityToken(_registrar.getContract(VY));

        uint256 currentBalance = vyToken.balanceOf(vatAddress);

        if (currentBalance < requiredAmount) {
            amountMinted = requiredAmount - currentBalance;
            vyToken.mintTo(vatAddress, amountMinted);
        } else {
            amountMinted = 0;
        }
    }

    // ─────────────────────────────────────────────
    // LTV Disparity Rebalancing Logic
    // ─────────────────────────────────────────────

    function _findLTVDisparity(address[] memory assets) internal view returns (LTVDisparityTrigger memory trigger) {
        IValinityLoanOfficer vlo = IValinityLoanOfficer(_registrar.getContract(VLO));

        trigger.lowestLTV = type(uint256).max;
        trigger.highestLTV = 0;

        for (uint256 i = 0; i < assets.length; i++) {
            uint256 ltv = vlo.getLTV(assets[i]);
            uint256 assetPriceUSD = getSpotPriceUSD(assets[i]);
            uint256 ltvUSD = (ltv * assetPriceUSD) / 1e18; // USD value per VY

            if (ltvUSD < trigger.lowestLTV) {
                trigger.lowestLTV = ltvUSD;
                trigger.lowestAsset = assets[i];
                trigger.triggerAssetPriceUSDLow = assetPriceUSD;
            }
            if (ltvUSD > trigger.highestLTV) {
                trigger.highestLTV = ltvUSD;
                trigger.highestAsset = assets[i];
                trigger.triggerAssetPriceUSDHigh = assetPriceUSD;
            }
        }

        if (trigger.lowestAsset == address(0) || trigger.highestAsset == address(0)) {
            revert NoValidAsset();
        }
    }

    function _validateLTVDisparity(LTVDisparityTrigger memory trigger) internal view {
        if (trigger.highestLTV < (trigger.lowestLTV * lowestLTVTriggerMultiplier) / BPS_MULTIPLIER) {
            revert InsufficientLTVDisparity();
        }
    }

    function _calculateLTVDisparityDelta(LTVDisparityTrigger memory trigger) internal view returns (uint256) {
        (uint256 vyLiquidity, uint256 usdcLiquidityRaw) = getUniswapVYUSDCReserves();
        uint256 usdcLiquidity = usdcLiquidityRaw * 1e12; // Scale to 18 decimals

        uint256 reserveLowest = _getReserveUSD(trigger.lowestAsset, trigger.triggerAssetPriceUSDLow);
        uint256 reserveHighest = _getReserveUSD(trigger.highestAsset, trigger.triggerAssetPriceUSDHigh);

        IValinityCapOfficer vco = IValinityCapOfficer(_registrar.getContract(VCO));
        uint256 capLowest = vco.getAssetCap(trigger.lowestAsset);
        uint256 capHighest = vco.getAssetCap(trigger.highestAsset);

        // a = reserveLowest + usdcLiquidity
        uint256 a = reserveLowest + usdcLiquidity;
        if (a == 0) {
            return 0;
        }

        // b = reserveLowest * capHighest + reserveLowest * vyLiquidity + usdcLiquidity * capHighest - reserveHighest * capLowest
        // Calculate in nested scope to reduce stack depth
        int256 b;
        {
            uint256 term1 = MathLib.mulDiv(reserveLowest, capHighest, 1e18);
            uint256 term2 = MathLib.mulDiv(reserveLowest, vyLiquidity, 1e18);
            uint256 term3 = MathLib.mulDiv(usdcLiquidity, capHighest, 1e18);
            uint256 term4 = MathLib.mulDiv(reserveHighest, capLowest, 1e18);

            uint256 bPositive = term1 + term2 + term3;

            if (bPositive >= term4) {
                b = int256(bPositive - term4);
            } else {
                b = -int256(term4 - bPositive);
            }
        }

        // c = vyLiquidity * (reserveLowest * capHighest - reserveHighest * capLowest)
        int256 c;
        {
            uint256 innerTerm1 = MathLib.mulDiv(reserveLowest, capHighest, 1e18);
            uint256 innerTerm2 = MathLib.mulDiv(reserveHighest, capLowest, 1e18);

            if (innerTerm1 >= innerTerm2) {
                c = int256(MathLib.mulDiv(vyLiquidity, innerTerm1 - innerTerm2, 1e18));
            } else {
                c = -int256(MathLib.mulDiv(vyLiquidity, innerTerm2 - innerTerm1, 1e18));
            }
        }

        // discriminant = b^2 - 4ac
        // b and c are at 1e18 scale, a is at 1e18 scale
        // b^2 is at 1e36 scale, 4ac is at 1e36 scale
        int256 discriminant;
        {
            uint256 bSquared = MathLib.mulDiv(uint256(b > 0 ? b : -b), uint256(b > 0 ? b : -b), 1);
            uint256 fourAC = MathLib.mulDiv(4 * a, uint256(c > 0 ? c : -c), 1);

            if (c >= 0) {
                // 4ac is positive, subtract it
                if (bSquared < fourAC) {
                    return 0;
                }
                discriminant = int256(bSquared - fourAC);
            } else {
                // 4ac is negative, add its absolute value
                discriminant = int256(bSquared + fourAC);
            }
        }

        if (discriminant < 0) {
            return 0;
        }

        // delta = [-b + sqrt(discriminant)] / (2a)
        // discriminant is at 1e36 scale, sqrt brings it to 1e18
        uint256 sqrtDiscriminant = sqrt(uint256(discriminant));
        int256 numerator = -b + int256(sqrtDiscriminant);

        if (numerator <= 0) {
            return 0;
        }

        // numerator is 1e18 scale, we want result in 1e18 scale (VY wei)
        // To preserve precision: (numerator * 1e18) / (2 * a)
        return MathLib.mulDiv(uint256(numerator), 1e18, 2 * a);
    }

    function _executeAndEmitLTVAcquisition(
        address lowestAsset,
        address highestAsset,
        uint256 triggerAssetPriceUSDLow,
        uint256 lowestLTV,
        uint256 netVY,
        uint256 fee,
        uint256 totalVY,
        uint256 vyMinted
    ) internal {
        (uint256 usdcAmount, uint256 assetReceived) = _executeSwaps(netVY, fee, totalVY, lowestAsset);

        // For LTV disparity: increase cap for highest asset
        IValinityCapOfficer(_registrar.getContract(VCO)).increaseAssetCap(highestAsset, totalVY);

        // Using LTVEmitParams struct because too many variables cause "Stack too deep" error
        _emitLTVAcquisitionEvent(
            LTVEmitParams({
                lowestAsset: lowestAsset,
                triggerAssetPriceUSDLow: triggerAssetPriceUSDLow,
                triggerLowestLTV: lowestLTV,
                netVY: netVY,
                fee: fee,
                vyMinted: vyMinted,
                assetReceived: assetReceived,
                usdcAmount: usdcAmount
            })
        );
    }

    function _emitLTVAcquisitionEvent(LTVEmitParams memory params) internal {
        uint256 executionVYPriceUSD = (params.usdcAmount * 1e18) / params.netVY;
        uint256 executionAssetPriceUSD = (params.usdcAmount * 1e18) / params.assetReceived;
        uint256 executionLTV = IValinityLoanOfficer(_registrar.getContract(VLO)).getLTV(params.lowestAsset);

        emit Acquired(
            params.lowestAsset,
            TriggerReason.LTVDisparity,
            params.vyMinted,
            params.netVY,
            params.fee,
            params.assetReceived,
            params.triggerAssetPriceUSDLow,
            params.triggerLowestLTV,
            executionVYPriceUSD,
            executionAssetPriceUSD,
            executionLTV
        );
    }

    // ─────────────────────────────────────────────
    // Price & View Functions
    // ─────────────────────────────────────────────

    function getSpotPriceUSD(address asset) internal view returns (uint256) {
        address vyAddress = _registrar.getContract(VY);
        address poolAddress;

        if (asset == vyAddress) {
            poolAddress = _getV2PairAddress(vyAddress, usdcAddress);
        } else {
            uint24 feeTier = assetPoolFeeTiers[asset];
            if (feeTier == 0) {
                feeTier = DEFAULT_FEE_TIER;
            }
            poolAddress = uniswapV3Factory.getPool(asset, usdcAddress, feeTier);
        }

        if (poolAddress == address(0)) {
            revert PoolDoesNotExist();
        }

        if (asset == vyAddress) {
            return _getSpotPriceFromV2Pair(poolAddress, asset);
        } else {
            (address token0, address token1, ) = _getPoolInfo(poolAddress);

            if (asset != token0 && asset != token1) {
                revert InvalidDexParams();
            }

            return _getSpotPriceFromPool(poolAddress, token0, token1, asset);
        }
    }

    function getUniswapVYUSDCReserves() internal view returns (uint256 x, uint256 y) {
        address pairAddress = _getV2PairAddress(_registrar.getContract(VY), usdcAddress);

        if (pairAddress == address(0)) {
            revert PoolDoesNotExist();
        }

        (uint256 reserve0, uint256 reserve1) = _getV2Reserves(pairAddress);
        address token0 = _getV2Token0(pairAddress);

        if (_registrar.getContract(VY) == token0) {
            x = reserve0; // VY reserves
            y = reserve1; // USDC reserves
        } else {
            x = reserve1; // VY reserves
            y = reserve0; // USDC reserves
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Uniswap V2 Helper Functions
    // ═══════════════════════════════════════════════════════════════════════

    function _getV2PairAddress(address tokenA, address tokenB) internal view returns (address pair) {
        // Uniswap V2 Factory interface
        address factory = uniswapV2Router.factory();

        (bool success, bytes memory data) = factory.staticcall(abi.encodeWithSignature("getPair(address,address)", tokenA, tokenB));

        if (success && data.length == 32) {
            pair = abi.decode(data, (address));
        }
    }

    function _getV2Reserves(address pair) internal view returns (uint256 reserve0, uint256 reserve1) {
        (bool success, bytes memory data) = pair.staticcall(abi.encodeWithSignature("getReserves()"));

        if (success && data.length >= 64) {
            (reserve0, reserve1) = abi.decode(data, (uint256, uint256));
        } else {
            revert InvalidDexParams();
        }
    }

    function _getV2Token0(address pair) internal view returns (address token0) {
        (bool success, bytes memory data) = pair.staticcall(abi.encodeWithSignature("token0()"));

        if (success && data.length == 32) {
            token0 = abi.decode(data, (address));
        } else {
            revert InvalidDexParams();
        }
    }

    function _getSpotPriceFromV2Pair(address pair, address targetToken) internal view returns (uint256 price) {
        (uint256 reserve0, uint256 reserve1) = _getV2Reserves(pair);
        address token0 = _getV2Token0(pair);

        address token1;
        {
            (bool success, bytes memory data) = pair.staticcall(abi.encodeWithSignature("token1()"));

            if (success && data.length == 32) {
                token1 = abi.decode(data, (address));
            } else {
                revert InvalidDexParams();
            }
        }

        if (targetToken != token0 && targetToken != token1) {
            revert InvalidTargetToken();
        }

        uint8 token0Decimals = IERC20Metadata(token0).decimals();
        uint8 token1Decimals = IERC20Metadata(token1).decimals();

        if (targetToken == token0) {
            // Price of token0 in terms of token1 (USDC)
            // price = reserve1 / reserve0, adjusted for decimals
            uint256 scaledReserve1 = _scaleDecimals(reserve1, token1Decimals, 18);
            uint256 scaledReserve0 = _scaleDecimals(reserve0, token0Decimals, 18);
            price = (scaledReserve1 * 1e18) / scaledReserve0;
        } else {
            // Price of token1 in terms of token0 (USDC)
            uint256 scaledReserve0 = _scaleDecimals(reserve0, token0Decimals, 18);
            uint256 scaledReserve1 = _scaleDecimals(reserve1, token1Decimals, 18);
            price = (scaledReserve0 * 1e18) / scaledReserve1;
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Uniswap V3 Price Functions
    // ═══════════════════════════════════════════════════════════════════════

    function _getSpotPriceFromPool(address pool, address token0, address token1, address targetToken) internal view returns (uint256 price) {
        if (targetToken != token0 && targetToken != token1) {
            revert InvalidTargetToken();
        }

        IUniswapV3Pool uniswapPool = IUniswapV3Pool(pool);
        (uint160 sqrtPriceX96, , , , , , ) = uniswapPool.slot0();

        uint256 priceX96 = MathLib.mulDiv(uint256(sqrtPriceX96), uint256(sqrtPriceX96), 2 ** 96);

        uint8 token0Decimals = IERC20Metadata(token0).decimals();
        uint8 token1Decimals = IERC20Metadata(token1).decimals();

        if (targetToken == token0) {
            // Price of token0 in terms of token1
            int256 decimalDiff = int256(uint256(token0Decimals)) - int256(uint256(token1Decimals));
            if (decimalDiff >= 0) {
                price = MathLib.mulDiv(priceX96, 10 ** (18 + uint256(decimalDiff)), 2 ** 96);
            } else {
                price = MathLib.mulDiv(priceX96, 10 ** 18, 2 ** 96 * 10 ** uint256(-decimalDiff));
            }
        } else {
            // Price of token1 in terms of token0 (inverse)
            int256 decimalDiff = int256(uint256(token1Decimals)) - int256(uint256(token0Decimals));
            if (decimalDiff >= 0) {
                price = MathLib.mulDiv(2 ** 96, 10 ** (18 + uint256(decimalDiff)), priceX96);
            } else {
                price = MathLib.mulDiv(2 ** 96, 10 ** 18, priceX96 * 10 ** uint256(-decimalDiff));
            }
        }
    }

    function _getPoolInfo(address pool) internal view returns (address token0, address token1, uint24 fee) {
        IUniswapV3Pool uniswapPool = IUniswapV3Pool(pool);
        token0 = uniswapPool.token0();
        token1 = uniswapPool.token1();
        fee = uniswapPool.fee();
    }

    // ─────────────────────────────────────────────
    // Internal Utilities
    // ─────────────────────────────────────────────

    function _getReserveUSD(address asset, uint256 priceUSD) internal view returns (uint256) {
        uint256 reserve = IERC20(asset).balanceOf(_registrar.getContract(VRT));
        uint8 assetDecimals = _getAssetDecimals(asset);
        uint256 scaledReserve = _scaleDecimals(reserve, assetDecimals, DEFAULT_DECIMALS);
        return (scaledReserve * priceUSD) / 1e18;
    }

    function _getAssetDecimals(address asset) internal view returns (uint8) {
        try IERC20Metadata(asset).decimals() returns (uint8 dec) {
            return dec;
        } catch {
            return DEFAULT_DECIMALS;
        }
    }

    function _scaleDecimals(uint256 amount, uint8 fromDecimals, uint8 toDecimals) internal pure returns (uint256) {
        if (fromDecimals > toDecimals) {
            return amount / 10 ** (fromDecimals - toDecimals);
        } else if (fromDecimals < toDecimals) {
            return amount * 10 ** (toDecimals - fromDecimals);
        }
        return amount;
    }

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    // No upgrade authorization: ABI minimized on purpose.
}
