// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TokenX
 * @dev Non-transferable reserve token for the X/MOKE pair.
 *      Only the owner (for initial LP setup) and the Release contract
 *      (for burning during claims) can move tokens.
 *      All LP is permanently locked at 0xdead.
 */
contract TokenX is ERC20, Ownable {
    address public pair;
    address public releaseContract;

    event PairSet(address indexed pair);
    event ReleaseContractSet(address indexed release);
    event BurnedFromPair(uint256 amount);

    constructor(
        uint256 totalSupply,
        address _owner
    ) ERC20("X", "X") Ownable(_owner) {
        _mint(_owner, totalSupply);
    }

    function setPair(address _pair) external onlyOwner {
        require(_pair != address(0), "Invalid pair");
        pair = _pair;
        emit PairSet(_pair);
    }

    function setReleaseContract(address _release) external onlyOwner {
        releaseContract = _release;
        emit ReleaseContractSet(_release);
    }

    /**
     * @dev Restricts all transfers.
     *      Allowed origins:
     *        - address(0)       → mint
     *        - owner()          → initial LP setup (transfer to pair via Router)
     *        - releaseContract  → burnFromPair triggers _burn which calls _update(pair, 0, amount)
     */
    function _update(address from, address to, uint256 amount) internal override {
        require(
            from == address(0) ||
            from == owner() ||
            msg.sender == releaseContract,
            "X: non-transferable"
        );
        super._update(from, to, amount);
    }

    /**
     * @dev Burns X tokens directly from the pair's balance.
     *      Only callable by the Release contract during claim().
     *      After burning, caller must call pair.sync() to update reserves.
     */
    function burnFromPair(uint256 amount) external {
        require(msg.sender == releaseContract, "Only release contract");
        require(pair != address(0), "Pair not set");
        _burn(pair, amount);
        emit BurnedFromPair(amount);
    }
}
