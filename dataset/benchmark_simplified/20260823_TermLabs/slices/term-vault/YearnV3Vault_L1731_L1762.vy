## DEBT MANAGEMENT ##
@external
def update_max_debt_for_strategy(strategy: address, new_max_debt: uint256):
    """
    @notice Update the max debt for a strategy.
    @param strategy The strategy to update the max debt for.
    @param new_max_debt The new max debt for the strategy.
    """
    self._enforce_role(msg.sender, Roles.MAX_DEBT_MANAGER)
    assert self.strategies[strategy].activation != 0, "inactive strategy"
    self.strategies[strategy].max_debt = new_max_debt

    log UpdatedMaxDebtForStrategy(msg.sender, strategy, new_max_debt)

@external
@nonreentrant("lock")
def update_debt(
    strategy: address, 
    target_debt: uint256, 
    max_loss: uint256 = MAX_BPS
) -> uint256:
    """
    @notice Update the debt for a strategy.
    @dev Pass max uint256 to allocate as much idle as possible.
    @param strategy The strategy to update the debt for.
    @param target_debt The target debt for the strategy.
    @param max_loss Optional to check realized losses on debt decreases.
    @return The new current debt of the strategy.
    """
    self._enforce_role(msg.sender, Roles.DEBT_MANAGER)
    return self._update_debt(strategy, target_debt, max_loss)

