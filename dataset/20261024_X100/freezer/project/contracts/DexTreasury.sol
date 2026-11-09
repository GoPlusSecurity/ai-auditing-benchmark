// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Senate} from "./Senate.sol";
import {DexBase} from "./DexBase.sol";
import {DexModule} from "./DexModule.sol";
import {IPoolManager, IUnlockCallback} from "./interfaces/dex/IPoolManager.sol";

abstract contract DexTreasury is Senate, DexBase, IERC721Receiver, IUnlockCallback {
    address private immutable _module;

    error NoModule(address module);

    constructor(address module, address base, uint256 dexSellCap_, Config memory config) {
        require(module.code.length != 0, NoModule(module));
        _module = module;

        _delegate(abi.encodeCall(DexModule.init, (base, dexSellCap_, config)));
    }

    function v3Mint(V3MintParams calldata) external onlySenate returns (uint256, uint256) {
        _forward();
    }

    function v3Increase(
        Dex,
        uint256,
        uint256,
        uint256,
        uint256,
        uint256
    ) external onlySenate returns (uint256, uint256, uint256) {
        _forward();
    }

    function v3Decrease(
        Dex,
        uint256,
        uint256,
        uint256,
        uint256
    ) external onlySenate returns (uint256, uint256, uint256, uint256) {
        _forward();
    }

    function v3Swap(
        Dex,
        address,
        address,
        uint24,
        uint256,
        uint256
    ) external onlySenate returns (uint256) {
        _forward();
    }

    function v4Increase(
        IPoolManager.PoolKey calldata,
        int24,
        int24,
        uint256,
        uint256,
        uint256
    ) external onlySenate returns (bytes32, uint256, uint256) {
        _forward();
    }

    function v4Decrease(
        bytes32,
        uint256,
        uint256,
        uint256
    ) external onlySenate returns (uint256, uint256) {
        _forward();
    }

    function v4Swap(
        IPoolManager.PoolKey calldata,
        bool,
        uint256,
        uint256
    ) external onlySenate returns (uint256) {
        _forward();
    }

    function unlockCallback(bytes calldata) external returns (bytes memory) {
        _forward();
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function dexModule() external view returns (address) {
        return _module;
    }

    function dexSellCap() external view returns (uint256) {
        return _store().dexSellCap;
    }

    function dexSold() external view returns (uint256) {
        return _store().dexSold;
    }

    function dexSellLeft() external view returns (uint256) {
        Store storage s = _store();
        return s.dexSellCap > s.dexSold ? s.dexSellCap - s.dexSold : 0;
    }

    function v4PositionOf(bytes32 positionId) external view returns (V4Position memory) {
        return _store().v4Positions[positionId];
    }

    function _isProposable(bytes4 selector) internal view virtual override returns (bool) {
        return
            selector == this.v3Mint.selector ||
            selector == this.v3Increase.selector ||
            selector == this.v3Decrease.selector ||
            selector == this.v3Swap.selector ||
            selector == this.v4Increase.selector ||
            selector == this.v4Decrease.selector ||
            selector == this.v4Swap.selector ||
            super._isProposable(selector);
    }

    function _forward() private {
        address module = _module;

        assembly {
            calldatacopy(0, 0, calldatasize())
            let ok := delegatecall(gas(), module, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch ok
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    function _delegate(bytes memory data) private {
        (bool ok, bytes memory result) = _module.delegatecall(data);
        if (!ok) {
            assembly ("memory-safe") {
                revert(add(result, 32), mload(result))
            }
        }
    }
}
