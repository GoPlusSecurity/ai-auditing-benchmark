

abstract contract BondMaker is UseSafeMath, BondMakerInterface, Time, Polyline, UseOracle {
    uint8 internal immutable DECIMALS_OF_BOND;
    uint8 internal immutable DECIMALS_OF_ORACLE_PRICE;
    address internal immutable FEE_TAKER;
    uint256 internal immutable MATURITY_SCALE;

    uint256 public nextBondGroupID = 1;

    /**
     * @dev The contents in this internal storage variable can be seen by getBond function.
     */
    struct BondInfo {
        uint256 maturity;
        BondTokenInterface contractInstance;
        uint64 strikePrice;
        bytes32 fnMapID;
    }
    mapping(bytes32 => BondInfo) internal _bonds;

    /**
     * @notice mapping fnMapID to polyline
     * @dev The contents in this internal storage variable can be seen by getFnMap function.
     */
    mapping(bytes32 => LineSegment[]) internal _registeredFnMap;

    /**
     * @dev The contents in this internal storage variable can be seen by getBondGroup function.
     */
    struct BondGroup {
        bytes32[] bondIDs;
        uint256 maturity;
    }
    mapping(uint256 => BondGroup) internal _bondGroupList;

    constructor(
        address oracleAddress,
        address feeTaker,
        uint256 maturityScale,
        uint8 decimalsOfBond,
        uint8 decimalsOfOraclePrice
    ) public UseOracle(oracleAddress) {
        require(decimalsOfBond < 19, "the decimals of bond must be less than 19");
        DECIMALS_OF_BOND = decimalsOfBond;
        require(decimalsOfOraclePrice < 19, "the decimals of oracle price must be less than 19");
        DECIMALS_OF_ORACLE_PRICE = decimalsOfOraclePrice;
        require(feeTaker != address(0), "the fee taker must be non-zero address");
        FEE_TAKER = feeTaker;
        require(maturityScale != 0, "MATURITY_SCALE must be positive");
        MATURITY_SCALE = maturityScale;
    }

    /**
     * @notice Create bond token contract.
     * The name of this bond token is its bond ID.
     * @dev To convert bytes32 to string, encode its bond ID at first, then convert to string.
     * The symbol of any bond token with bond ID is either SBT or LBT;
     * As SBT is a special case of bond token, any bond token which does not match to the form of
     * SBT is defined as LBT.
     */
    function registerNewBond(uint256 maturity, bytes calldata fnMap)
        external
        virtual
        override
        returns (
            bytes32,
            address,
            bytes32
        )
    {
        _assertBeforeMaturity(maturity);
        require(maturity < _getBlockTimestampSec() + 365 days, "the maturity is too far");
        require(
            maturity % MATURITY_SCALE == 0,
            "the maturity must be the multiple of MATURITY_SCALE"
        );

        bytes32 bondID = generateBondID(maturity, fnMap);

        // Check if the same form of bond is already registered.
        // Cannot detect if the bond is described in a different polyline while two are
        // mathematically equivalent.
        require(
            address(_bonds[bondID].contractInstance) == address(0),
            "the bond type has been already registered"
        );

        // Register function mapping if necessary.
