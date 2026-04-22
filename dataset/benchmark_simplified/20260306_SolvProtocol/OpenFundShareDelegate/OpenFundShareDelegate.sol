// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library AddressUpgradeable {
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
}

abstract contract ContextUpgradeable {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

/// @notice Minimal transfer-only SFT/NFT-like contract:
/// - Only keeps `safeTransferFrom` public/external entrypoint.
/// - All other public/external functions from the original merged file are removed.
contract OpenFundShareDelegate is ContextUpgradeable {
    using AddressUpgradeable for address;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    // =========================
    // Minimal ownership storage
    // =========================

    mapping(uint256 => address) internal _ownerOf;
    mapping(uint256 => address) internal _tokenApprovals;
    mapping(address => mapping(address => bool)) internal _operatorApprovals;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {}

    // ============================================================
    // Kept API: safeTransferFrom (ERC-721 compatible)
    // ============================================================

    function safeTransferFrom(address from_, address to_, uint256 tokenId_) external payable {
        safeTransferFrom(from_, to_, tokenId_, "");
    }

    function safeTransferFrom(
        address from_,
        address to_,
        uint256 tokenId_,
        bytes memory data_
    ) public payable {
        require(_isApprovedOrOwner(_msgSender(), tokenId_), "transfer caller is not owner nor approved");
        _transfer(from_, to_, tokenId_);
        require(_checkOnERC721Received(from_, to_, tokenId_, data_), "transfer to non ERC721Receiver");
    }

    // =========================
    // Internal helpers
    // =========================

    function _isApprovedOrOwner(address operator_, uint256 tokenId_) internal view returns (bool) {
        address owner_ = _ownerOf[tokenId_];
        require(owner_ != address(0), "invalid tokenId");
        return operator_ == owner_ || _operatorApprovals[owner_][operator_] || _tokenApprovals[tokenId_] == operator_;
    }

    function _transfer(address from_, address to_, uint256 tokenId_) internal {
        require(to_ != address(0), "transfer to the zero address");
        require(_ownerOf[tokenId_] == from_, "transfer from invalid owner");

        delete _tokenApprovals[tokenId_];
        _ownerOf[tokenId_] = to_;
        emit Transfer(from_, to_, tokenId_);
    }

    function _checkOnERC721Received(
        address from_,
        address to_,
        uint256 tokenId_,
        bytes memory data_
    ) private returns (bool) {
        if (!to_.isContract()) {
            return true;
        }
        (bool ok, bytes memory ret) = to_.call(
            abi.encodeWithSelector(bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")), _msgSender(), from_, tokenId_, data_)
        );
        if (!ok) {
            if (ret.length == 0) revert("transfer to non ERC721Receiver implementer");
            /// @solidity memory-safe-assembly
            assembly {
                revert(add(32, ret), mload(ret))
            }
        }
        return ret.length == 32 && abi.decode(ret, (bytes4)) == bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
}