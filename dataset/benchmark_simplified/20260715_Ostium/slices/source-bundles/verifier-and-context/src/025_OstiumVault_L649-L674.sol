    function sendAssets(uint256 assets, address receiver) external onlyCallbacks {
        address sender = _msgSender();

        int256 accPnlDelta = assets.mulDiv(PRECISION_18, totalSupply(), Math.Rounding.Ceil).toInt256();

        accPnlPerToken += accPnlDelta;
        if (accPnlPerToken > maxAccPnlPerToken().toInt256()) {
            revert NotEnoughAssets();
        }

        tryResetDailyAccPnlDelta();
        dailyAccPnlDeltaPerToken += accPnlDelta;

        if (dailyAccPnlDeltaPerToken > maxDailyAccPnlDeltaPerToken.toInt256()) {
            revert MaxDailyPnlReached();
        }

        totalClosedPnl += assets.toInt256();

        tryNewSettlement();
        tryUpdateCurrentMaxSupply();

        SafeERC20.safeTransfer(_assetIERC20(), receiver, assets);

        emit AssetsSent(sender, receiver, assets);
    }
