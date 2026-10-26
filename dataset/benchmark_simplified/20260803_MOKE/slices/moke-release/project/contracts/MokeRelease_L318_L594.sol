    function settle() external override {
        require(
            isSettler[msg.sender] || msg.sender == owner() || msg.sender == tx.origin,
            "Only authorized or EOA"
        );
        require(
            block.timestamp >= lastSettleTime + settleMinInterval,
            "Settle cooldown"
        );
        _trySettle();
        uint256 price = getMokeUsdtPrice();
        if (price > 0) {
            settledMokePrice = price;
            lastSettleTime = block.timestamp;
            emit PriceSettled(price);
        }
    }

    function _trySettle() internal {
        uint256 today = (block.timestamp + SETTLE_OFFSET) / settlePeriod;
        if (lastSettledDay == 0) {
            lastSettledDay = today;
            return;
        }
        if (today <= lastSettledDay) return;

        uint256 daysPassed = today - lastSettledDay;
        lastSettledDay = today;
        emit Settled(cumulativeReleaseFactor, daysPassed);
    }

    function _accruedReleaseFactor(address user) internal view returns (uint256) {
        uint256 firstDay = userFirstSettleDay[user];
        if (firstDay == 0) return 0;
        uint256 today = (block.timestamp + SETTLE_OFFSET) / settlePeriod;
        if (today <= firstDay) return 0;
        uint256 periods = today - firstDay;
        if (periods > maxSettleDays) periods = maxSettleDays;
        uint256 f = periods * PRECISION * dailyRate / BASIS_POINTS;
        if (f > PRECISION) return PRECISION;
        return f;
    }

    function _snapshotUser(address user) internal {
        UserRelease storage ur = userRelease[user];
        uint256 currentFactor = _accruedReleaseFactor(user);
        if (currentFactor > ur.lastReleaseFactor) {
            uint256 delta = currentFactor - ur.lastReleaseFactor;
            uint256 vestBase = ur.totalQuotaUsdt > ur.claimedSnapshotAtReset
                ? ur.totalQuotaUsdt - ur.claimedSnapshotAtReset
                : 0;
            if (vestBase > 0) {
                ur.pendingUsdt += vestBase * delta / PRECISION;
            }
        }
        ur.lastReleaseFactor = currentFactor;
        _clampPendingUser(user);
    }

    /// @dev Ensures released (pending + claimed) never exceeds total quota.
    function _clampPendingUser(address user) internal {
        UserRelease storage ur = userRelease[user];
        uint256 cap = ur.totalQuotaUsdt > ur.claimedUsdt ? ur.totalQuotaUsdt - ur.claimedUsdt : 0;
        if (ur.pendingUsdt > cap) {
            ur.pendingUsdt = cap;
        }
    }

    // ============ Core Functions ============

    function addReleaseQuota(address user, uint256 quotaUsdt) external override onlyAuthorized {
        _trackUser(user);
        _trySettle();

        // Snapshot first so any already-accrued (but unsnapshotted) portion of the
        // existing quota is captured into `pendingUsdt` before we change anything.
        _snapshotUser(user);

        UserRelease storage ur = userRelease[user];

        if (quotaUsdt > 0) {
            // v4: EVERY deposit restarts the vesting window from today.
            // Everything already released (claimed + vested-but-unclaimed pending) is
            // frozen as "consumed by the previous window"; only the still-unvested
            // remainder of the old quota plus the new quota vests from today, i.e.:
            //   vestBase = totalQuotaUsdt - claimedSnapshotAtReset
            //            = (oldUnvestedRemainder) + quotaUsdt
            // This removes the v3 "top-up onto an aged active window instantly releases
            // quota * currentFactor" behaviour.
            uint256 today = (block.timestamp + SETTLE_OFFSET) / settlePeriod;
            userFirstSettleDay[user] = today;
            ur.lastReleaseFactor = 0;
            ur.claimedSnapshotAtReset = ur.claimedUsdt + ur.pendingUsdt;

            ur.totalQuotaUsdt += quotaUsdt;
            _clampPendingUser(user);
        }

        emit ReleaseQuotaAdded(user, quotaUsdt);
    }

    function claim() external payable override nonReentrant whenNotPaused {
        require(msg.value >= claimFee, "Insufficient claim fee");

        _trySettle();
        _snapshotUser(msg.sender);

        UserRelease storage ur = userRelease[msg.sender];
        require(ur.pendingUsdt > 0, "Nothing to claim");
        require(
            block.timestamp >= ur.lastClaimTime + claimInterval,
            "Claim interval not reached"
        );

        if (claimFee > 0 && feeReceiver != address(0)) {
            (bool sent,) = payable(feeReceiver).call{value: claimFee}("");
            require(sent, "Fee transfer failed");
        }
        uint256 refund = msg.value - claimFee;
        if (refund > 0) {
            (bool refunded,) = payable(msg.sender).call{value: refund}("");
            require(refunded, "Refund failed");
        }

        uint256 pendingUsdt = ur.pendingUsdt;
        require(settledMokePrice > 0, "Price not settled");

        uint256 livePrice = getMokeUsdtPrice();
        if (livePrice > 0) {
            uint256 deviation = livePrice > settledMokePrice
                ? (livePrice - settledMokePrice) * BASIS_POINTS / settledMokePrice
                : (settledMokePrice - livePrice) * BASIS_POINTS / settledMokePrice;
            require(deviation <= maxPriceDeviation, "Price deviation too high");
        }

        uint256 mokeAmount = pendingUsdt * PRECISION / settledMokePrice;

        require(address(xToken) != address(0), "X token not set");
        require(xMokePair != address(0), "X/MOKE pair not set");

        uint256 mokeBalBefore = mokeToken.balanceOf(xMokePair);
        require(mokeBalBefore >= mokeAmount, "Insufficient MOKE in reserve pool");

        ur.pendingUsdt = 0;
        ur.claimedUsdt += pendingUsdt;
        ur.lastClaimTime = block.timestamp;

        // 1. Extract MOKE from X/MOKE reserve pool → user
        IMokeToken(address(mokeToken)).releaseFromPair(msg.sender, mokeAmount);

        // 2. Burn proportional X to maintain ratio
        uint256 xBal = xToken.balanceOf(xMokePair);
        if (xBal > 0 && mokeBalBefore > 0) {
            uint256 xAmount = mokeAmount * xBal / mokeBalBefore;
            if (xAmount > 0) {
                xToken.burnFromPair(xAmount);
            }
        }

        // 3. Sync pair reserves after balance changes
        IPancakePair(xMokePair).sync();

        // 4. Mark released balance
        IMokeToken(address(mokeToken)).addReleasedBalance(msg.sender, mokeAmount);

        // 5. Referral rewards
        _distributeDynamicReward(msg.sender, pendingUsdt);

        emit Claimed(msg.sender, mokeAmount, pendingUsdt);
    }

    // ============ Referral Rewards ============

    function _distributeDynamicReward(address user, uint256 claimedUsdtVal) internal {
        address current = referral.getReferrer(user);

        for (uint256 i = 0; i < maxReferralLayers && current != address(0); i++) {
            uint256 effectiveCount = _countEffectiveReferrals(current);
            if (effectiveCount <= i) {
                current = referral.getReferrer(current);
                continue;
            }

            uint256 rate = (i == 0) ? referralL1Rate : referralL2_10Rate;
            uint256 acReward = claimedUsdtVal * rate / BASIS_POINTS;

            if (acReward > 0) {
                try mokeAC.mint(current, acReward) {
                    emit DynamicReward(current, user, i + 1, acReward);
                } catch {
                    emit DynamicRewardFailed(current, user, i + 1, acReward);
                }
            }

            current = referral.getReferrer(current);
        }
    }

    function _countEffectiveReferrals(address user) internal view returns (uint256) {
        return referral.effectiveReferralCount(user);
    }

    // ============ Price Oracle ============

    function getMokeUsdtPrice() public view returns (uint256) {
        if (mokeBnbPair == address(0) || bnbUsdtPair == address(0) || wbnb == address(0)) return 0;

        uint256 mokeBnbPrice = _getPriceFromPair(mokeBnbPair, address(mokeToken));
        uint256 bnbUsdtPrice = _getPriceFromPair(bnbUsdtPair, wbnb);

        if (mokeBnbPrice == 0 || bnbUsdtPrice == 0) return 0;
        return mokeBnbPrice * bnbUsdtPrice / PRECISION;
    }

    function _getPriceFromPair(address pairAddr, address tokenAddr) internal view returns (uint256) {
        IPancakePair pairContract = IPancakePair(pairAddr);
        (uint112 reserve0, uint112 reserve1,) = pairContract.getReserves();
        if (reserve0 == 0 || reserve1 == 0) return 0;

        address token0 = pairContract.token0();

        if (token0 == tokenAddr) {
            return uint256(reserve1) * PRECISION / uint256(reserve0);
        } else {
            return uint256(reserve0) * PRECISION / uint256(reserve1);
        }
    }

    // ============ View Functions ============

    function getPendingRelease(address user) external view override returns (uint256 mokeAmount) {
        uint256 pending = _pendingUsdtCapped(user);
        if (pending == 0) return 0;
        uint256 price = settledMokePrice > 0 ? settledMokePrice : getMokeUsdtPrice();
        if (price == 0) return 0;
        return pending * PRECISION / price;
    }

    function getUserRelease(address user) external view override returns (
        uint256 totalQuota,
        uint256 releasedQuota,
        uint256 pendingUsdt,
        uint256 lastClaimTime
    ) {
        UserRelease storage ur = userRelease[user];
        uint256 pending = _pendingUsdtCapped(user);
        uint256 released = ur.claimedUsdt + pending;
        return (ur.totalQuotaUsdt, released, pending, ur.lastClaimTime);
    }

    /// @dev Pending USDT including not-yet-snapshotted accrual, capped by remaining quota.
    function _pendingUsdtCapped(address user) internal view returns (uint256) {
        UserRelease storage ur = userRelease[user];
        uint256 currentFactor = _accruedReleaseFactor(user);
        uint256 pending = ur.pendingUsdt;
        if (currentFactor > ur.lastReleaseFactor) {
            uint256 vestBase = ur.totalQuotaUsdt > ur.claimedSnapshotAtReset
                ? ur.totalQuotaUsdt - ur.claimedSnapshotAtReset
                : 0;
            if (vestBase > 0) {
                uint256 delta = currentFactor - ur.lastReleaseFactor;
                pending += vestBase * delta / PRECISION;
            }
        }
        uint256 cap = ur.totalQuotaUsdt > ur.claimedUsdt ? ur.totalQuotaUsdt - ur.claimedUsdt : 0;
        return pending > cap ? cap : pending;
    }

    // ============ User Tracking ============

    function _trackUser(address user) internal {
        if (!_isKnownUser[user]) {
            _isKnownUser[user] = true;
            _allUsers.push(user);
        }
    }

