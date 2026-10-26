    function syncUserLP(address user) external override {
        _syncUserLP(user);
    }

    function batchSyncUserLP(address[] calldata users) external {
        for (uint256 i = 0; i < users.length; i++) {
            _syncUserLP(users[i]);
        }
    }

    function _syncUserLP(address user) internal {
        uint256 currentLP = lpToken.balanceOf(user);
        uint256 recordedLP = userLPRecord[user];

        if (recordedLP > 0) {
            uint256 accumulated = recordedLP * totalDividendPerLP / 1e18;
            uint256 debt = userDividendDebt[user];
            if (accumulated > debt) {
                userPendingDividend[user] += accumulated - debt;
            }
        }

        if (currentLP != recordedLP) {
            emit UserLPSynced(user, recordedLP, currentLP);
        }

        userLPRecord[user] = currentLP;
        userDividendDebt[user] = currentLP * totalDividendPerLP / 1e18;
    }

    // ============ Core Functions ============

    function distributeDividend() external payable override nonReentrant whenNotPaused {
        uint256 mokeBalance = mokeToken.balanceOf(address(this));

        uint256 bnbAmount;
        if (mokeBalance >= minSwapAmount) {
            bnbAmount = _swapMOKEForBNB(mokeBalance);
        }
        bnbAmount += unprocessedBNB + msg.value;
        unprocessedBNB = 0;

        if (bnbAmount < minDistributeAmount) {
            unprocessedBNB = bnbAmount;
            return;
        }

        uint256 totalLP = lpToken.totalSupply();
        if (totalLP == 0) {
            unprocessedBNB = bnbAmount;
            return;
        }

        uint256 perLP = bnbAmount * 1e18 / totalLP;
        totalDividendPerLP += perLP;

        emit DividendDistributed(bnbAmount, totalLP, perLP);
    }

    function claimDividend() external override nonReentrant whenNotPaused {
        _syncUserLP(msg.sender);

        uint256 pending = userPendingDividend[msg.sender];
        require(pending > 0, "No dividend");

        userPendingDividend[msg.sender] = 0;

        (bool sent,) = payable(msg.sender).call{value: pending}("");
        require(sent, "Transfer failed");

        emit DividendClaimed(msg.sender, pending);
    }

    function getPendingDividend(address user) external view override returns (uint256) {
        uint256 currentLP = lpToken.balanceOf(user);
        uint256 accumulated = currentLP * totalDividendPerLP / 1e18;
        uint256 debt = userDividendDebt[user];
        return userPendingDividend[user] + (accumulated > debt ? accumulated - debt : 0);
    }

    // ============ Swap ============

    function _swapMOKEForBNB(uint256 mokeAmount) internal returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(mokeToken);
        path[1] = router.WETH();

        uint256 minOut = _getMinOutput(mokeAmount, path[0], path[1]);
        mokeToken.forceApprove(address(router), mokeAmount);

        _swapping = true;
        uint256 before = address(this).balance;
        try router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            mokeAmount, minOut, path, address(this), block.timestamp + 300
        ) {
            uint256 received = address(this).balance - before;
            _swapping = false;
            return received;
        } catch {
            _swapping = false;
            return 0;
        }
    }

    function _getMinOutput(uint256 amountIn, address tokenIn, address tokenOut) internal view returns (uint256) {
        address factory = router.factory();
        address pair = IPancakeFactoryLP(factory).getPair(tokenIn, tokenOut);
        if (pair == address(0)) return 0;
        try IPancakePairLP(pair).getReserves() returns (uint112 r0, uint112 r1, uint32) {
            address t0 = IPancakePairLP(pair).token0();
            uint256 reserveIn;
            uint256 reserveOut;
            if (t0 == tokenIn) { reserveIn = r0; reserveOut = r1; }
            else { reserveIn = r1; reserveOut = r0; }
            if (reserveIn == 0 || reserveOut == 0) return 0;
            uint256 amountInWithFee = amountIn * 997;
            uint256 expectedOut = amountInWithFee * reserveOut / (reserveIn * 1000 + amountInWithFee);
            return expectedOut * (BASIS_POINTS - swapSlippageBps) / BASIS_POINTS;
        } catch {
            return 0;
        }
    }

    // ============ Emergency / Pausable ============
