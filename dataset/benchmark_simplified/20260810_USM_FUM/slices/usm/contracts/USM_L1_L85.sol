// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "erc20permit/contracts/ERC20Permit.sol";
import "./IUSM.sol";
import "./OptOutable.sol";
import "./oracles/Oracle.sol";
import "./Address.sol";
import "./WadMath.sol";
import "./FUM.sol";
import "./MinOut.sol";

/**
 * @title USM
 * @author Alberto Cuesta Cañada, Jacob Eliosoff, Alex Roan
 * @notice Concept by Jacob Eliosoff (@jacob-eliosoff).
 */
contract USM is IUSM, ERC20Permit, OptOutable {
    using Address for address payable;
    using WadMath for uint;

    uint public constant WAD = 1e18;
    uint private constant FOUR_WAD = 4 * WAD;                                       // public for these just clutters etherscan
    uint private constant MILLION = 1e6;
    uint private constant TRILLION = 1e12;
    uint private constant HALF_TRILLION = TRILLION / 2;
    uint public constant MAX_DEBT_RATIO = WAD * 8 / 10;                             // 80%
    uint public constant MIN_FUM_BUY_PRICE_DECAY_PER_SECOND = 999991977495368426;   // 1-sec decay equiv to halving in 1 day
    uint public constant BID_ASK_ADJUSTMENT_DECAY_PER_SECOND = 988514020352896135;  // 1-sec decay equiv to halving in 1 minute
    uint public constant BID_ASK_ADJUSTMENT_ZERO_OUT_PERIOD = 600;                  // After 10 min, adjustment just goes to 0

    uint public constant PREFUND_END_TIMESTAMP = 1635724800;                        // Midnight (UTC), morning of Nov 1, 2021
    uint public constant PREFUND_FUM_PRICE_IN_ETH = WAD / 4000;                     // Prefund FUM price: 1/4000 = 0.00025 ETH

    IFUM public immutable override fum;
    Oracle public immutable oracle;

    struct StoredState {
        uint32 timeSystemWentUnderwater;    // Time at which (we noticed) debt ratio went > MAX, or 0 if it's currently < MAX
        uint64 ethUsdPrice;                 // Stored in millionths, not WADs: so 123.456 is stored as 123,456,000
        uint64 oracleEthUsdPrice;           // Millionths, not WADs
        uint32 bidAskAdjustmentTimestamp;
        uint64 bidAskAdjustment;            // Millionths, not WADs
    }

    struct LoadedState {
        uint timeSystemWentUnderwater;
        uint ethUsdPrice;                   // This one is in WADs, not millionths
        uint oracleEthUsdPrice;             // WADs, not millionths
        uint bidAskAdjustmentTimestamp;
        uint bidAskAdjustment;              // WADs, not millionths
        uint ethPool;
        uint usmTotalSupply;
    }

    StoredState public storedState = StoredState({
        timeSystemWentUnderwater: 0, ethUsdPrice: 0, oracleEthUsdPrice: 0,
        bidAskAdjustmentTimestamp: 0, bidAskAdjustment: uint64(MILLION)         // Initialize adjustment to 1.0 (scaled by 1m)
    });

    constructor(Oracle oracle_,
                address[] memory addressesYouCantSendThisContractsTokensTo,
                address[] memory contractsToAskToRejectSendsToThisContractsAddress)
        ERC20Permit("Minimalist USD v1 - Release Candidate 1", "USM")
        OptOutable(addressesYouCantSendThisContractsTokensTo, contractsToAskToRejectSendsToThisContractsAddress)
    {
        oracle = oracle_;
        fum = new FUM(addressesYouCantSendThisContractsTokensTo, contractsToAskToRejectSendsToThisContractsAddress);
    }

    // ____________________ Modifiers ____________________

    /**
     * @dev Some operations are only allowed after the initial "prefund" (fixed-price funding) period.
     */
    modifier onlyAfterPrefund {
        require(!isDuringPrefund(), "Not allowed during prefund");
        _;
    }

    // ____________________ External transactional functions ____________________

    /**
     * @notice Mint new USM, sending it to the given address, and only if the amount minted >= `minUsmOut`.  The amount of ETH
     * is passed in as `msg.value`.
