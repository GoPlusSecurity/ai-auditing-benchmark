@internal
def _add_strategy(new_strategy: address, add_to_queue: bool):
    assert new_strategy not in [self, empty(address)], "strategy cannot be zero address"
    assert IStrategy(new_strategy).asset() == self.asset, "invalid asset"
    assert self.strategies[new_strategy].activation == 0, "strategy already active"

    # Add the new strategy to the mapping.
    self.strategies[new_strategy] = StrategyParams({
        activation: block.timestamp,
        last_report: block.timestamp,
        current_debt: 0,
        max_debt: 0
    })

    # If we are adding to the queue and the default queue has space, add the strategy.
    if add_to_queue and len(self.default_queue) < MAX_QUEUE:
        self.default_queue.append(new_strategy)        
        
    log StrategyChanged(new_strategy, StrategyChangeType.ADDED)

