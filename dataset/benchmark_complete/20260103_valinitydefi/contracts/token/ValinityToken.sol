// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract ValinityToken is ERC20, AccessControl {
    // EIP712 Precomputed hashes:
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
    bytes32 private constant EIP712DOMAINTYPE_HASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    // keccak256("ValinityToken")
    bytes32 private constant NAME_HASH = 0x57baa3182211fc13f780c2c3f3afbe6e6f926eb3b16ce6b934be325d1727b10b;

    // keccak256("1")
    bytes32 private constant VERSION_HASH = 0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6;

    // keccak256("VYPermit(address owner,address spender,uint256 amount,uint256 nonce)");
    bytes32 private constant TXTYPE_HASH = 0x085abc97e2d328b3816b8248b9e8aa0e35bb8f414343c830d2d375b0d9b3c98f;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 public DOMAIN_SEPARATOR;
    mapping(address => uint256) public nonces;

    uint256 public constant MAX_SUPPLY = 7_000_000_000 * 10 ** 18; // 7 billion hard cap

    uint16 public transferFeeBps;
    address public transferFeeRecipient;

    mapping(address => bool) public whitelistedAddresses;

    error MaxSupplyExceeded();
    error FeeTooHigh();
    error CallerNotPrevContract();
    error InvalidAddress();
    error InvalidNewContractAddress();
    error InvalidSignature();

    event TransferFeeUpdated(uint16 newBps);
    event TransferFeeRecipientUpdated(address recipient);
    event WhitelistUpdated(address indexed who, bool whitelisted);
    event TransferFee(address indexed from, address indexed to, uint256 grossAmount, uint256 netAmount, uint256 feeAmount, uint256 feeBps);

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /**
     * @dev Constructor that setup all the admin governance agent.
     * Initializes transfer fee to 1% and no minter or fee recipient.
     */
    constructor(string memory name, string memory symbol, address adminAddress) ERC20(name, symbol) {
        if (adminAddress == address(0)) {
            revert InvalidAddress();
        }

        // Setup EIP712
        DOMAIN_SEPARATOR = keccak256(abi.encode(EIP712DOMAINTYPE_HASH, NAME_HASH, VERSION_HASH, block.chainid, address(this)));

        // Default transfer fee to 1% (100 basis points)
        transferFeeBps = 100; // 1%

        // Give adminAddress the admin role that can grant/revoke ADMIN_ROLE and MINTER_ROLE
        _grantRole(DEFAULT_ADMIN_ROLE, adminAddress);
        _grantRole(ADMIN_ROLE, adminAddress);
        _setRoleAdmin(MINTER_ROLE, ADMIN_ROLE);
    }

    function mintTo(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        if (totalSupply() + amount > MAX_SUPPLY) {
            revert MaxSupplyExceeded();
        }
        super._mint(to, amount);
    }

    function setTransferFeeBps(uint16 newBps) external onlyRole(ADMIN_ROLE) {
        if (newBps == transferFeeBps) return;
        if (newBps > 10000) {
            // Max 100% fee
            revert FeeTooHigh();
        }
        transferFeeBps = newBps;
        emit TransferFeeUpdated(newBps);
    }

    function setTransferFeeRecipient(address recipient) external onlyRole(ADMIN_ROLE) {
        if (recipient == transferFeeRecipient) return;
        transferFeeRecipient = recipient;
        emit TransferFeeRecipientUpdated(recipient);
    }

    function setWhitelisted(address who, bool exempt) external onlyRole(ADMIN_ROLE) {
        if (who == address(0)) revert InvalidAddress();
        if (whitelistedAddresses[who] == exempt) return;
        whitelistedAddresses[who] = exempt;
        emit WhitelistUpdated(who, exempt);
    }

    function isWhitelisted(address who) public view returns (bool) {
        return whitelistedAddresses[who];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        uint256 fee = _calculateTransferFee(_msgSender(), recipient, amount);
        uint256 netAmount = amount - fee;

        if (fee > 0) {
            if (fee >= amount) {
                revert FeeTooHigh();
            }
            _transfer(_msgSender(), recipient, netAmount);
            _collectFee(_msgSender(), fee);
            emit TransferFee(_msgSender(), transferFeeRecipient, amount, netAmount, fee, transferFeeBps);
        } else {
            _transfer(_msgSender(), recipient, amount);
        }

        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        uint256 fee = _calculateTransferFee(sender, recipient, amount);
        uint256 netAmount = amount - fee;

        _spendAllowance(sender, _msgSender(), amount);

        if (fee > 0) {
            if (fee >= amount) {
                revert FeeTooHigh();
            }
            _transfer(sender, recipient, netAmount);
            _collectFee(sender, fee);
            emit TransferFee(sender, transferFeeRecipient, amount, netAmount, fee, transferFeeBps);
        } else {
            _transfer(sender, recipient, amount);
        }

        return true;
    }

    function permit(address owner, address spender, uint256 amount, uint8 v, bytes32 r, bytes32 s) external {
        // EIP712 scheme: https://github.com/ethereum/EIPs/blob/master/EIPS/eip-712.md
        bytes32 txInputHash = keccak256(abi.encode(TXTYPE_HASH, owner, spender, amount, nonces[owner]));
        bytes32 totalHash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, txInputHash));

        address recoveredAddress = ecrecover(totalHash, v, r, s);
        if (recoveredAddress == address(0) || recoveredAddress != owner) {
            revert InvalidSignature();
        }

        nonces[owner] = nonces[owner] + 1;
        _approve(owner, spender, amount);
    }

    function _calculateTransferFee(address from, address to, uint256 amount) private view returns (uint256) {
        // if either the sender or the receiver is whitelisted, no fee is charged
        if (isWhitelisted(from) || isWhitelisted(to)) {
            return 0;
        }

        return (amount * transferFeeBps) / 10000; // 10000 basis points = 100%
    }

    function _collectFee(address sender, uint256 fee) private {
        if (fee > 0 && transferFeeRecipient != address(0)) {
            _transfer(sender, transferFeeRecipient, fee);
        }
    }
}
