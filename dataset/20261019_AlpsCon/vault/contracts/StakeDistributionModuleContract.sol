//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "hardhat/console.sol";
import "./interfaces/IERC20.sol";
import "./math/SafeMath.sol";
import "./math/SafeERC20.sol";
import {AggregatorV3Interface} from "./interfaces/ChainLinkAggregatorV3Interface.sol";
import {IAITradeHubContract} from "./interfaces/IAITradeHubContract.sol";
import {IVaultContract} from "./interfaces/IVaultContract.sol";
import {IInnovatorHubContract} from "./interfaces/IInnovatorHubContract.sol";
import {ISwapContract} from "./interfaces/ISwapContract.sol";
import {ReentrancyGuard} from "./utils/ReentrancyGuard.sol";

contract StakeDistributionModuleContract is ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    error StakeDistributionModulePermissionDeniedError();
    error StakeDistributionModuleNoFeeForDistributionError();
    error StakeDistributionModuleTimeLockError();

    event StakeDistributionNewCollectFeeModuleEvent(address contractAddress);
    event StakeDistributionFeeDistributed(address indexed collectFeeContract, address indexed token, uint256 collectedFee, uint256 distributedAmount);

    uint256 public DISTRIBUTION_FEE_PERCENT_DECIMAL_PRECISION = 10 ** 2;
    uint256 public DISTRIBUTION_FEE_PERCENT = 20 * DISTRIBUTION_FEE_PERCENT_DECIMAL_PRECISION; //20%

    IVaultContract internal vaultContract;
    IInnovatorHubContract internal innovatorHubContract;
    ISwapContract internal swapContract;

    address internal owner;
    address internal distributionToken;
    mapping(address => mapping(address => uint256)) internal lastCollectedFees;
    address[] internal collectFeeContracts;
    uint256 internal lastDistribution;
    uint256 internal distributionInterval;

    modifier onlyOwner()  {
        if (msg.sender != owner) revert StakeDistributionModulePermissionDeniedError();
        _;
    }

    constructor(address _vaultContractAddress, address _innovatorHubAddress, address _swapContractAddress, address _distributionTokenAddress, address[] memory _collectFeeContracts){
        owner = msg.sender;
        vaultContract = IVaultContract(_vaultContractAddress);
        innovatorHubContract = IInnovatorHubContract(_innovatorHubAddress);
        swapContract = ISwapContract(_swapContractAddress);
        distributionToken = _distributionTokenAddress;
        collectFeeContracts = _collectFeeContracts;
        distributionInterval = 1 hours;
        distribute();
    }

    function distribute() public nonReentrant {
        if (lastDistribution + distributionInterval < block.timestamp) revert StakeDistributionModuleTimeLockError();
        lastDistribution = block.timestamp;
        address[] memory distributionTokens = swapContract.supportTokens();
        for (uint contractIndex; contractIndex < collectFeeContracts.length; contractIndex++) {
            address collectFeeContract = collectFeeContracts[contractIndex];
            for (uint8 i = 0; i < distributionTokens.length; i++) {
                address token = distributionTokens[i];
                _distributeToken(collectFeeContract, token);
            }
        }
    }

    function _distributeToken(address collectFeeContract, address token) internal {
        uint256 lastCollectedFee = lastCollectedFees[collectFeeContract][token];
        (,
            ,
            uint256 total_fee,
            ,
            ,
            ,
            ) = vaultContract.getStats(collectFeeContract, token);
        if (lastCollectedFee == 0) {
            lastCollectedFees[collectFeeContract][token] = total_fee;
            return;
        }
        if (lastCollectedFee >= total_fee) return;
        uint256 collectedFee = total_fee - lastCollectedFee;
        //Get swap rate SOURCE token -> ALPS
        if (token != distributionToken)
            collectedFee = swapContract.estimateSwapAmount(token, distributionToken, collectedFee);
        lastCollectedFees[collectFeeContract][token] = total_fee;
        //Take distribution percent
        uint256 distributionAmt = (collectedFee * DISTRIBUTION_FEE_PERCENT) / (100 * DISTRIBUTION_FEE_PERCENT_DECIMAL_PRECISION);
        //Withdraw from Vault
        vaultContract.moduleWithdrawToken(address(distributionToken), address(this), distributionAmt);
        //Distribute
        IERC20(distributionToken).approve(address(innovatorHubContract), distributionAmt);
        innovatorHubContract.distributeStakingRewards(distributionAmt);
        emit StakeDistributionFeeDistributed(collectFeeContract, token, collectedFee, distributionAmt);
    }

    function addFeeCollectContract(address contractAddress) external onlyOwner {
        collectFeeContracts.push(contractAddress);
        emit StakeDistributionNewCollectFeeModuleEvent(contractAddress);
    }


}