    function exit(address dst, uint256 wad) external {
        uint256 chi = (block.timestamp > PotLike(pot).rho()) ? PotLike(pot).drip() : PotLike(pot).chi();
        uint256 pie = rdivup(wad, chi);

        claimableFees[VerusConstants.VDXFID_DAI_DSR_SUPPLY] = sub(claimableFees[VerusConstants.VDXFID_DAI_DSR_SUPPLY], pie);
        PotLike(pot).exit(pie);
        uint256 amt = rmul(chi, pie);
        claimableFees[VerusConstants.VDXF_SYSTEM_DAI_HOLDINGS] = sub(claimableFees[VerusConstants.VDXF_SYSTEM_DAI_HOLDINGS], amt) ;
        JoinLike(daiJoin).exit(dst, amt);
    }
