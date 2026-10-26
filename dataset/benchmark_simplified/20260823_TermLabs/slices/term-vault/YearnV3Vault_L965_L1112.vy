@internal
def _update_debt(strategy: address, target_debt: uint256, max_loss: uint256) -> uint256:
    """
    The vault will re-balance the debt vs target debt. Target debt must be
    smaller or equal to strategy's max_debt. This function will compare the 
    current debt with the target debt and will take funds or deposit new 
    funds to the strategy. 

    The strategy can require a maximum amount of funds that it wants to receive
    to invest. The strategy can also reject freeing funds if they are locked.
    """
    # How much we want the strategy to have.
    new_debt: uint256 = target_debt
    # How much the strategy currently has.
    current_debt: uint256 = self.strategies[strategy].current_debt

    # If the vault is shutdown we can only pull funds.
    if self.shutdown:
        new_debt = 0

    assert new_debt != current_debt, "new debt equals current debt"

    if current_debt > new_debt:
        # Reduce debt.
        assets_to_withdraw: uint256 = unsafe_sub(current_debt, new_debt)

        # Ensure we always have minimum_total_idle when updating debt.
        minimum_total_idle: uint256 = self.minimum_total_idle
        total_idle: uint256 = self.total_idle
        
        # Respect minimum total idle in vault
        if total_idle + assets_to_withdraw < minimum_total_idle:
            assets_to_withdraw = unsafe_sub(minimum_total_idle, total_idle)
            # Cant withdraw more than the strategy has.
            if assets_to_withdraw > current_debt:
                assets_to_withdraw = current_debt

        # Check how much we are able to withdraw.
        # Use maxRedeem and convert since we use redeem.
        withdrawable: uint256 = IStrategy(strategy).convertToAssets(
            IStrategy(strategy).maxRedeem(self)
        )

        # If insufficient withdrawable, withdraw what we can.
        if withdrawable < assets_to_withdraw:
            assets_to_withdraw = withdrawable

        if assets_to_withdraw == 0:
            return current_debt

        # If there are unrealised losses we don't let the vault reduce its debt until there is a new report
        unrealised_losses_share: uint256 = self._assess_share_of_unrealised_losses(strategy, current_debt, assets_to_withdraw)
        assert unrealised_losses_share == 0, "strategy has unrealised losses"
        
        # Cache for repeated use.
        _asset: address = self.asset

        # Always check the actual amount withdrawn.
        pre_balance: uint256 = ERC20(_asset).balanceOf(self)
        self._withdraw_from_strategy(strategy, assets_to_withdraw)
        post_balance: uint256 = ERC20(_asset).balanceOf(self)
        
        # making sure we are changing idle according to the real result no matter what. 
        # We pull funds with {redeem} so there can be losses or rounding differences.
        withdrawn: uint256 = min(post_balance - pre_balance, current_debt)

        # If we didn't get the amount we asked for and there is a max loss.
        if withdrawn < assets_to_withdraw and max_loss < MAX_BPS:
            # Make sure the loss is within the allowed range.
            assert unsafe_sub(assets_to_withdraw, withdrawn) <= assets_to_withdraw * max_loss / MAX_BPS, "too much loss"

        # If we got too much make sure not to increase PPS.
        elif withdrawn > assets_to_withdraw:
            assets_to_withdraw = withdrawn

        # Update storage.
        self.total_idle += withdrawn # actual amount we got.
        # Amount we tried to withdraw in case of losses
        self.total_debt -= assets_to_withdraw 

        new_debt = current_debt - assets_to_withdraw
    else: 
        # We are increasing the strategies debt

        # Respect the maximum amount allowed.
        max_debt: uint256 = self.strategies[strategy].max_debt
        if new_debt > max_debt:
            new_debt = max_debt
            # Possible for current to be greater than max from reports.
            if new_debt < current_debt:
                return current_debt

        # Vault is increasing debt with the strategy by sending more funds.
        max_deposit: uint256 = IStrategy(strategy).maxDeposit(self)
        if max_deposit == 0:
            return current_debt

        # Deposit the difference between desired and current.
        assets_to_deposit: uint256 = new_debt - current_debt
        if assets_to_deposit > max_deposit:
            # Deposit as much as possible.
            assets_to_deposit = max_deposit
        
        # Ensure we always have minimum_total_idle when updating debt.
        minimum_total_idle: uint256 = self.minimum_total_idle
        total_idle: uint256 = self.total_idle

        if total_idle <= minimum_total_idle:
            return current_debt
        
        available_idle: uint256 = unsafe_sub(total_idle, minimum_total_idle)

        # If insufficient funds to deposit, transfer only what is free.
        if assets_to_deposit > available_idle:
            assets_to_deposit = available_idle

        # Can't Deposit 0.
        if assets_to_deposit > 0:
            # Cache for repeated use.
            _asset: address = self.asset

            # Approve the strategy to pull only what we are giving it.
            self._erc20_safe_approve(_asset, strategy, assets_to_deposit)

            # Always update based on actual amounts deposited.
            pre_balance: uint256 = ERC20(_asset).balanceOf(self)
            IStrategy(strategy).deposit(assets_to_deposit, self)
            post_balance: uint256 = ERC20(_asset).balanceOf(self)

            # Make sure our approval is always back to 0.
            self._erc20_safe_approve(_asset, strategy, 0)

            # Making sure we are changing according to the real result no 
            # matter what. This will spend more gas but makes it more robust.
            assets_to_deposit = pre_balance - post_balance

            # Update storage.
            self.total_idle -= assets_to_deposit
            self.total_debt += assets_to_deposit

        new_debt = current_debt + assets_to_deposit

    # Commit memory to storage.
    self.strategies[strategy].current_debt = new_debt

    log DebtUpdated(strategy, current_debt, new_debt)
    return new_debt

