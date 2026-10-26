contract Sand is ERC20ExecuteExtension, ERC20BasicApproveExtension, ERC20BaseToken {

    constructor(address sandAdmin, address executionAdmin, address beneficiary) public {
        _admin = sandAdmin;
        _executionAdmin = executionAdmin;
        _mint(beneficiary, 3000000000000000000000000000);
    }
