// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @title SquidMulticall
/// @notice Multicall logic specific to Squid calls format. The contract specificity is mainly
/// to enable ERC20 and native token amounts in calldata between two calls.
/// @dev Support receiption of NFTs.
interface ISquidMulticall {
    /// @notice Call type that enables to specific behaviours of the multicall.
    enum CallType {
        // Will simply run calldata
        Default,
        // Will update amount field in calldata with ERC20 token balance of the multicall contract.
        FullTokenBalance,
        // Will update amount field in calldata with native token balance of the multicall contract.
        FullNativeBalance,
        // Will run a safeTransferFrom to get full ERC20 token balance of the caller.
        CollectTokenBalance
    }

    /// @notice Calldata format expected by multicall.
    struct Call {
        // Call type, see CallType struct description.
        CallType callType;
        // Address that will be called.
        address target;
        // Native token amount that will be sent in call.
        uint256 value;
        // Calldata that will be send in call.
        bytes callData;
        // Extra data used by multicall depending on call type.
        // Default: unused (provide 0x)
        // FullTokenBalance: address of the ERC20 token to get balance of and zero indexed position
        // of the amount parameter to update in function call contained by calldata.
        // Expect format is: abi.encode(address token, uint256 amountParameterPosition)
        // Eg: for function swap(address tokenIn, uint amountIn, address tokenOut, uint amountOutMin,)
        // amountParameterPosition would be 1.
        // FullNativeBalance: unused (provide 0x)
        // CollectTokenBalance: address of the ERC20 token to collect.
        // Expect format is: abi.encode(address token)
        bytes payload;
    }

    /// Thrown when one of the calls fails.
    /// @param callPosition Zero indexed position of the call in the call set provided to the
    /// multicall.
    /// @param reason Revert data returned by contract called in failing call.
    error CallFailed(uint256 callPosition, bytes reason);

    /// @notice Main function of the multicall that runs the call set.
    /// @param calls Call set to be ran by multicall.
    function run(Call[] calldata calls) external payable;
}

/// @dev Minimal ERC20 interface required by this contract.
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

/// @dev Minimal SafeERC20 subset required by this contract.
library SafeERC20 {
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory returndata) = address(token).call(
            abi.encodeCall(IERC20.transferFrom, (from, to, value))
        );
        require(success, "SafeERC20: transferFrom failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: transferFrom returned false");
        }
    }
}

/// @dev Minimal ERC721Receiver interface.
interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

/// @dev Minimal ERC1155Receiver interface.
interface IERC1155Receiver {
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}

contract SquidMulticall is ISquidMulticall, IERC721Receiver, IERC1155Receiver {
    using SafeERC20 for IERC20;

    bytes4 private constant ERC165_INTERFACE_ID = 0x01ffc9a7;
    bytes4 private constant ERC721_TOKENRECEIVER_INTERFACE_ID = 0x150b7a02;
    bytes4 private constant ERC1155_TOKENRECEIVER_INTERFACE_ID = 0x4e2312e0;

    /// @inheritdoc ISquidMulticall
    function run(Call[] calldata calls) external payable {
        for (uint256 i = 0; i < calls.length; i++) {
            Call memory call = calls[i];

            if (call.callType == CallType.FullTokenBalance) {
                (address token, uint256 amountParameterPosition) = abi.decode(
                    call.payload,
                    (address, uint256)
                );
                uint256 amount = IERC20(token).balanceOf(address(this));
                // Deduct 1 from amount to keep hot balances and reduce gas cost
                if (amount > 0) {
                    // Cannot underflow because amount > 0
                    unchecked {
                        amount -= 1;
                    }
                }
                _setCallDataParameter(call.callData, amountParameterPosition, amount);
            } else if (call.callType == CallType.FullNativeBalance) {
                call.value = address(this).balance;
            } else if (call.callType == CallType.CollectTokenBalance) {
                address token = abi.decode(call.payload, (address));
                uint256 senderBalance = IERC20(token).balanceOf(msg.sender);
                IERC20(token).safeTransferFrom(msg.sender, address(this), senderBalance);
                continue;
            }

            (bool success, bytes memory data) = call.target.call{value: call.value}(call.callData);
            if (!success) revert CallFailed(i, data);
        }
    }

    function _setCallDataParameter(
        bytes memory callData,
        uint256 parameterPosition,
        uint256 value
    ) private pure {
        assembly {
            // 36 bytes shift because 32 for prefix + 4 for selector
            mstore(add(callData, add(36, mul(parameterPosition, 32))), value)
        }
    }

    /// @notice Implementation required by ERC165 for NFT reception.
    /// See https://eips.ethereum.org/EIPS/eip-165.
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return
            interfaceId == ERC1155_TOKENRECEIVER_INTERFACE_ID ||
            interfaceId == ERC721_TOKENRECEIVER_INTERFACE_ID ||
            interfaceId == ERC165_INTERFACE_ID;
    }

    /// @notice Implementation required by ERC721 for NFT reception.
    /// See https://eips.ethereum.org/EIPS/eip-721.
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /// @notice Implementation required by ERC1155 for NFT reception.
    /// See https://eips.ethereum.org/EIPS/eip-1155.
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    /// @notice Implementation required by ERC1155 for NFT reception.
    /// See https://eips.ethereum.org/EIPS/eip-1155.
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    /// @dev Enable native tokens reception with .transfer or .send
    receive() external payable {}
}
