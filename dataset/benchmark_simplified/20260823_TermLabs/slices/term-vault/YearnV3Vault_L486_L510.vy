@internal
def _erc20_safe_approve(token: address, spender: address, amount: uint256):
    # Used only to approve tokens that are not the type managed by this Vault.
    # Used to handle non-compliant tokens like USDT
    assert ERC20(token).approve(spender, amount, default_return_value=True), "approval failed"

@internal
def _erc20_safe_transfer_from(token: address, sender: address, receiver: address, amount: uint256):
    # Used only to transfer tokens that are not the type managed by this Vault.
    # Used to handle non-compliant tokens like USDT
    assert ERC20(token).transferFrom(sender, receiver, amount, default_return_value=True), "transfer failed"

@internal
def _erc20_safe_transfer(token: address, receiver: address, amount: uint256):
    # Used only to send tokens that are not the type managed by this Vault.
    # Used to handle non-compliant tokens like USDT
    assert ERC20(token).transfer(receiver, amount, default_return_value=True), "transfer failed"

@internal
def _issue_shares(shares: uint256, recipient: address):
    self.balance_of[recipient] = unsafe_add(self.balance_of[recipient], shares)
    self.total_supply += shares

    log Transfer(empty(address), recipient, shares)

