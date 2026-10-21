// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./IERC20.sol";
import "./Ownable.sol";
import "./ReentrancyGuard.sol";
import "./INodeNFT.sol";
import "./TokenDistributor.sol";
import "./IXPL.sol";
import "./ITimeHelper.sol";

contract NodeDistributePlus is Ownable, ReentrancyGuard {
    INodeNFT public nodeNFTContract;
    modifier onlyDev() {
        require(_msgSender() == owner() || _msgSender() == devAddress, "t000");
        _;
    }
    struct ShareInfo {
        uint256 index;
        uint256 ShareAmount;
        uint256 totalNode;
        uint256 perShare;
        uint256 shareTime;
    }
    bool public initialized;
    bool public paused;
    address public devAddress;
    address public usdtAddress;
    address public xplAddress;
    uint256 public startTime = 0;
    uint256 public endTime = 0;

    uint256 public minShareAmount;
    uint256 public maxShareAmount;
    uint256 public minNodeAmount;
    uint256 public distributeInterval;

    uint256 public constant BASE_POINT = 100;
    uint256 public distributeRate;

    address public tokenDistributorForUSDT;
    address public tokenDistributorForXPL;

    mapping(uint256 _nodeType => uint256 _totalClaimAmount)
        public tokenTotalClaimAmount;
    mapping(uint256 _nodeType => uint256 _totalShareAmount)
        public tokenTotalShareAmount;
    mapping(uint256 _nodeType => uint256 _lastDistributeTime)
        public tokenLastDistributeTime;
    mapping(uint256 _nodeType => uint256 _shareIndex) public tokenShareIndex;

    mapping(address _user => bool _isWhiteList) public whiteList;
    mapping(uint256 _nodeType => mapping(uint256 _index => ShareInfo _shareInfo))
        public tokenShareInfo;
    mapping(uint256 _nodeType => mapping(uint256 _tokenId => uint256 _claimAmount))
        public tokenUserClaimAmountList;
    mapping(uint256 _nodeType => mapping(uint256 _tokenId => uint256 _lastClaimIndex))
        public tokenLastClaimIndexList;
    mapping(uint256 _nodeType => mapping(uint256 _index => uint256 _accPerShare))
        public tokenAccPerShare;

    mapping(address _user => uint256 _claimedUsdtAmount)
        public userClaimedUsdtAmount;
    mapping(address _user => uint256 _claimedXplAmount)
        public userClaimedXplAmount;
    address public timeHelperContract;
    //创建销毁的时间
    mapping(string => uint256) public dayBurnTaskTimeList;
    //每日需要销毁总量
    mapping(string => uint256) public daytotalNeedBurnList;
    //每日销毁总量最后更新时间
    mapping(string => uint256) public dayLastBurnTimeList;
    //每日已销毁总量
    mapping(string => uint256) public dayTotalBurnedList;

    event ShareDistributed(
        uint256 nodeType,
        address user,
        uint256 index,
        uint256 ShareAmount,
        uint256 totalNode,
        uint256 perShare,
        uint256 timestamp
    );

    event ClaimReward(
        uint256 nodeType,
        uint256 tokenId,
        uint256 lastClaimIndex,
        uint256 currentShareIndex,
        uint256 pendingAmount,
        uint256 timestamp
    );

    constructor(address initialOwner) Ownable(initialOwner) {}

    function initialize(
        address _devAddress,
        address _usdtAddress,
        address _xplAddress,
        address _nodeNFTContract
    ) external {
        require(!initialized, "t001");
        require(
            _usdtAddress != address(0) &&
                _xplAddress != address(0) &&
                _nodeNFTContract != address(0),
            "t002"
        );
        initialized = true;
        devAddress = _devAddress;
        usdtAddress = _usdtAddress;
        xplAddress = _xplAddress;
        nodeNFTContract = INodeNFT(_nodeNFTContract);
        tokenDistributorForUSDT = address(new TokenDistributor(_usdtAddress));
        tokenDistributorForXPL = address(new TokenDistributor(_xplAddress));
        tokenShareIndex[uint256(NodeType.USDT)] = 1;
        tokenShareIndex[uint256(NodeType.XPL)] = 1;

        startTime = block.timestamp;
        endTime = block.timestamp + 365 days;
        minShareAmount = 1 * 10 ** 18;
        maxShareAmount = 100 * 10 ** 18;
        minNodeAmount = 5;
        distributeInterval = 1 minutes;
        distributeRate = 50;
        _transferOwnership(msg.sender);
    }

    function setNodeNFTContract(address _nodeNFTContract) external onlyDev {
        nodeNFTContract = INodeNFT(_nodeNFTContract);
    }

    function setDistributeRate(uint256 _distributeRate) external onlyDev {
        // require(_distributeRate > 0 && _distributeRate <= 50, "t002");
        distributeRate = _distributeRate;
    }

    function setMinShareAmount(uint256 _minShareAmount) external onlyDev {
        minShareAmount = _minShareAmount;
    }

    function setMaxShareAmount(uint256 _maxShareAmount) external onlyDev {
        maxShareAmount = _maxShareAmount;
    }

    function setMinNodeAmount(uint256 _minNodeAmount) external onlyDev {
        minNodeAmount = _minNodeAmount;
    }

    function setTimeHelperContract(
        address _timeHelperContract
    ) external onlyDev {
        timeHelperContract = _timeHelperContract;
    }

    function setDayTotalNeedBurn(uint256 _totalNeedBurn) external onlyDev {
        (, , , , string memory date, ) = TimeHelper(timeHelperContract)
            .getYearMonthDay(block.timestamp, 0);
        require(daytotalNeedBurnList[date] == 0, "t003");
        daytotalNeedBurnList[date] = _totalNeedBurn;
        dayBurnTaskTimeList[date] = block.timestamp;
    }

    function DynamicBurnPool(
        string memory date,
        uint256 _amount
    ) external nonReentrant {
        require(_amount > 0, "k001");
        require(daytotalNeedBurnList[date] > 0, "k002");
        // require(block.timestamp >= dayLastBurnTimeList[date] + 1 hours, "k003");
        require(block.timestamp <= dayBurnTaskTimeList[date] + 2 days, "k004");
        require(
            dayTotalBurnedList[date] + _amount <= daytotalNeedBurnList[date],
            "k005"
        );
        dayTotalBurnedList[date] += _amount;
        dayLastBurnTimeList[date] = block.timestamp;
        IXPL(xplAddress).DynamicBurnPool(_amount);
    }

    function setTimeLine(
        uint256 _startTime,
        uint256 _endTime
    ) external onlyDev {
        startTime = _startTime;
        endTime = _endTime;
    }

    function setDevAddress(address _devAddress) external onlyDev {
        devAddress = _devAddress;
    }

    function setDistributeInterval(
        uint256 _distributeInterval
    ) external onlyDev {
        distributeInterval = _distributeInterval;
    }

    function setWhiteList(address user_, bool isWhiteList_) external onlyDev {
        whiteList[user_] = isWhiteList_;
    }

    function setPaused(bool _paused) external onlyDev {
        paused = _paused;
    }

    event T(uint256 _nodeType, uint256 _time, string _msg);

    function _distributeShare(uint256 _nodeType) private {
        address tokenDistributor = _nodeType == 0
            ? tokenDistributorForUSDT
            : tokenDistributorForXPL;
        if (paused) {
            emit T(_nodeType, block.timestamp, "paused");
            return;
        }
        uint256 time = block.timestamp;
        if (
            tokenLastDistributeTime[_nodeType] > 0 &&
            time < tokenLastDistributeTime[_nodeType] + distributeInterval
        ) {
            emit T(
                _nodeType,
                block.timestamp,
                "time < tokenLastDistributeTime[_nodeType] + distributeInterval"
            );
            return;
        }
        address user = _msgSender();
        if (!initialized) {
            emit T(_nodeType, block.timestamp, "!initialized");
            return;
        }
        if (time < startTime || time > endTime) {
            emit T(
                _nodeType,
                block.timestamp,
                "time < startTime || time > endTime"
            );
            return;
        }
        if (address(nodeNFTContract) == address(0)) {
            emit T(
                _nodeType,
                block.timestamp,
                "address(nodeNFTContract) == address(0)"
            );
            return;
        }
        uint256 unClaimAmount = tokenTotalShareAmount[_nodeType] -
            tokenTotalClaimAmount[_nodeType];
        uint256 balance = _nodeType == 0
            ? IERC20(usdtAddress).balanceOf(tokenDistributor)
            : IERC20(xplAddress).balanceOf(tokenDistributor);
        if (balance < unClaimAmount + minShareAmount) {
            emit T(
                _nodeType,
                block.timestamp,
                "balance < unClaimAmount + minShareAmount"
            );
            return;
        }
        uint256 toDistributeAmount = ((balance - unClaimAmount) *
            distributeRate) / BASE_POINT;

        if (toDistributeAmount > maxShareAmount) {
            toDistributeAmount = maxShareAmount;
        }

        uint256 totalNode = nodeNFTContract.getAllPower();
        if (totalNode < minNodeAmount) {
            emit T(_nodeType, block.timestamp, "totalNode < minNodeAmount");
            return;
        }
        uint256 perShare = toDistributeAmount / totalNode;
        uint256 currentIndex = tokenShareIndex[_nodeType];
        uint256 lastIndex = currentIndex > 0 ? currentIndex - 1 : 0;
        tokenAccPerShare[_nodeType][currentIndex] =
            tokenAccPerShare[_nodeType][lastIndex] +
            perShare;
        tokenShareInfo[_nodeType][tokenShareIndex[_nodeType]] = ShareInfo({
            index: tokenShareIndex[_nodeType],
            ShareAmount: toDistributeAmount,
            totalNode: totalNode,
            perShare: perShare,
            shareTime: time
        });
        emit ShareDistributed(
            _nodeType,
            user,
            tokenShareIndex[_nodeType],
            toDistributeAmount,
            totalNode,
            perShare,
            time
        );
        tokenShareIndex[_nodeType]++;
        tokenTotalShareAmount[_nodeType] += toDistributeAmount;
        tokenLastDistributeTime[_nodeType] = time;
    }

    function distributeShare(uint256 _nodeType) external nonReentrant {
        _distributeShare(_nodeType);
    }

    function distributeAllShare() external nonReentrant {
        _distributeShare(uint256(NodeType.USDT));
        _distributeShare(uint256(NodeType.XPL));
    }

    function claimReward(uint256 _tokenId, uint256 _nodeType) public {
        uint256 pendingAmount = pendingReward(_tokenId, _nodeType);
        if (pendingAmount == 0) {
            return;
        }
        address tokenDistributor = _nodeType == 0
            ? tokenDistributorForUSDT
            : tokenDistributorForXPL;
        uint256 lastClaimIndex = tokenLastClaimIndexList[_nodeType][_tokenId];
        uint256 balance = _nodeType == 0
            ? IERC20(usdtAddress).balanceOf(tokenDistributor)
            : IERC20(xplAddress).balanceOf(tokenDistributor);
        if (balance < pendingAmount) {
            return;
        }
        tokenTotalClaimAmount[_nodeType] += pendingAmount;
        uint256 currentShareIndex = tokenShareIndex[_nodeType] - 1;
        tokenLastClaimIndexList[_nodeType][_tokenId] = currentShareIndex;
        tokenUserClaimAmountList[_nodeType][_tokenId] += pendingAmount;

        address owner = nodeNFTContract.ownerOf(_tokenId);
        if (owner == address(0)) {
            return;
        }
        emit ClaimReward(
            _nodeType,
            _tokenId,
            lastClaimIndex,
            currentShareIndex,
            pendingAmount,
            block.timestamp
        );
        address _to_address = owner;
        IERC20(_nodeType == 0 ? usdtAddress : xplAddress).transferFrom(
            tokenDistributor,
            _to_address,
            pendingAmount
        );
        if (_nodeType == 0) {
            userClaimedUsdtAmount[_to_address] += pendingAmount;
        } else {
            userClaimedXplAmount[_to_address] += pendingAmount;
        }
    }

    function pendingReward(
        uint256 _tokenId,
        uint256 _nodeType
    ) public view returns (uint256) {
        address owner = nodeNFTContract.ownerOf(_tokenId);
        if (owner == address(0)) {
            return 0;
        }
        NftData memory nftData = nodeNFTContract.nftDataList(_tokenId);
        if (nftData.isActive == false || nftData.purchaseTime == 0) {
            return 0;
        }
        if (!nodeNFTContract.isActiveNode(_tokenId)) {
            return 0;
        }
        uint256 lastClaimIndex = tokenLastClaimIndexList[_nodeType][_tokenId];
        uint256 startIndex = 0;
        uint256 shareIndex = tokenShareIndex[_nodeType];
        if (lastClaimIndex == 0) {
            for (uint256 i = 1; i < shareIndex; i++) {
                if (
                    tokenShareInfo[_nodeType][i].shareTime >
                    nftData.purchaseTime
                ) {
                    startIndex = i;
                    break;
                }
            }
        } else {
            startIndex = lastClaimIndex + 1;
        }
        if (startIndex == 0 || startIndex >= shareIndex) {
            return 0;
        }
        uint256 totalAmount = (tokenAccPerShare[_nodeType][shareIndex - 1] -
            tokenAccPerShare[_nodeType][startIndex - 1]) * nftData.rate;
        return totalAmount;
    }

    struct NftData2 {
        uint256 tokenId;
        NftType nftType;
        uint256 rate;
        address owner;
        uint256 purchaseTime;
        bool isActive;
        bool isActiveNode;
    }

    function getALlPendingReward(
        address _owner
    )
        public
        view
        returns (
            uint256 _usdtAmount,
            uint256 _xplAmount,
            uint256 _claimedUsdtAmount,
            uint256 _claimedXplAmount,
            NftData2[] memory _nftDataList
        )
    {
        _claimedUsdtAmount = userClaimedUsdtAmount[_owner];
        _claimedXplAmount = userClaimedXplAmount[_owner];
        uint256 _num = nodeNFTContract.balanceOf(_owner);
        _nftDataList = new NftData2[](_num);
        for (uint256 i = 0; i < _num; i++) {
            uint256 _tokenId = nodeNFTContract.tokenOfOwnerByIndex(_owner, i);
            _usdtAmount += pendingReward(_tokenId, uint256(NodeType.USDT));
            _xplAmount += pendingReward(_tokenId, uint256(NodeType.XPL));
            NftData memory nftData = nodeNFTContract.nftDataList(_tokenId);
            _nftDataList[i] = NftData2({
                tokenId: _tokenId,
                nftType: nftData.nftType,
                rate: nftData.rate,
                owner: nftData.owner,
                purchaseTime: nftData.purchaseTime,
                isActive: nftData.isActive,
                isActiveNode: nodeNFTContract.isActiveNode(_tokenId)
            });
        }
    }

    function claimAllReward(address _owner) external {
        uint256 _num = nodeNFTContract.balanceOf(_owner);
        for (uint256 i = 0; i < _num; i++) {
            uint256 _tokenId = nodeNFTContract.tokenOfOwnerByIndex(_owner, i);
            uint256 _usdtAmount = pendingReward(
                _tokenId,
                uint256(NodeType.USDT)
            );
            if (_usdtAmount > 0) {
                claimReward(_tokenId, uint256(NodeType.USDT));
            }
            uint256 _xplAmount = pendingReward(_tokenId, uint256(NodeType.XPL));
            if (_xplAmount > 0) {
                claimReward(_tokenId, uint256(NodeType.XPL));
            }
        }
    }
}
