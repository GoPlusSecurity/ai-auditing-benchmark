// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.21;

import {IUniversalRouter} from "@universal-router/interfaces/IUniversalRouter.sol";
import {Commands} from "@universal-router/libraries/Commands.sol";

library CommandInput {
    struct V3SwapExactIn {
        address recipient;
        uint256 amountIn;
        uint256 amountOutMin;
        bytes path;
        bool payerIsUser;
    }

    struct V3SwapExactOut {
        address recipient;
        uint256 amountOut;
        uint256 amountInMax;
        bytes path;
        bool payerIsUser;
    }

    struct WrapEth {
        address recipient;
        uint256 amount;
    }

    struct UnwrapWeth {
        address recipient;
        uint256 amountMinimum;
    }

    struct Permit2TransferFrom {
        address token;
        address recipient;
        uint160 amount;
    }

    struct Sweep {
        address token;
        address recipient;
        uint160 amountMinimum;
    }

    struct Transfer {
        address token;
        address recipient;
        uint256 amount;
    }

    /// @dev Simplified V4 swap input for mocking purposes
    /// @dev Real V4 uses actions/params arrays with PoolManager.unlock pattern
    struct V4Swap {
        bytes actions;
        bytes[] params;
    }
}
