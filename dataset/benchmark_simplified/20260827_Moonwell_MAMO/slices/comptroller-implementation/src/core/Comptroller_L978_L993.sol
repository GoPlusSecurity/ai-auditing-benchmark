    function updateAndDistributeSupplierRewardsForToken(address mToken, address supplier) internal {
        if (address(rewardDistributor) != address(0)){
            rewardDistributor.updateMarketSupplyIndexAndDisburseSupplierRewards(MToken(mToken), supplier, false);
        }
    }

   /**
     * @notice Call out to the reward distributor to update its borrow index and this user's index too
     * @param mToken The market to synchronize indexes for
     * @param borrower The borrower to whom rewards are going
     */
    function updateAndDistributeBorrowerRewardsForToken(address mToken, address borrower) internal {
        if (address(rewardDistributor) != address(0)){
            rewardDistributor.updateMarketBorrowIndexAndDisburseBorrowerRewards(MToken(mToken), borrower, false);
        }
    }
