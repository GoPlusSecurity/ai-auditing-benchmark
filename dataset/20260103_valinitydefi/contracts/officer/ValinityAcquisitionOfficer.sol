// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { RegistrarClientInitializable } from "../RegistrarClient.sol";
import { ValinityCapOfficer } from "./ValinityCapOfficer.sol";
import { ValinityLoanOfficer } from "./ValinityLoanOfficer.sol";
import { ValinityAcquisitionTreasury } from "../treasury/ValinityAcquisitionTreasury.sol";
import { ValinityAssetRegistry } from "../ValinityAssetRegistry.sol";
import { ValinityToken } from "../token/ValinityToken.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ReentrancyGuardTransient } from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import { IUniswapV2Router02 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract ValinityAcquisitionOfficer is UUPSUpgradeable, AccessControl, ReentrancyGuardTransient, RegistrarClientInitializable {
    using SafeERC20 for IERC20;

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

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint16 public constant BPS_MULTIPLIER = 10_000;
    uint24 public constant DEFAULT_FEE_TIER = 3000;
    uint8 internal constant DEFAULT_DECIMALS = 18;

    address public feeRecipient;
    address public usdcAddress;

    uint16 public priceDisparityFeeBps;
    uint256 public lastPriceDisparityTrigger;
    uint32 public ltvDisparityFeeBps;
    uint32 public ltvDisparityCooldown;
    uint256 public lastLTVDisparityTrigger;
    uint256 public mtpMultiplier;
    uint256 public lowestLTVTriggerMultiplier;

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
        PriceDisparity, // 0
        LTVDisparity // 1
    }

    event Acquired(
        address indexed asset,
        TriggerReason triggerReason,
        uint256 vyMinted,
        uint256 vyNet,
        uint256 vyFee,
        uint256 assetAmount,
        uint256 triggerVYPriceUSD,
        uint256 triggerAssetPriceUSD,
        uint256 triggerLTV,
        uint256 executionVYPriceUSD,
        uint256 executionAssetPriceUSD,
        uint256 executionLTV
    );

    event AssetPoolFeeTierUpdated(address indexed asset, uint24 feeTier);
    event LowestLTVTriggerMultiplierUpdated(uint256 value);
    event LTVDisparityCooldownUpdated(uint32 value);
    event LTVDisparityFeeUpdated(uint32 value);
    event MTPMultiplierUpdated(uint256 value);
    event TokenRescued(address token, address to, uint256 amount);
    event FeeRecipientUpdated(address recipient);
    event PriceDisparityFeeUpdated(uint256 newBps);

    // Errors
    error FeeTooHigh();
    error InsufficientEnabledAssets();
    error InsufficientLTVDisparity();
    error InvalidAddress();
    error InvalidAsset();
    error InvalidDexParams();
    error InvalidFeeTier();
    error InvalidMultiplier();
    error InvalidTargetToken();
    error NoAcquisitionNeeded();
    error NoValidAsset();
    error PoolDoesNotExist();
    error SwapFailed();
    error TriggerCooldownActive();
    error VYPriceBelowTrigger();

    struct AcquireEconomics {
        address asset;
        uint256 vyNet;
        uint256 vyFee;
        uint256 totalVY;
        uint256 vyMinted;
        uint256 assetReceived;
        uint256 usdcAmount;
    }

    struct PriceDisparityTrigger {
        address weakestAsset;
        uint256 lowestLTVF;
        uint256 triggerLTV;
        uint256 triggerAssetPriceUSD;
        uint256 mtp;
        uint256 triggerVYPriceUSD;
    }

    struct LTVDisparityTrigger {
        address lowestAsset;
        address highestAsset;
        uint256 lowestLTV;
        uint256 highestLTV;
        uint256 triggerAssetPriceUSDLow;
        uint256 triggerAssetPriceUSDHigh;
    }

    struct ExecutionMetrics {
        uint256 executionVYPriceUSD;
        uint256 executionAssetPriceUSD;
        uint256 executionLTV;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address registrarAddress,
        address adminAddress,
        address uniswapV2RouterAddress,
        address uniswapV3RouterAddress,
        address uniswapV3FactoryAddress,
        address usdcAddr
    ) public initializer {
        __RegistrarClient_init(registrarAddress);

        if (
            adminAddress == address(0) || uniswapV2RouterAddress == address(0) || uniswapV3RouterAddress == address(0) || uniswapV3FactoryAddress == address(0)
        ) {
            revert InvalidAddress();
        }

        usdcAddress = usdcAddr;
        uniswapV2Router = IUniswapV2Router02(uniswapV2RouterAddress);
        uniswapV3Router = ISwapRouter(uniswapV3RouterAddress);
        uniswapV3Factory = IUniswapV3Factory(uniswapV3FactoryAddress);

        priceDisparityFeeBps = 200; // 2%
        ltvDisparityFeeBps = 100; // 1%
        ltvDisparityCooldown = 12 * 3600; // 12 hours
        mtpMultiplier = 20_000; // 2.0x
        lowestLTVTriggerMultiplier = 10_500; // 1.05x

        _grantRole(DEFAULT_ADMIN_ROLE, adminAddress);
        _grantRole(ADMIN_ROLE, adminAddress);
    }

    // ─────────────────────────────────────────────
    // Trigger A — Price Disparity Rebalancing
    // ─────────────────────────────────────────────

    function acquireByPriceDisparity() external nonReentrant returns (bool success) {
        address[] memory assets = _getEnabledAssets();
        if (assets.length == 0) {
            revert InsufficientEnabledAssets();
        }

        PriceDisparityTrigger memory trigger = _findWeakestAssetAndMTP(assets);
        uint256 deltaX = _calculateVYToSell(trigger.mtp);

        if (deltaX == 0) {
            revert NoAcquisitionNeeded();
        }

        _executeAndEmitPriceAcquisition(trigger, deltaX);
        lastPriceDisparityTrigger = block.timestamp;

        return true;
    }

    // ─────────────────────────────────────────────
    // Trigger B — LTV Disparity Rebalancing
    // ─────────────────────────────────────────────

    function acquireByLTVDisparity() external nonReentrant returns (bool success) {
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

        uint256 totalVY = Math.mulDiv(delta, BPS_MULTIPLIER, BPS_MULTIPLIER - ltvDisparityFeeBps);
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
    // Core Acquisition Logic
    // ─────────────────────────────────────────────

    function _getEnabledAssets() internal view returns (address[] memory) {
        ValinityAssetRegistry registry = ValinityAssetRegistry(_registrar.getContract(VAR));
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

    function _acquire(address asset, uint256 netVY) internal returns (AcquireEconomics memory econ) {
        uint256 fee = (netVY * priceDisparityFeeBps) / BPS_MULTIPLIER;
        uint256 totalVY = netVY + fee;

        uint256 vyMinted = _mintDeficitVYToVAT(totalVY);

        (uint256 usdcAmount, uint256 assetReceived) = _executeSwaps(netVY, fee, totalVY, asset);

        // For price disparity: increase cap
        ValinityCapOfficer(_registrar.getContract(VCO)).increaseAssetCap(asset, totalVY);

        econ = AcquireEconomics({
            asset: asset,
            vyNet: netVY,
            vyFee: fee,
            totalVY: totalVY,
            vyMinted: vyMinted,
            assetReceived: assetReceived,
            usdcAmount: usdcAmount
        });
    }

    function _executeSwaps(uint256 netVY, uint256 fee, uint256 totalVY, address targetAsset) internal returns (uint256 usdcAmount, uint256 assetReceived) {
        // Transfer VY from VAT to this contract
        ValinityAcquisitionTreasury(_registrar.getContract(VAT)).transferToken(address(this), totalVY);

        if (feeRecipient != address(0) && fee > 0) {
            ValinityToken(_registrar.getContract(VY)).transfer(feeRecipient, fee);
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
        ValinityToken vyToken = ValinityToken(_registrar.getContract(VY));

        uint256 currentBalance = vyToken.balanceOf(vatAddress);

        if (currentBalance < requiredAmount) {
            amountMinted = requiredAmount - currentBalance;
            vyToken.mintTo(vatAddress, amountMinted);
        } else {
            amountMinted = 0;
        }
    }

    // ─────────────────────────────────────────────
    // Price Disparity Rebalancing Logic
    // ─────────────────────────────────────────────

    function _findWeakestAssetAndMTP(address[] memory assets) internal view returns (PriceDisparityTrigger memory trigger) {
        ValinityLoanOfficer vlo = ValinityLoanOfficer(payable(_registrar.getContract(VLO)));

        trigger.lowestLTVF = type(uint256).max;

        for (uint256 i = 0; i < assets.length; i++) {
            uint256 ltv = vlo.getLTV(assets[i]);
            uint256 assetPriceUSD = getSpotPriceUSD(assets[i]);
            uint256 ltvf = (assetPriceUSD * ltv) / 1e18; // USD per VY

            if (ltvf < trigger.lowestLTVF) {
                trigger.lowestLTVF = ltvf;
                trigger.weakestAsset = assets[i];
                trigger.triggerLTV = ltv;
                trigger.triggerAssetPriceUSD = assetPriceUSD;
            }
        }

        if (trigger.weakestAsset == address(0)) {
            revert NoValidAsset();
        }

        trigger.mtp = (trigger.lowestLTVF * mtpMultiplier) / BPS_MULTIPLIER;
        trigger.triggerVYPriceUSD = getSpotPriceUSD(_registrar.getContract(VY));

        if (trigger.triggerVYPriceUSD <= trigger.mtp) {
            revert VYPriceBelowTrigger();
        }
    }

    function _calculateVYToSell(uint256 mtp) internal view returns (uint256 deltaX) {
        (uint256 xWei, uint256 yWei) = getUniswapVYUSDCReserves();

        // Normalize both to 18 decimals for calculation
        uint256 x = xWei; // Already 18 decimals
        uint256 y = yWei * 1e12; // Convert USDC from 6 to 18 decimals

        // pTarget in 18 decimals (e.g., 0.79e18 = $0.79/VY)
        uint256 pTarget = (mtp * 99) / 100;

        if (pTarget == 0 || x == 0 || y == 0) {
            return 0;
        }

        // sqrtInput = (x * y * 1e18) / pTarget to preserve 18 decimal scale after sqrt
        uint256 sqrtInput = Math.mulDiv(Math.mulDiv(x, y, 1), 1e18, pTarget);
        uint256 sqrtResult = sqrt(sqrtInput);

        if (sqrtResult <= x) {
            return 0;
        }

        // Result in 18 decimals (wei)
        uint256 numerator = sqrtResult - x;
        deltaX = (numerator * 1000) / 997; // Account for 0.3% fee
    }

    function _executeAndEmitPriceAcquisition(PriceDisparityTrigger memory trigger, uint256 deltaX) internal {
        AcquireEconomics memory econ = _acquire(trigger.weakestAsset, deltaX);
        ExecutionMetrics memory metrics = _calculateExecutionMetrics(econ, trigger.weakestAsset);

        emit Acquired(
            econ.asset,
            TriggerReason.PriceDisparity,
            econ.vyMinted,
            econ.vyNet,
            econ.vyFee,
            econ.assetReceived,
            trigger.triggerVYPriceUSD,
            trigger.triggerAssetPriceUSD,
            trigger.triggerLTV,
            metrics.executionVYPriceUSD,
            metrics.executionAssetPriceUSD,
            metrics.executionLTV
        );
    }

    // ─────────────────────────────────────────────
    // LTV Disparity Rebalancing Logic
    // ─────────────────────────────────────────────

    function _findLTVDisparity(address[] memory assets) internal view returns (LTVDisparityTrigger memory trigger) {
        ValinityLoanOfficer vlo = ValinityLoanOfficer(payable(_registrar.getContract(VLO)));

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

        ValinityCapOfficer vco = ValinityCapOfficer(_registrar.getContract(VCO));
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
            uint256 term1 = Math.mulDiv(reserveLowest, capHighest, 1e18);
            uint256 term2 = Math.mulDiv(reserveLowest, vyLiquidity, 1e18);
            uint256 term3 = Math.mulDiv(usdcLiquidity, capHighest, 1e18);
            uint256 term4 = Math.mulDiv(reserveHighest, capLowest, 1e18);

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
            uint256 innerTerm1 = Math.mulDiv(reserveLowest, capHighest, 1e18);
            uint256 innerTerm2 = Math.mulDiv(reserveHighest, capLowest, 1e18);

            if (innerTerm1 >= innerTerm2) {
                c = int256(Math.mulDiv(vyLiquidity, innerTerm1 - innerTerm2, 1e18));
            } else {
                c = -int256(Math.mulDiv(vyLiquidity, innerTerm2 - innerTerm1, 1e18));
            }
        }

        // discriminant = b^2 - 4ac
        // b and c are at 1e18 scale, a is at 1e18 scale
        // b^2 is at 1e36 scale, 4ac is at 1e36 scale
        int256 discriminant;
        {
            uint256 bSquared = Math.mulDiv(uint256(b > 0 ? b : -b), uint256(b > 0 ? b : -b), 1);
            uint256 fourAC = Math.mulDiv(4 * a, uint256(c > 0 ? c : -c), 1);

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
        return Math.mulDiv(uint256(numerator), 1e18, 2 * a);
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
        ValinityCapOfficer(_registrar.getContract(VCO)).increaseAssetCap(highestAsset, totalVY);

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
        uint256 triggerVYPriceUSD = getSpotPriceUSD(_registrar.getContract(VY));
        uint256 executionVYPriceUSD = (params.usdcAmount * 1e18) / params.netVY;
        uint256 executionAssetPriceUSD = (params.usdcAmount * 1e18) / params.assetReceived;
        uint256 executionLTV = ValinityLoanOfficer(payable(_registrar.getContract(VLO))).getLTV(params.lowestAsset);

        emit Acquired(
            params.lowestAsset,
            TriggerReason.LTVDisparity,
            params.vyMinted,
            params.netVY,
            params.fee,
            params.assetReceived,
            triggerVYPriceUSD,
            params.triggerAssetPriceUSDLow,
            params.triggerLowestLTV,
            executionVYPriceUSD,
            executionAssetPriceUSD,
            executionLTV
        );
    }

    function _calculateExecutionMetrics(AcquireEconomics memory econ, address asset) internal view returns (ExecutionMetrics memory metrics) {
        metrics.executionVYPriceUSD = (econ.usdcAmount * 1e18) / econ.vyNet;
        metrics.executionAssetPriceUSD = _calculateAssetPrice(econ.asset, econ.usdcAmount, econ.assetReceived);
        metrics.executionLTV = ValinityLoanOfficer(payable(_registrar.getContract(VLO))).getLTV(asset);
    }

    // ─────────────────────────────────────────────
    // Price & View Functions
    // ─────────────────────────────────────────────

    function getSpotPriceUSD(address asset) public view returns (uint256) {
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

    function getMTP() external view returns (uint256 mtp) {
        address[] memory assets = _getEnabledAssets();
        if (assets.length == 0) {
            return 0;
        }

        ValinityLoanOfficer vlo = ValinityLoanOfficer(payable(_registrar.getContract(VLO)));

        uint256 lowestLTVF = type(uint256).max;
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 ltv = vlo.getLTV(assets[i]);
            uint256 assetPriceUSD = getSpotPriceUSD(assets[i]);
            uint256 ltvf = (assetPriceUSD * ltv) / 1e18;
            if (ltvf < lowestLTVF) {
                lowestLTVF = ltvf;
            }
        }

        if (lowestLTVF == type(uint256).max) {
            return 0;
        }

        return (lowestLTVF * mtpMultiplier) / BPS_MULTIPLIER;
    }

    function getLTVF(address asset) external view returns (uint256 ltvf) {
        uint256 ltv = ValinityLoanOfficer(payable(_registrar.getContract(VLO))).getLTV(asset);
        uint256 assetPriceUSD = getSpotPriceUSD(asset);
        return (assetPriceUSD * ltv) / 1e18;
    }

    function getAssetFeeTier(address asset) external view returns (uint24) {
        ValinityAssetRegistry registry = ValinityAssetRegistry(_registrar.getContract(VAR));
        if (!registry.isSupported(asset)) {
            revert InvalidAsset();
        }

        uint24 feeTier = assetPoolFeeTiers[asset];
        if (feeTier == 0) {
            return DEFAULT_FEE_TIER;
        }
        return feeTier;
    }

    function getUniswapVYUSDCReserves() public view returns (uint256 x, uint256 y) {
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

    // ─────────────────────────────────────────────
    // Admin Functions
    // ─────────────────────────────────────────────

    function setAssetPoolFeeTier(address asset, uint24 feeTier) external onlyRole(ADMIN_ROLE) {
        if (feeTier == assetPoolFeeTiers[asset]) return;
        if (asset == address(0)) {
            revert InvalidAddress();
        }
        if (feeTier != 100 && feeTier != 500 && feeTier != 3000 && feeTier != 10000) {
            revert InvalidFeeTier();
        }
        assetPoolFeeTiers[asset] = feeTier;
        emit AssetPoolFeeTierUpdated(asset, feeTier);
    }

    function setFeeRecipient(address recipient) external onlyRole(ADMIN_ROLE) {
        if (recipient == feeRecipient) return;
        feeRecipient = recipient;
        emit FeeRecipientUpdated(recipient);
    }

    function setPriceDisparityFeeBps(uint16 newBps) external onlyRole(ADMIN_ROLE) {
        if (newBps == priceDisparityFeeBps) return;
        if (newBps > BPS_MULTIPLIER) {
            // Max 100% fee
            revert FeeTooHigh();
        }
        priceDisparityFeeBps = newBps;
        emit PriceDisparityFeeUpdated(newBps);
    }

    function setLTVDisparityFeeBps(uint16 newBps) external onlyRole(ADMIN_ROLE) {
        if (newBps == ltvDisparityFeeBps) return;
        if (newBps > BPS_MULTIPLIER) {
            // Max 100% fee
            revert FeeTooHigh();
        }
        ltvDisparityFeeBps = newBps;
        emit LTVDisparityFeeUpdated(newBps);
    }

    function setLTVDisparityCooldown(uint32 newCooldown) external onlyRole(ADMIN_ROLE) {
        ltvDisparityCooldown = newCooldown;
        emit LTVDisparityCooldownUpdated(newCooldown);
    }

    function setMTPMultiplier(uint256 newMultiplier) external onlyRole(ADMIN_ROLE) {
        if (newMultiplier == mtpMultiplier) return;
        if (newMultiplier == 0 || newMultiplier > 100_000) {
            revert InvalidMultiplier();
        }
        mtpMultiplier = newMultiplier;
        emit MTPMultiplierUpdated(newMultiplier);
    }

    function setLowestLTVTriggerMultiplier(uint256 newMultiplier) external onlyRole(ADMIN_ROLE) {
        if (newMultiplier == lowestLTVTriggerMultiplier) return;
        if (newMultiplier == 0 || newMultiplier > 100_000) {
            revert InvalidMultiplier();
        }
        lowestLTVTriggerMultiplier = newMultiplier;
        emit LowestLTVTriggerMultiplierUpdated(newMultiplier);
    }

    function rescueToken(address token, address to, uint256 amount) external onlyRole(ADMIN_ROLE) {
        IERC20(token).safeTransfer(to, amount);
        emit TokenRescued(token, to, amount);
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

        uint256 priceX96 = Math.mulDiv(uint256(sqrtPriceX96), uint256(sqrtPriceX96), 2 ** 96);

        uint8 token0Decimals = IERC20Metadata(token0).decimals();
        uint8 token1Decimals = IERC20Metadata(token1).decimals();

        if (targetToken == token0) {
            // Price of token0 in terms of token1
            int256 decimalDiff = int256(uint256(token0Decimals)) - int256(uint256(token1Decimals));
            if (decimalDiff >= 0) {
                price = Math.mulDiv(priceX96, 10 ** (18 + uint256(decimalDiff)), 2 ** 96);
            } else {
                price = Math.mulDiv(priceX96, 10 ** 18, 2 ** 96 * 10 ** uint256(-decimalDiff));
            }
        } else {
            // Price of token1 in terms of token0 (inverse)
            int256 decimalDiff = int256(uint256(token1Decimals)) - int256(uint256(token0Decimals));
            if (decimalDiff >= 0) {
                price = Math.mulDiv(2 ** 96, 10 ** (18 + uint256(decimalDiff)), priceX96);
            } else {
                price = Math.mulDiv(2 ** 96, 10 ** 18, priceX96 * 10 ** uint256(-decimalDiff));
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

    function _calculateAssetPrice(address asset, uint256 usdcAmount, uint256 assetReceived) internal view returns (uint256) {
        if (assetReceived == 0) {
            return 0;
        }

        uint8 assetDecimals = _getAssetDecimals(asset);
        uint8 usdcDecimals = IERC20Metadata(usdcAddress).decimals();

        uint256 scaledUSDC = _scaleDecimals(usdcAmount, usdcDecimals, 18);
        uint256 scaledAsset = _scaleDecimals(assetReceived, assetDecimals, 18);

        return (scaledUSDC * 1e18) / scaledAsset;
    }

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

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(ADMIN_ROLE) {}
}
