//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

// We import this library to be able to use console.log
import "hardhat/console.sol";

import "../utils/Context.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IERC20Errors.sol";


// This is the main building block for smart contracts.
abstract contract ERC20Token is Context, IERC20, IERC20Errors {
    // Some string type variables to identify the token.
    string private _name;
    string private _symbol;

    // The fixed amount of tokens stored in an unsigned integer type variable.
    uint256 private _totalSupply ;

    // Owner have all token on initial
    address private _owner;

    // A mapping is a key/value map. Here we store each account balance.
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    /**
     * Contract initialization.
     */
    constructor(string memory __name,string memory __symbol, uint256 __totalSupply) {
        // The totalSupply is assigned to the transaction sender, which is the
        // account that is deploying the contract.
        _name = __name;
        _symbol = __symbol;
        _totalSupply = __totalSupply;
        _balances[msg.sender] = _totalSupply;
        _owner = msg.sender;
    }

    function transfer(address to, uint256 value) external returns (bool){
        address __owner = _msgSender();
        console.log(
            "Transferring from %s to %s %s tokens",
            msg.sender,
            to,
            value
        );
        _transfer(__owner,to,value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool){
        address spender = _msgSender();
        // console.log("Transfer Spender %s, From %s, To %s, Value: %s",spender,from,to,value);
        _spendAllowance(from, spender, value);
        _transfer(from, to , value);
        return true;
    }

    
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

 
    function allowance(address __owner, address spender) public view  returns (uint256) {
        return _allowances[__owner][spender];
    }

    function approve(address spender, uint256 value) external returns (bool) {
        address __owner = _msgSender();
        // console.log("Aapprovel Owner: %s, Spender %s, Value: %s",__owner,spender,value);
        _approve(__owner, spender, value);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external  returns (bool) {
        address __owner = _msgSender();
        _approve(__owner, spender, allowance(__owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 requestedDecrease) external  returns (bool) {
        address __owner = _msgSender();
        uint256 currentAllowance = allowance(__owner, spender);
        if (currentAllowance < requestedDecrease) {
            revert ERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
        }
        unchecked {
            _approve(__owner, spender, currentAllowance - requestedDecrease);
        }

        return true;
    }


    function _transfer(address from, address to, uint256 value) internal {
        if(from == address(0)){
            revert ERC20InvalidSender(address(0));
        }
        if(to == address(0)){
            revert ERC20InvalidReceiver(address(0));
        }

        _update(from, to, value);
    }

    function _approve(address __owner, address spender, uint256 value) internal  {
        _approve(__owner, spender, value, true);
    }

    function _approve(address __owner, address spender, uint256 value, bool emitEvent) internal {
        if(__owner == address(0)){
            revert ERC20InvalidApprover(address(0));
        }
        if(spender == address(0)){
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[__owner][spender] = value;
        if(emitEvent){
            emit Approval(__owner, spender, value);
        }
    }

    function _spendAllowance(address __owner, address spender, uint256 value) internal {
        uint256 currentAllowance = _allowances[__owner][spender];
        if(currentAllowance != type(uint256).max){
            if(currentAllowance < value){
                revert ERC20InsufficientAllowance(spender,currentAllowance,value);
            }
            unchecked{
                _approve(__owner,spender, currentAllowance - value,false);
            }
        }
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from` (or `to`) is
     * the zero address. All customizations to transfers, mints, and burns should be done by overriding this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(address from, address to , uint256 value) internal  {
        if(from == address(0)){
            _totalSupply += value;
            console.log("Sending to supply from {}",from);
        }else{
            uint256 fromBalance = _balances[from];
            if(fromBalance < value){
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
             unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[from] = fromBalance - value;
            }
        }
        if(to == address(0)){
            unchecked{
                _totalSupply -= value;
            }
        }else{
            unchecked{
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);

    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, by transferring it to address(0).
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not , {_update} should be overridden instead
     */
    function _burn(address account, uint256 value) internal{
        if(account == address(0)){
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    
     function totalSupply() public view  returns (uint256) {
        return _totalSupply;
    }

     function name() public view  returns (string memory) {
        return _name;
    }

    function symbol() public view  returns (string memory) {
        return _symbol;
    }

    function decimals() public pure  returns (uint8) {
        return 18;
    }
    function owner() public view returns (address){
        return _owner;
    }
}
