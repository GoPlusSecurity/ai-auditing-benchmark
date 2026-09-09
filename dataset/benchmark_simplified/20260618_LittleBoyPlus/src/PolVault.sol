// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {ILBP} from "./interfaces/ILBP.sol";

import {IPancakePair} from "./interfaces/IPancakePair.sol";

interface ILBPPolCallback {
    function tradingOpened() external view returns (bool);

    function onPolStart() external;

    function onPolEnd() external;
}

contract PolVault is ReentrancyGuardTransient {
    using SafeERC20 for IERC20;

    error ZeroAddress();

    error NotOpened();

    error SwapSlippage();

    error TransferFailed();

    error OnlyController();

    error InvalidRecipient();

    event PolFlushed(
        address indexed caller,
        uint256 bufferProcessed,
        uint256 lbpSwapped,
        uint256 usdtReceived,
        uint256 lbpAddedToLp,
        uint256 usdtAddedToLp,
        uint256 liquidityAdded
    );

    uint256 public constant FLUSH_REWARD_BPS = 50;

    uint256 public constant FLUSH_REWARD_MAX = 10 * 1e18;

    ILBP public immutable token;

    IERC20 public immutable usdt;

    IPancakePair public immutable pair;

    ILBPPolCallback public immutable controller;

    constructor(address _controller, IERC20 _usdt, IPancakePair _pair) {
        if (_controller == address(0)) revert ZeroAddress();
        if (address(_usdt) == address(0)) revert ZeroAddress();
        if (address(_pair) == address(0)) revert ZeroAddress();

        token = ILBP(_controller);
        usdt = _usdt;
        pair = _pair;
        controller = ILBPPolCallback(_controller);
    }

    function flushPolForUser(address recipient) external nonReentrant returns (uint256 liquidityAdded) {
        if (msg.sender != address(controller)) revert OnlyController();
        if (recipient == address(0)) revert InvalidRecipient();
        return _doFlushPol(recipient);
    }

    function _doFlushPol(address rewardRecipient) internal returns (uint256 liquidityAdded) {
        if (!controller.tradingOpened()) revert NotOpened();

        uint256 buffer = token.rawBalanceOf(address(this));

        if (rewardRecipient != address(0)) {
            uint256 reward = buffer * FLUSH_REWARD_BPS / 10_000;
            if (reward > FLUSH_REWARD_MAX) reward = FLUSH_REWARD_MAX;
            if (reward > 0) {
                if (!token.transfer(rewardRecipient, reward)) revert TransferFailed();
                unchecked { buffer -= reward; }
            }
        }

        controller.onPolStart();

        uint256 half = buffer / 2;
        uint256 usdtReceived = _swapLbpToUsdt(half);
        uint256 lbpRemaining = buffer - half;
        (uint256 lbpAddedToLp, uint256 usdtAddedToLp, uint256 liq) =
            _addLiquidity(lbpRemaining, usdt.balanceOf(address(this)));
        liquidityAdded = liq;

        controller.onPolEnd();

        emit PolFlushed(
            rewardRecipient,
            buffer,
            half,
            usdtReceived,
            lbpAddedToLp,
            usdtAddedToLp,
            liquidityAdded
        );
    }

    function _swapLbpToUsdt(uint256 amountIn) internal returns (uint256 amountOut) {
        if (amountIn == 0) return 0;

        (uint112 r0, uint112 r1,) = pair.getReserves();
        if (r0 == 0 || r1 == 0) return 0;

        uint256 amountInWithFee = amountIn * 9_975;
        uint256 numerator = amountInWithFee * uint256(r0);
        uint256 denominator = uint256(r1) * 10_000 + amountInWithFee;
        amountOut = numerator / denominator;
        if (amountOut == 0) return 0;

        if (!token.transfer(address(pair), amountIn)) revert TransferFailed();

        uint256 usdtBefore = usdt.balanceOf(address(this));
        pair.swap(amountOut, 0, address(this), "");
        uint256 usdtReceived = usdt.balanceOf(address(this)) - usdtBefore;
        if (usdtReceived < amountOut) revert SwapSlippage();
        return usdtReceived;
    }

    function _addLiquidity(uint256 lbpAmount, uint256 usdtAmount)
        internal
        returns (uint256 useLbp, uint256 useUsdt, uint256 liquidity)
    {
        if (lbpAmount == 0 || usdtAmount == 0) return (0, 0, 0);

        (uint112 r0, uint112 r1,) = pair.getReserves();
        if (r0 == 0 || r1 == 0) return (0, 0, 0);

        uint256 optimalUsdt = lbpAmount * uint256(r0) / uint256(r1);
        if (optimalUsdt <= usdtAmount) {
            useLbp = lbpAmount;
            useUsdt = optimalUsdt;
        } else {
            useUsdt = usdtAmount;
            useLbp = usdtAmount * uint256(r1) / uint256(r0);
        }
        if (useLbp == 0 || useUsdt == 0) return (0, 0, 0);

        if (!token.transfer(address(pair), useLbp)) revert TransferFailed();
        usdt.safeTransfer(address(pair), useUsdt);
        liquidity = pair.mint(address(this));
    }
}
