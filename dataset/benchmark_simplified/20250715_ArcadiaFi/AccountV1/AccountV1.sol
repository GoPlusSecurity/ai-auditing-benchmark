/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

/*//////////////////////////////////////////////////////////////
                         FLATTENED IMPORTS
//////////////////////////////////////////////////////////////*/

library AccountErrors {
    error AccountInAuction();
    error AccountNotLiquidatable();
    error AccountUnhealthy();
    error AlreadyInitialized();
    error CreditorAlreadySet();
    error CreditorNotSet();
    error CoolDownPeriodNotPassed();
    error InvalidAccountVersion();
    error InvalidERC20Id();
    error InvalidERC721Amount();
    error InvalidRecipient();
    error InvalidRegistry();
    error NoFallback();
    error NoReentry();
    error NonZeroOpenPosition();
    error NumeraireNotFound();
    error OnlyFactory();
    error OnlyCreditor();
    error OnlyLiquidator();
    error OnlyOwner();
    error TooManyAssets();
    error UnknownAsset();
    error UnknownAssetType();
}

contract AccountStorageV1 {
    // Flag indicating if the Account is in an auction (in liquidation).
    bool public inAuction;
    // Flag Indicating if a function is locked to protect against reentrancy.
    uint8 internal locked;
    // Used to prevent the old Owner from frontrunning a transferFrom().
    // The Timestamp of the last account action, that might be disadvantageous for a new Owner
    // (withdrawals, change of Creditor, increasing liabilities...).
    uint32 public lastActionTimestamp;
    // The contract address of the liquidator, address 0 if no creditor is set.
    address public liquidator;

    // The minimum amount of collateral that must be held in the Account before a position can be opened, denominated in the numeraire.
    // Will count as Used Margin after a position is opened.
    uint96 public minimumMargin;
    // The contract address of the Registry.
    address public registry;

    // The owner of the Account.
    address public owner;
    // The contract address of the Creditor.
    address public creditor;
    // The Numeraire (the unit in which prices are measured) of the Account,
    // in which all assets and liabilities are denominated.
    address public numeraire;

    // Array with all the contract addresses of ERC20 tokens in the account.
    address[] internal erc20Stored;
    // Array with all the contract addresses of ERC721 tokens in the account.
    address[] internal erc721Stored;
    // Array with all the contract addresses of ERC1155 tokens in the account.
    address[] internal erc1155Stored;
    // Array with all the corresponding ids for each ERC721 token in the account.
    uint256[] internal erc721TokenIds;
    // Array with all the corresponding ids for each ERC1155 token in the account.
    uint256[] internal erc1155TokenIds;

    // Map asset => balance.
    mapping(address => uint256) public erc20Balances;
    // Map asset => id => balance.
    mapping(address => mapping(uint256 => uint256)) public erc1155Balances;
    // Map owner => approved Creditor.
    // This is a Creditor for which a margin Account can be opened later in time to e.g. refinance liabilities.
    mapping(address => address) public approvedCreditor;
    // Map owner => assetManager => flag.
    mapping(address => mapping(address => bool)) public isAssetManager;
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeTransferLib {
    function safeTransferETH(address to, uint256 amount) internal {
        bool success;
        assembly {
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }
        require(success, "ETH_TRANSFER_FAILED");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool success;
        assembly {
            let freeMemoryPointer := mload(0x40)
            mstore(freeMemoryPointer, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), and(from, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(freeMemoryPointer, 36), and(to, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(freeMemoryPointer, 68), amount)
            success := and(
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                call(gas(), token, 0, freeMemoryPointer, 100, 0, 32)
            )
        }
        require(success, "TRANSFER_FROM_FAILED");
    }

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success;
        assembly {
            let freeMemoryPointer := mload(0x40)
            mstore(freeMemoryPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(freeMemoryPointer, 36), amount)
            success := and(
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
            )
        }
        require(success, "TRANSFER_FAILED");
    }

    function safeApprove(IERC20 token, address to, uint256 amount) internal {
        bool success;
        assembly {
            let freeMemoryPointer := mload(0x40)
            mstore(freeMemoryPointer, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(freeMemoryPointer, 36), amount)
            success := and(
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
            )
        }
        require(success, "APPROVE_FAILED");
    }
}

struct AssetValueAndRiskFactors {
    uint256 assetValue;
    uint256 collateralFactor;
    uint256 liquidationFactor;
}

library AssetValuationLib {
    uint256 internal constant ONE_4 = 10_000;

    function _calculateCollateralValue(AssetValueAndRiskFactors[] memory valuesAndRiskFactors)
        internal
        pure
        returns (uint256 collateralValue)
    {
        for (uint256 i; i < valuesAndRiskFactors.length; ++i) {
            collateralValue += valuesAndRiskFactors[i].assetValue * valuesAndRiskFactors[i].collateralFactor;
        }
        collateralValue = collateralValue / ONE_4;
    }

    function _calculateLiquidationValue(AssetValueAndRiskFactors[] memory valuesAndRiskFactors)
        internal
        pure
        returns (uint256 liquidationValue)
    {
        for (uint256 i; i < valuesAndRiskFactors.length; ++i) {
            liquidationValue += valuesAndRiskFactors[i].assetValue * valuesAndRiskFactors[i].liquidationFactor;
        }
        liquidationValue = liquidationValue / ONE_4;
    }
}

interface IERC721 {
    function ownerOf(uint256 id) external view returns (address);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 id) external;
}

interface IERC1155 {
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
    function balanceOf(address account, uint256 id) external view returns (uint256);
}

interface IRegistry {
    function FACTORY() external view returns (address);
    function inRegistry(address asset) external view returns (bool);
    function batchGetAssetTypes(address[] calldata assetAddresses) external view returns (uint256[] memory);
    function batchProcessDeposit(
        address creditor,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata amounts
    ) external;
    function batchProcessWithdrawal(
        address creditor,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata amounts
    ) external returns (uint256[] memory);
    function getTotalValue(
        address numeraire,
        address creditor,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) external view returns (uint256);
    function getCollateralValue(
        address numeraire,
        address creditor,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) external view returns (uint256);
    function getLiquidationValue(
        address numeraire,
        address creditor,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) external view returns (uint256);
    function getValuesInNumeraire(
        address numeraire,
        address creditor,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) external view returns (AssetValueAndRiskFactors[] memory valuesAndRiskFactors);
}

interface ICreditor {
    function openMarginAccount(uint256 accountVersion) external returns (bool, address, address, uint256);
    function closeMarginAccount(address account) external;
    function getOpenPosition(address account) external view returns (uint256);
    function riskManager() external view returns (address riskManager);
    function flashActionCallback(bytes calldata callbackData) external;
    function startLiquidation(address initiator, uint256 minimumMargin) external returns (uint256);
}

struct ActionData {
    address[] assets;
    uint256[] assetIds;
    uint256[] assetAmounts;
    uint256[] assetTypes;
}

interface IActionBase {
    function executeAction(bytes calldata actionTargetData) external returns (ActionData memory);
}

interface IFactory {
    function isAccount(address account) external view returns (bool);
    function safeTransferAccount(address to) external;
}

interface IPermit2 {
    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    struct PermitBatchTransferFrom {
        TokenPermissions[] permitted;
        uint256 nonce;
        uint256 deadline;
    }

    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }

    function permitTransferFrom(
        PermitBatchTransferFrom memory permit,
        SignatureTransferDetails[] calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;
}

/**
 * @title Arcadia Accounts
 * @author Pragma Labs
 * @notice Arcadia Accounts are smart contracts that act as onchain, decentralized and composable margin accounts.
 * They provide individuals, DAOs, and other protocols with a simple and flexible way to deposit and manage multiple assets as collateral.
 * The total combination of assets can be used as margin to back liabilities issued by any financial protocol (lending, leverage, futures...).
 * @dev Users can use this Account to deposit assets (fungible, non-fungible, LP positions, yiel bearing assets...).
 * The Account will denominate all the deposited assets into one Numeraire (one unit of account, like USD or ETH).
 * Users can use the single denominated value of all their assets to take margin (take credit line, financing for leverage...).
 * An increase of value of one asset will offset a decrease in value of another asset.
 * Ensure your total value denomination remains above the liquidation threshold, or risk being liquidated!
 * @dev Integrating this Account as means of margin/collateral management for your own protocol that requires collateral is encouraged.
 * Arcadia's Account functions will guarantee you a certain value of the Account.
 * For allowlists or liquidation strategies specific to your protocol, contact pragmalabs.dev
 */
contract AccountV1 is AccountStorageV1 {
    using AssetValuationLib for AssetValueAndRiskFactors[];
    using SafeTransferLib for IERC20;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The current Account Version.
    uint256 public constant ACCOUNT_VERSION = 1;
    // The maximum amount of different assets that can be used as collateral within an Arcadia Account.
    uint256 public constant ASSET_LIMIT = 15;
    // The cool-down period after an account action, that might be disadvantageous for a new Owner,
    // during which ownership cannot be transferred to prevent the old Owner from frontrunning a transferFrom().
    uint256 internal constant COOL_DOWN_PERIOD = 5 minutes;
    // Storage slot with the address of the current implementation.
    // This is the hardcoded keccak-256 hash of: "eip1967.proxy.implementation" subtracted by 1.
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    // The contract address of the Arcadia Accounts Factory.
    address public immutable FACTORY;
    // Uniswap Permit2 contract
    IPermit2 internal immutable PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    // Storage slot for the Account implementation, a struct to avoid storage conflict when dealing with upgradeable contracts.
    struct AddressSlot {
        address value;
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event AssetManagerSet(address indexed owner, address indexed assetManager, bool value);
    event MarginAccountChanged(address indexed creditor, address indexed liquidator);
    event NumeraireSet(address indexed numeraire);

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /**
     * @dev Throws if function is reentered.
     */
    modifier nonReentrant() {
        if (locked != 1) revert AccountErrors.NoReentry();
        locked = 2;
        _;
        locked = 1;
    }

    /**
     * @dev Throws if called when the Account is in an auction.
     */
    modifier notDuringAuction() {
        if (inAuction == true) revert AccountErrors.AccountInAuction();
        _;
    }

    /**
     * @dev Throws if called by any address other than an Asset Manager or the owner.
     */
    modifier onlyAssetManager() {
        // A custom error would need to read out owner + isAssetManager storage
        require(msg.sender == owner || isAssetManager[owner][msg.sender], "A: Only Asset Manager");
        _;
    }

    /**
     * @dev Throws if called by any address other than the Creditor.
     */
    modifier onlyCreditor() {
        if (msg.sender != creditor) revert AccountErrors.OnlyCreditor();
        _;
    }

    /**
     * @dev Throws if called by any address other than the Factory address.
     */
    modifier onlyFactory() {
        if (msg.sender != FACTORY) revert AccountErrors.OnlyFactory();
        _;
    }

    /**
     * @dev Throws if called by any address other than the Liquidator address.
     */
    modifier onlyLiquidator() {
        if (msg.sender != liquidator) revert AccountErrors.OnlyLiquidator();
        _;
    }

    /**
     * @dev Throws if called by any address other than the owner.
     */
    modifier onlyOwner() {
        if (msg.sender != owner) revert AccountErrors.OnlyOwner();
        _;
    }

    /**
     * @dev Starts the cool-down period during which ownership cannot be transferred.
     * This prevents the old Owner from frontrunning a transferFrom().
     */
    modifier updateActionTimestamp() {
        lastActionTimestamp = uint32(block.timestamp);
        _;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param factory The contract address of the Arcadia Accounts Factory.
     */
    constructor(address factory) {
        // This will only be the owner of the Account implementation.
        // and will not affect any subsequent proxy implementation using this Account implementation.
        owner = msg.sender;

        FACTORY = factory;
    }

    /* ///////////////////////////////////////////////////////////////
                          MARGIN REQUIREMENTS
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Calculates the total collateral value (MTM discounted with a haircut) of the Account.
     * @return collateralValue The collateral value, returned in the decimal precision of the Numeraire.
     * @dev Returns the value denominated in the Numeraire of the Account.
     * @dev The collateral value of the Account is equal to the spot value of the underlying assets,
     * discounted by a haircut (the collateral factor). Since the value of
     * collateralized assets can fluctuate, the haircut guarantees that the Account
     * remains over-collateralized with a high confidence level.
     * The size of the haircut depends on the underlying risk of the assets in the Account.
     * The bigger the volatility or the smaller the onchain liquidity, the bigger the haircut will be.
     */
    function getCollateralValue() internal view returns (uint256 collateralValue) {
        (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) =
            generateAssetData();
        collateralValue =
            IRegistry(registry).getCollateralValue(numeraire, creditor, assetAddresses, assetIds, assetAmounts);
    }

    /**
     * @notice Returns the used margin of the Account.
     * @return usedMargin The total amount of margin that is currently in use to back liabilities.
     * @dev Used Margin is the value of the assets that is currently 'locked' to back:
     *  - All the liabilities issued against the Account.
     *  - An additional fixed buffer to cover gas fees in case of a liquidation.
     * @dev The used margin is denominated in the Numeraire.
     * @dev Currently only one Creditor at a time can open a margin account.
     * The open liability is fetched at the contract of the Creditor -> only allow trusted audited Creditors!!!
     */
    function getUsedMargin() internal view returns (uint256 usedMargin) {
        // Cache creditor
        address creditor_ = creditor;
        if (creditor_ == address(0)) return 0;

        // getOpenPosition() is a view function, cannot modify state.
        usedMargin = ICreditor(creditor_).getOpenPosition(address(this)) + minimumMargin;
    }

    /**
     * @notice Calculates the remaining margin the owner of the Account can use.
     * @return freeMargin The remaining amount of margin a user can take.
     * @dev Free Margin is the value of the assets that is still free to back additional liabilities.
     * @dev The free margin is denominated in the Numeraire.
     */

    /**
     * @notice Checks if the Account is unhealthy.
     * @return isUnhealthy Boolean indicating if the Account is unhealthy.
     */
    function isAccountUnhealthy() internal view returns (bool isUnhealthy) {
        // If usedMargin is equal to minimumMargin, the open liabilities are 0 and the Account is always healthy.
        // An Account is unhealthy if the collateral value is smaller than the used margin.
        uint256 usedMargin = getUsedMargin();
        isUnhealthy = usedMargin > minimumMargin && getCollateralValue() < usedMargin;
    }

    /*///////////////////////////////////////////////////////////////
                       ASSET MANAGER ACTIONS
    ///////////////////////////////////////////////////////////////*/
    /**
     * @notice Executes a flash action.
     * @param actionTarget The contract address of the actionTarget to execute external logic.
     * @param actionData A bytes object containing three structs and two bytes objects.
     * The first struct contains the info about the assets to withdraw from this Account to the actionTarget.
     * The second struct contains the info about the owner's assets that need to be transferred from the owner to the actionTarget.
     * The third struct contains the permit for the Permit2 transfer.
     * The first bytes object contains the signature for the Permit2 transfer.
     * The second bytes object contains the encoded input for the actionTarget.
     * @dev This function optimistically chains multiple actions together (= do a flash action):
     * - It can optimistically withdraw assets from the Account to the actionTarget.
     * - It can transfer assets directly from the owner to the actionTarget.
     * - It can execute external logic on the actionTarget, and interact with any DeFi protocol to swap, stake, claim...
     * - It can deposit all recipient tokens from the actionTarget back into the Account.
     * At the very end of the flash action, the following check is performed:
     * - The Account is in a healthy state (collateral value is greater than open liabilities).
     * If a check fails, the whole transaction reverts.
     */
    function flashAction(address actionTarget, bytes calldata actionData)
        external
        onlyAssetManager
        nonReentrant
        notDuringAuction
        updateActionTimestamp
    {
        // Decode flash action data.
        (
            ActionData memory withdrawData,
            ActionData memory transferFromOwnerData,
            IPermit2.PermitBatchTransferFrom memory permit,
            bytes memory signature,
            bytes memory actionTargetData
        ) = abi.decode(actionData, (ActionData, ActionData, IPermit2.PermitBatchTransferFrom, bytes, bytes));

        // Withdraw assets to the actionTarget.
        _withdraw(withdrawData.assets, withdrawData.assetIds, withdrawData.assetAmounts, actionTarget);

        // Transfer assets from owner (that are not assets in this account) to the actionTarget.
        if (transferFromOwnerData.assets.length > 0) {
            _transferFromOwner(transferFromOwnerData, actionTarget);
        }

        // If the function input includes a signature and non-empty token permissions,
        // initiate a transfer from the owner to the actionTarget via Permit2.
        if (signature.length > 0 && permit.permitted.length > 0) {
            _transferFromOwnerWithPermit(permit, signature, actionTarget);
        }

        // Execute external logic on the actionTarget.
        ActionData memory depositData = IActionBase(actionTarget).executeAction(actionTargetData);

        // Deposit assets from actionTarget into Account.
        _deposit(depositData.assets, depositData.assetIds, depositData.assetAmounts, actionTarget);

        // Account must be healthy after actions are executed.
        if (isAccountUnhealthy()) revert AccountErrors.AccountUnhealthy();
    }

    /**
     * @notice Deposits assets into the Account.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @param from The assets deposited into the Account will come from this address.
     */
    function _deposit(
        address[] memory assetAddresses,
        uint256[] memory assetIds,
        uint256[] memory assetAmounts,
        address from
    ) internal {
        // Transfer assets to Account before processing them.
        uint256[] memory assetTypes = IRegistry(registry).batchGetAssetTypes(assetAddresses);
        for (uint256 i; i < assetAddresses.length; ++i) {
            // Skip if amount is 0 to prevent storing addresses that have 0 balance.
            if (assetAmounts[i] == 0) continue;

            if (assetTypes[i] == 1) {
                if (assetIds[i] != 0) revert AccountErrors.InvalidERC20Id();
                _depositERC20(from, assetAddresses[i], assetAmounts[i]);
            } else if (assetTypes[i] == 2) {
                if (assetAmounts[i] != 1) revert AccountErrors.InvalidERC721Amount();
                _depositERC721(from, assetAddresses[i], assetIds[i]);
            } else if (assetTypes[i] == 3) {
                _depositERC1155(from, assetAddresses[i], assetIds[i], assetAmounts[i]);
            } else {
                revert AccountErrors.UnknownAssetType();
            }
        }

        if (erc20Stored.length + erc721Stored.length + erc1155Stored.length > ASSET_LIMIT) {
            revert AccountErrors.TooManyAssets();
        }

        // If no Creditor is set, batchProcessDeposit only checks if the assets can be priced.
        // If a Creditor is set, batchProcessDeposit will also update the exposures of assets and underlying assets for the Creditor.
        IRegistry(registry).batchProcessDeposit(creditor, assetAddresses, assetIds, assetAmounts);
    }

    /**
     * @notice Withdraws assets from the Account to the owner.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @param to The address to withdraw to.
     * @dev (batch)ProcessWithdrawal handles the accounting of assets in the Registry.
     */
    function _withdraw(
        address[] memory assetAddresses,
        uint256[] memory assetIds,
        uint256[] memory assetAmounts,
        address to
    ) internal {
        // Process assets before transferring them out of the Account.
        // If a Creditor is set, batchProcessWithdrawal will also update the exposures of assets and underlying assets for the Creditor.
        uint256[] memory assetTypes =
            IRegistry(registry).batchProcessWithdrawal(creditor, assetAddresses, assetIds, assetAmounts);

        for (uint256 i; i < assetAddresses.length; ++i) {
            // Skip if amount is 0 to prevent transferring 0 balances.
            if (assetAmounts[i] == 0) continue;

            if (assetTypes[i] == 1) {
                if (assetIds[i] != 0) revert AccountErrors.InvalidERC20Id();
                _withdrawERC20(to, assetAddresses[i], assetAmounts[i]);
            } else if (assetTypes[i] == 2) {
                if (assetAmounts[i] != 1) revert AccountErrors.InvalidERC721Amount();
                _withdrawERC721(to, assetAddresses[i], assetIds[i]);
            } else if (assetTypes[i] == 3) {
                _withdrawERC1155(to, assetAddresses[i], assetIds[i], assetAmounts[i]);
            } else {
                revert AccountErrors.UnknownAssetType();
            }
        }
    }

    /**
     * @notice Internal function to deposit ERC20 assets.
     * @param from Address the tokens should be transferred from. This address must have approved the Account.
     * @param ERC20Address The contract address of the asset.
     * @param amount The amount of ERC20 assets.
     * @dev Used for all asset type == 1.
     * @dev If the token has not yet been deposited, the ERC20 token address is stored.
     */
    function _depositERC20(address from, address ERC20Address, uint256 amount) internal {
        IERC20(ERC20Address).safeTransferFrom(from, address(this), amount);

        uint256 currentBalance = erc20Balances[ERC20Address];

        if (currentBalance == 0) {
            erc20Stored.push(ERC20Address);
        }

        unchecked {
            erc20Balances[ERC20Address] = currentBalance + amount;
        }
    }

    /**
     * @notice Internal function to deposit ERC721 tokens.
     * @param from Address the tokens should be transferred from. This address must have approved the Account.
     * @param ERC721Address The contract address of the asset.
     * @param id The ID of the ERC721 token.
     * @dev Used for all asset type == 2.
     * @dev After successful transfer, the function pushes the ERC721 address to the stored token and stored ID array.
     * This may cause duplicates in the ERC721 stored addresses array, but this is intended.
     */
    function _depositERC721(address from, address ERC721Address, uint256 id) internal {
        IERC721(ERC721Address).safeTransferFrom(from, address(this), id);

        erc721Stored.push(ERC721Address);
        erc721TokenIds.push(id);
    }

    /**
     * @notice Internal function to deposit ERC1155 tokens.
     * @param from The Address the tokens should be transferred from. This address must have approved the Account.
     * @param ERC1155Address The contract address of the asset.
     * @param id The ID of the ERC1155 tokens.
     * @param amount The amount of ERC1155 tokens.
     * @dev Used for all asset type == 3.
     * @dev After successful transfer, the function checks whether the combination of address & ID has already been stored.
     * If not, the function pushes the new address and ID to the stored arrays.
     * This may cause duplicates in the ERC1155 stored addresses array, this is intended.
     */
    function _depositERC1155(address from, address ERC1155Address, uint256 id, uint256 amount) internal {
        IERC1155(ERC1155Address).safeTransferFrom(from, address(this), id, amount, "");

        uint256 currentBalance = erc1155Balances[ERC1155Address][id];

        if (currentBalance == 0) {
            erc1155Stored.push(ERC1155Address);
            erc1155TokenIds.push(id);
        }

        unchecked {
            erc1155Balances[ERC1155Address][id] = currentBalance + amount;
        }
    }

    /**
     * @notice Internal function to withdraw ERC20 assets.
     * @param to Address the tokens should be sent to.
     * @param ERC20Address The contract address of the asset.
     * @param amount The amount of ERC20 assets.
     * @dev Used for all asset type == 1.
     * @dev The function checks whether the Account has any leftover balance of said asset.
     * If not, it will pop() the ERC20 asset address from the stored addresses array.
     * Note: this shifts the order of erc20Stored!
     * @dev This check is done using a loop:
     * gas usage of writing it in a mapping vs extra loops is in favor of extra loops in this case.
     */
    function _withdrawERC20(address to, address ERC20Address, uint256 amount) internal {
        erc20Balances[ERC20Address] -= amount;

        if (erc20Balances[ERC20Address] == 0) {
            uint256 erc20StoredLength = erc20Stored.length;

            if (erc20StoredLength == 1) {
                // There was only one ERC20 stored on the contract, safe to remove from array.
                erc20Stored.pop();
            } else {
                for (uint256 i; i < erc20StoredLength; ++i) {
                    if (erc20Stored[i] == ERC20Address) {
                        erc20Stored[i] = erc20Stored[erc20StoredLength - 1];
                        erc20Stored.pop();
                        break;
                    }
                }
            }
        }

        IERC20(ERC20Address).safeTransfer(to, amount);
    }

    /**
     * @notice Internal function to withdraw ERC721 tokens.
     * @param to Address the tokens should be sent to.
     * @param ERC721Address The contract address of the asset.
     * @param id The ID of the ERC721 token.
     * @dev Used for all asset type == 2.
     * @dev The function checks whether any other ERC721 is deposited in the Account.
     * If not, it pops the stored addresses and stored IDs (pop() of two arrays is 180 gas cheaper than deleting).
     * If there are, it loops through the stored arrays and searches the ID that's withdrawn,
     * then replaces it with the last index, followed by a pop().
     * @dev Sensitive to ReEntrance attacks! SafeTransferFrom therefore done at the end of the function.
     */
    function _withdrawERC721(address to, address ERC721Address, uint256 id) internal {
        uint256 tokenIdLength = erc721TokenIds.length;

        uint256 i;
        if (tokenIdLength == 1) {
            // There was only one ERC721 stored on the contract, safe to remove both lists.
            if (erc721TokenIds[0] != id || erc721Stored[0] != ERC721Address) revert AccountErrors.UnknownAsset();
            erc721TokenIds.pop();
            erc721Stored.pop();
        } else {
            for (; i < tokenIdLength; ++i) {
                if (erc721TokenIds[i] == id && erc721Stored[i] == ERC721Address) {
                    erc721TokenIds[i] = erc721TokenIds[tokenIdLength - 1];
                    erc721TokenIds.pop();
                    erc721Stored[i] = erc721Stored[tokenIdLength - 1];
                    erc721Stored.pop();
                    break;
                }
            }
            // For loop should break, otherwise we never went into the if-branch, meaning the token being withdrawn
            // is unknown and not properly deposited.
            // i + 1 is done after loop, so i reaches tokenIdLength.
            if (i == tokenIdLength) revert AccountErrors.UnknownAsset();
        }

        IERC721(ERC721Address).safeTransferFrom(address(this), to, id);
    }

    /**
     * @notice Internal function to withdraw ERC1155 tokens.
     * @param to Address the tokens should be sent to.
     * @param ERC1155Address The contract address of the asset.
     * @param id The ID of the ERC1155 tokens.
     * @param amount The amount of ERC1155 tokens.
     * @dev Used for all asset types = 3.
     * @dev After successful transfer, the function checks whether there is any balance left for that ERC1155.
     * If there is, it simply transfers the tokens.
     * If not, it checks whether it can pop() (used for gas savings vs delete) the stored arrays.
     * If there are still other ERC1155's on the contract, it looks for the ID and token address to be withdrawn
     * and then replaces it with the last index, followed by a pop().
     * @dev Sensitive to ReEntrance attacks! SafeTransferFrom therefore done at the end of the function.
     */
    function _withdrawERC1155(address to, address ERC1155Address, uint256 id, uint256 amount) internal {
        uint256 tokenIdLength = erc1155TokenIds.length;

        erc1155Balances[ERC1155Address][id] -= amount;

        if (erc1155Balances[ERC1155Address][id] == 0) {
            if (tokenIdLength == 1) {
                erc1155TokenIds.pop();
                erc1155Stored.pop();
            } else {
                for (uint256 i; i < tokenIdLength; ++i) {
                    if (erc1155TokenIds[i] == id) {
                        if (erc1155Stored[i] == ERC1155Address) {
                            erc1155TokenIds[i] = erc1155TokenIds[tokenIdLength - 1];
                            erc1155TokenIds.pop();
                            erc1155Stored[i] = erc1155Stored[tokenIdLength - 1];
                            erc1155Stored.pop();
                            break;
                        }
                    }
                }
            }
        }

        IERC1155(ERC1155Address).safeTransferFrom(address(this), to, id, amount, "");
    }

    /**
     * @notice Transfers assets directly from the owner to the actionTarget contract.
     * @param transferFromOwnerData A struct containing the info of all assets transferred from the owner that are not in this account.
     * @param to The address to withdraw to.
     */
    function _transferFromOwner(ActionData memory transferFromOwnerData, address to) internal {
        uint256 assetAddressesLength = transferFromOwnerData.assets.length;
        address owner_ = owner;
        for (uint256 i; i < assetAddressesLength; ++i) {
            if (transferFromOwnerData.assetAmounts[i] == 0) {
                // Skip if amount is 0 to prevent transferring 0 balances.
                continue;
            }

            if (transferFromOwnerData.assetTypes[i] == 1) {
                IERC20(transferFromOwnerData.assets[i]).safeTransferFrom(
                    owner_, to, transferFromOwnerData.assetAmounts[i]
                );
            } else if (transferFromOwnerData.assetTypes[i] == 2) {
                IERC721(transferFromOwnerData.assets[i]).safeTransferFrom(owner_, to, transferFromOwnerData.assetIds[i]);
            } else if (transferFromOwnerData.assetTypes[i] == 3) {
                IERC1155(transferFromOwnerData.assets[i]).safeTransferFrom(
                    owner_, to, transferFromOwnerData.assetIds[i], transferFromOwnerData.assetAmounts[i], ""
                );
            } else {
                revert AccountErrors.UnknownAssetType();
            }
        }
    }

    /**
     * @notice Transfers assets from the owner to the actionTarget contract via Permit2.
     * @param permit Data specifying the terms of the transfer.
     * @param signature The signature to verify.
     * @param to_ The address to withdraw to.
     */
    function _transferFromOwnerWithPermit(
        IPermit2.PermitBatchTransferFrom memory permit,
        bytes memory signature,
        address to_
    ) internal {
        uint256 tokenPermissionsLength = permit.permitted.length;
        IPermit2.SignatureTransferDetails[] memory transferDetails =
            new IPermit2.SignatureTransferDetails[](tokenPermissionsLength);

        for (uint256 i; i < tokenPermissionsLength; ++i) {
            transferDetails[i].to = to_;
            transferDetails[i].requestedAmount = permit.permitted[i].amount;
        }

        PERMIT2.permitTransferFrom(permit, transferDetails, owner, signature);
    }

    /* ///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Generates three arrays of all the stored assets in the Account.
     * @return assetAddresses Array of the contract addresses of the assets.
     * @return assetIds Array of the IDs of the assets.
     * @return assetAmounts Array with the amounts of the assets.
     * @dev Balances are stored on the contract to prevent working around the deposit limits.
     * @dev Loops through the stored asset addresses and fills the arrays.
     * @dev There is no importance of the order in the arrays, but all indexes of the arrays correspond to the same asset.
     */
    function generateAssetData()
        internal
        view
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        uint256 totalLength;
        unchecked {
            totalLength = erc20Stored.length + erc721Stored.length + erc1155Stored.length;
        } // Cannot realistically overflow.
        assetAddresses = new address[](totalLength);
        assetIds = new uint256[](totalLength);
        assetAmounts = new uint256[](totalLength);

        uint256 i;
        uint256 erc20StoredLength = erc20Stored.length;
        address cacheAddr;
        for (; i < erc20StoredLength; ++i) {
            cacheAddr = erc20Stored[i];
            assetAddresses[i] = cacheAddr;
            // Gas: no need to store 0, index will continue anyway.
            // assetIds[i] = 0;
            assetAmounts[i] = erc20Balances[cacheAddr];
        }

        uint256 j;
        uint256 erc721StoredLength = erc721Stored.length;
        for (; j < erc721StoredLength; ++j) {
            cacheAddr = erc721Stored[j];
            assetAddresses[i] = cacheAddr;
            assetIds[i] = erc721TokenIds[j];
            assetAmounts[i] = 1;
            unchecked {
                ++i;
            }
        }

        uint256 k;
        uint256 erc1155StoredLength = erc1155Stored.length;
        uint256 cacheId;
        for (; k < erc1155StoredLength; ++k) {
            cacheAddr = erc1155Stored[k];
            cacheId = erc1155TokenIds[k];
            assetAddresses[i] = cacheAddr;
            assetIds[i] = cacheId;
            assetAmounts[i] = erc1155Balances[cacheAddr][cacheId];
            unchecked {
                ++i;
            }
        }
    }

    /* 
    @notice Returns the onERC721Received selector.
    @dev Needed to receive ERC721 tokens.
    */
    function onERC721Received(address, address, uint256, bytes calldata) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /*
    @notice Returns the onERC1155Received selector.
    @dev Needed to receive ERC1155 tokens.
    */
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

}
