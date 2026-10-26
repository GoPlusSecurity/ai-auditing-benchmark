    function mintAllowed(address mToken, address minter, uint mintAmount) override external returns (uint) {
        // Pausing is a very serious situation - we revert to sound the alarms
        require(!mintGuardianPaused[mToken], "mint is paused");

        // Shh - currently unused
        mintAmount;

        if (!markets[mToken].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        uint supplyCap = supplyCaps[mToken];
        // Supply cap of 0 corresponds to unlimited supplying
        if (supplyCap != 0) {
            uint totalCash = MToken(mToken).getCash();
            uint totalBorrows = MToken(mToken).totalBorrows();
            uint totalReserves = MToken(mToken).totalReserves();
            // totalSupplies = totalCash + totalBorrows - totalReserves
            uint totalSupplies = sub_(add_(totalCash, totalBorrows), totalReserves);

            uint nextTotalSupplies = add_(totalSupplies, mintAmount);
            require(nextTotalSupplies < supplyCap, "market supply cap reached");
        }

        // Keep the flywheel moving
        updateAndDistributeSupplierRewardsForToken(mToken, minter);
        return uint(Error.NO_ERROR);
    }
