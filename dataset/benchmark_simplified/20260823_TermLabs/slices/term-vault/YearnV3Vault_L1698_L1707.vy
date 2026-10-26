## STRATEGY MANAGEMENT ##
@external
def add_strategy(new_strategy: address, add_to_queue: bool=True):
    """
    @notice Add a new strategy.
    @param new_strategy The new strategy to add.
    """
    self._enforce_role(msg.sender, Roles.ADD_STRATEGY_MANAGER)
    self._add_strategy(new_strategy, add_to_queue)

