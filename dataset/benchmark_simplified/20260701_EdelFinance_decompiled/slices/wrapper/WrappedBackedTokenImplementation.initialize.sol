contract WrappedBackedTokenImplementation is OwnableUpgradeable, ERC4626Upgradeable, ERC20PermitUpgradeable {
    string constant public VERSION = "1.0.0";

    // Calculating the Delegated Transfer typehash:
    bytes32 public constant DELEGATED_TRANSFER_TYPEHASH =
        keccak256("DELEGATED_TRANSFER(address owner,address to,uint256 value,uint256 nonce,uint256 deadline)");

    // Roles:
    address public pauser;

    // EIP-712 Delegate Functionality:
    bool public delegateMode;
    mapping(address => bool) public delegateWhitelist;

    // Pause:
    bool public isPaused;

    // SanctionsList:
    SanctionsList public sanctionsList;

    // Terms:
    string public terms;

    // Events:
    event NewPauser(address indexed newPauser);
    event NewSanctionsList(address indexed newSanctionsList);
    event DelegateWhitelistChange(address indexed whitelistAddress, bool status);
    event DelegateModeChange(bool delegateMode);
    event PauseModeChange(bool pauseMode);
    event NewTerms(string newTerms);

    modifier allowedDelegate {
        require(delegateMode || delegateWhitelist[_msgSender()], "WrappedBackedToken: Unauthorized delegate");
        _;
    }


    // constructor, call initializer to lock the implementation instance.
    constructor () {
        initialize("Wrapped Backed Token Implementation", "wBTI", address(0x0000000000000000000000000000000000000000));
    }

    function initialize(string memory name_, string memory symbol_, address underlying_) public initializer {
        __ERC20_init(name_, symbol_);
        __ERC20Permit_init(name_);
        __ERC4626_init(IERC20Upgradeable(underlying_));
        __Ownable_init();
        _setTerms("https://www.backedassets.fi/legal-documentation"); // Default Terms
    }
