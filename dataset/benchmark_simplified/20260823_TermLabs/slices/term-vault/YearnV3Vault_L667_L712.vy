@view
@internal
def _assess_share_of_unrealised_losses(strategy: address, strategy_current_debt: uint256, assets_needed: uint256) -> uint256:
    """
    Returns the share of losses that a user would take if withdrawing from this strategy
    This accounts for losses that have been realized at the strategy level but not yet
    realized at the vault level.

    e.g. if the strategy has unrealised losses for 10% of its current debt and the user 
    wants to withdraw 1_000 tokens, the losses that they will take is 100 token
    """
    # The actual amount that the debt is currently worth.
    vault_shares: uint256 = IStrategy(strategy).balanceOf(self)
    strategy_assets: uint256 = IStrategy(strategy).convertToAssets(vault_shares)
    
    # If no losses, return 0
    if strategy_assets >= strategy_current_debt or strategy_current_debt == 0:
        return 0

    # Users will withdraw assets_needed divided by loss ratio (strategy_assets / strategy_current_debt - 1).
    # NOTE: If there are unrealised losses, the user will take his share.
    numerator: uint256 = assets_needed * strategy_assets
    users_share_of_loss: uint256 = assets_needed - numerator / strategy_current_debt
    # Always round up.
    if numerator % strategy_current_debt != 0:
        users_share_of_loss += 1

    return users_share_of_loss

@internal
def _withdraw_from_strategy(strategy: address, assets_to_withdraw: uint256):
    """
    This takes the amount denominated in asset and performs a {redeem}
    with the corresponding amount of shares.

    We use {redeem} to natively take on losses without additional non-4626 standard parameters.
    """
    # Need to get shares since we use redeem to be able to take on losses.
    shares_to_redeem: uint256 = min(
        # Use previewWithdraw since it should round up.
        IStrategy(strategy).previewWithdraw(assets_to_withdraw), 
        # And check against our actual balance.
        IStrategy(strategy).balanceOf(self)
    )
    # Redeem the shares.
    IStrategy(strategy).redeem(shares_to_redeem, self, self)
