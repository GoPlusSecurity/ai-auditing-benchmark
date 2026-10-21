// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.20;

import "../loans/IMultiSourceLoan.sol";
import "../../interfaces/external/IReservoir.sol";

import "@solmate/tokens/ERC20.sol";
import "@solmate/tokens/ERC721.sol";
import {IPool} from "@aave/interfaces/IPool.sol";

interface IPurchaseBundler {
    /* @dev
        * reservoirExecutionInfo: info to execute the reservoir order
        * contractMustBeOwner: whether the contract must be the owner of the NFT to proceed with the execution
        * purchaseCurrency: currency used to buy/sell the NFT
        * amount: borrowed amount to swap or get from swap.
        *           - In bnpl, is how much we take from buyer as initial payment.
        *           - In s&r, is how much amount is set as input for the quoter.
        * swapData: abi.encode(address quoter, bytes quoterArgs) - quoter must be whitelisted
        * swapValue: value to send along with the swap call
        * maxSlippage: maximum slippage allowed for the swap
        */
    struct ExecutionInfo {
        IReservoir.ExecutionInfo reservoirExecutionInfo;
        bool contractMustBeOwner;
        address purchaseCurrency;
        uint256 amount;
        bytes swapData;
        uint256 swapValue;
        uint256 maxSlippage;
    }

    struct Taxes {
        uint128 buyTax;
        uint128 sellTax;
    }

    struct AaveBorrowArgs {
        IPool pool;
        address[] assets;
        uint256[] amounts;
    }

    struct ExecuteSellArgs {
        address[] currencies;
        uint256[] currencyAmounts;
        ERC721[] collections;
        uint256[] tokenIds;
        address marketPlace;
        bytes[] executionData;
        bytes[] swapData;
    }

    /* @dev
        * borrowArgs: Aave flash loan parameters (pool, assets, amounts)
        * executeSellArgs: Arguments for executing the NFT sale
        * loanExecutionData: Encoded repayLoan(IMultiSourceLoan.LoanRepaymentData)[] data
        * swapCurrencies: ERC20 tokens to swap to repay the Aave loan
        * swapAmounts: Amounts of each currency to swap
        * swapData: Encoded swap data for each currency swap
        * unwrap: Whether to unwrap aave borrowed WETH (aave doesn't lend ETH directly)
        */
    struct ExecuteSellWithLoanArgs {
        AaveBorrowArgs borrowArgs;
        ExecuteSellArgs executeSellArgs;
        bytes[] loanExecutionData;
        ERC20[] swapCurrencies;
        uint160[] swapAmounts;
        bytes[] swapData;
        bool unwrap;
    }

    struct SwapAndExecuteParams {
        address[] inputCurrencies;
        address[] outputCurrencies;
        uint256[] amountsToSwap;
        bytes swapData;
        address target;
        bytes executionCalldata;
        uint256 executionValue;
    }

    /// @notice Buy a number of NFTs using loans to cover part of the price (i.e. BNPL).
    /// @dev Buy calls emit loan -> Before trying to transfer the NFT but after transfering the principal
    /// @dev Encoded: emitLoan(IMultiSourceLoan.LoanExecutionData)[]
    /// @param executionData The data needed to execute the loan + buy the NFT.
    function buy(bytes[] calldata executionData) external payable returns (uint256[] memory);

    /// @notice Sell the collateral behind a number of loans (potentially 1) and use proceeds to pay back the loans.
    /// @dev Encoded: repayLoan(IMultiSourceLoan.LoanRepaymentData)[]
    /// @param executionData The data needed to execute the loan repayment + sell the NFT.
    /// @param swapData The data needed to execute the swap.
    function sell(bytes[] calldata executionData, bytes[] calldata swapData) external;

    /// @notice Execute a sell signed by the borrower.
    /// @dev Encoded: repayLoan(IMultiSourceLoan.LoanRepaymentData)[]
    /// @param currencies The currencies to send.
    /// @param currencyAmounts The amounts of each currency to send.
    /// @param collections The collections of the NFTs to receive.
    /// @param tokenIds The token IDs of the NFTs to receive.
    /// @param executionData The data needed to execute the loan repayment + sell the NFT.
    /// @param swapData The data needed to execute the swap.
    function executeSell(
        address[] calldata currencies,
        uint256[] calldata currencyAmounts,
        ERC721[] calldata collections,
        uint256[] calldata tokenIds,
        address marketPlace,
        bytes[] calldata executionData,
        bytes[] calldata swapData
    ) external payable;

    function executeSellWithLoan(ExecuteSellWithLoanArgs calldata args) external payable;

    /// @notice Returns the address of the MultiSourceLoan.
    function getMultiSourceLoanAddress() external view returns (address);

    /// @notice Returns the taxes for a specific module.
    /// @param module The module address to query.
    /// @return The taxes for the module.
    function getTaxes(address module) external view returns (Taxes memory);

    /// @notice Returns the pending taxes for a specific module.
    /// @param module The module address to query.
    /// @return pendingTax The pending tax values.
    function getPendingTaxes(address module) external view returns (Taxes memory);

    /// @notice Returns the pending taxes for a specific module.
    /// @param module The module address to query.
    /// @return setTime The time when the pending taxes were set.
    function getPendingTaxesSetTime(address module) external view returns (uint256);

    /// @notice Kicks off the process to update the taxes for a specific module.
    /// @param module The module address to set the tax for.
    /// @param newTaxes New taxes.
    function updateTaxes(address module, Taxes calldata newTaxes) external;

    /// @notice Set the taxes for a module if enough notice has been given.
    /// @param module The module address to finalize the tax for.
    function setTaxes(address module) external;

    /// @notice Collect multiple currencies, perform swaps, and execute calldata on a whitelisted target
    /// @dev The target contract must be this contract (PurchaseBundler) or a whitelisted marketplace
    /// @param args SwapAndExecuteParams struct containing all swap and execution parameters
    function swapAndExecute(SwapAndExecuteParams calldata args) external payable;
}
