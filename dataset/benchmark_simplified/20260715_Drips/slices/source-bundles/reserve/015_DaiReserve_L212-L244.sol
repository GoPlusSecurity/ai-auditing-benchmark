
interface IERC20Reserve {
    function erc20() external view returns (IERC20);

    function withdraw(uint256 amt) external;

    function deposit(uint256 amt) external;
}

contract ERC20Reserve is IERC20Reserve, Ownable {
    IERC20 public immutable override erc20;
    address public user;
    uint256 public balance;

    event Withdrawn(address to, uint256 amt);
    event Deposited(address from, uint256 amt);
    event ForceWithdrawn(address to, uint256 amt);
    event UserSet(address oldUser, address newUser);

    constructor(
        IERC20 _erc20,
        address owner,
        address _user
    ) {
        erc20 = _erc20;
        setUser(_user);
        transferOwnership(owner);
    }

    modifier onlyUser() {
        require(_msgSender() == user, "Reserve: caller is not the user");
        _;
    }
