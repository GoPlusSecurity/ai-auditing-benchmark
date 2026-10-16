    function _assertBondGroup(bytes32[] memory bondIDs, uint256 maturity) internal view {
        require(bondIDs.length >= 2, "the bond group should consist of 2 or more bonds");

        /**
         * @dev Count the number of the end points on x axis. In the case of a simple SBT/LBT split,
         * 3 for SBT plus 3 for LBT equals to 6.
         * In the case of SBT with the strike price 100, (x,y) = (0,0), (100,100), (200,100) defines
         * the form of SBT on the field.
         * In the case of LBT with the strike price 100, (x,y) = (0,0), (100,0), (200,100) defines
         * the form of LBT on the field.
         * Right hand side area of the last grid point is expanded on the last line to the infinity.
         * @param nextBreakPointIndex returns the number of unique points on x axis.
         * In the case of SBT and LBT with the strike price 100, x = 0,100,200 are the unique points
         * and the number is 3.
         */
        uint256 numOfBreakPoints = 0;
        for (uint256 i = 0; i < bondIDs.length; i++) {
            BondInfo storage bond = _bonds[bondIDs[i]];
            require(bond.maturity == maturity, "the maturity of the bonds must be same");
            LineSegment[] storage polyline = _registeredFnMap[bond.fnMapID];
            numOfBreakPoints = numOfBreakPoints.add(polyline.length);
        }

        uint256 nextBreakPointIndex = 0;
        uint64[] memory rateBreakPoints = new uint64[](numOfBreakPoints);
        for (uint256 i = 0; i < bondIDs.length; i++) {
            BondInfo storage bond = _bonds[bondIDs[i]];
            LineSegment[] storage segments = _registeredFnMap[bond.fnMapID];
            for (uint256 j = 0; j < segments.length; j++) {
                uint64 breakPoint = segments[j].right.x;
                bool ok = false;

                for (uint256 k = 0; k < nextBreakPointIndex; k++) {
                    if (rateBreakPoints[k] == breakPoint) {
                        ok = true;
                        break;
                    }
                }

                if (ok) {
                    continue;
                }

                rateBreakPoints[nextBreakPointIndex] = breakPoint;
                nextBreakPointIndex++;
            }
        }

        for (uint256 k = 0; k < rateBreakPoints.length; k++) {
            uint64 rate = rateBreakPoints[k];
            uint256 totalBondPriceN = 0;
            uint256 totalBondPriceD = 1;
            for (uint256 i = 0; i < bondIDs.length; i++) {
                BondInfo storage bond = _bonds[bondIDs[i]];
                LineSegment[] storage segments = _registeredFnMap[bond.fnMapID];
                (uint256 segmentIndex, bool ok) = _correspondSegment(segments, rate);

                require(ok, "invalid domain expression");

                (uint128 n, uint64 d) = _mapXtoY(segments[segmentIndex], rate);

                if (n != 0) {
                    // a/b + c/d = (ad+bc)/bd
                    // totalBondPrice += (n / d);
                    // N = D*n + N*d, D = D*d
                    totalBondPriceN = totalBondPriceD.mul(n).add(totalBondPriceN.mul(d));
                    totalBondPriceD = totalBondPriceD.mul(d);
                }
            }
            /**
             * @dev Ensure that totalBondPrice (= totalBondPriceN / totalBondPriceD) is the same
             * with rate. Because we need 1 Ether to mint a unit of each bond token respectively,
             * the sum of cashflow (USD) per a unit of bond token is the same as USD/ETH
             * rate at maturity.
             */
            require(
                totalBondPriceN == totalBondPriceD.mul(rate),
                "the total price at any rateBreakPoints should be the same value as the rate"
            );
        }
    }
