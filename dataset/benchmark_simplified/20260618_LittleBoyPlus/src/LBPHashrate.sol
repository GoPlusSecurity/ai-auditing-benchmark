// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {IPancakePair} from "./interfaces/IPancakePair.sol";

import {PowMath} from "./libs/PowMath.sol";

import {HashrateRegistry} from "./HashrateRegistry.sol";

interface ILBP {
    function mintReward(address to, uint256 amount) external;

    function lastTransfer() external view returns (address);
}

contract LBPHashrate is ERC20, ReentrancyGuardTransient {
    uint256 private constant REF_REWARD_USDT = 199 * 1e17;

    uint256 private constant VALID_INVITE_USDT = 199 * 1e18;

    uint256 private constant NODE_LP_USDT = 995 * 1e18;

    uint256 private constant NODE_PERF_USDT = 2_985 * 1e18;

    uint256 public constant REFCODE_AMOUNT = 11 * 10 ** 14;

    uint256 private constant DYNAMIC_POOL_BPS = 8_000;

    uint256 private constant RATIOS_PACKED = (uint256(2_500) << 0) | (uint256(625) << 12)
        | (uint256(625) << 24) | (uint256(625) << 36) | (uint256(625) << 48) | (uint256(625) << 60)
        | (uint256(625) << 72) | (uint256(625) << 84) | (uint256(625) << 96) | (uint256(625) << 108)
        | (uint256(375) << 120) | (uint256(375) << 132) | (uint256(375) << 144) | (uint256(375) << 156)
        | (uint256(375) << 168);

    uint256 private constant THRESHOLDS_PACKED = (uint256(1) << 0) | (uint256(1) << 4)
        | (uint256(2) << 8) | (uint256(2) << 12) | (uint256(3) << 16) | (uint256(3) << 20)
        | (uint256(4) << 24) | (uint256(4) << 28) | (uint256(5) << 32) | (uint256(5) << 36)
        | (uint256(6) << 40) | (uint256(6) << 44) | (uint256(7) << 48) | (uint256(7) << 52)
        | (uint256(7) << 56);

    address private constant DEAD = 0x000000000000000000000000000000000000dEaD;

    uint256 private constant D0 = 41_958 * 1e18;

    uint256 private constant EMIT_STATIC_PCT = 50;

    uint256 private constant EMIT_NODE_PCT = 10;

    ILBP public immutable lbp;

    IPancakePair public immutable pair;

    address public immutable refVault;

    mapping(address => uint256) public registeredLp;

    bool public tradingOpened;

    uint64 public openTime;

    uint64 internal lastEmissionUpdate;

    uint112 internal lastTickRLbp;

    uint256 public staticAccPerShare;

    uint256 public nodeAccPerShare;

    mapping(address => uint256) internal userIndex;

    mapping(address => uint256) internal userNodeIndex;

    mapping(address => bool) public isNode;

    uint256 public totalNodeCount;

    mapping(address => address) public referrer;

    mapping(address => uint256) public sharedHashrate;

    mapping(address => uint256) public validDownlines;

    mapping(address => bool) internal rewardTriggered;

    uint256 public accountedEmission;

    error ZeroAddress();

    error OnlyLBP();

    error InvalidBind();

    error SharedHashrateUnderflow();

    error InsufficientRegisteredLp();

    error TransferBelowValidFloor();

    event HashrateCredited(address indexed user, uint256 lpDelta, uint256 hashrate);

    event HashrateDebited(address indexed user, uint256 lpRemoved, uint256 hashrate);

    event StaticReward(address indexed user, uint256 amount);

    event NodeReward(address indexed user, uint256 amount);

    event DynamicReward(
        address indexed recipient, address indexed origin, uint8 generation, uint256 amount
    );

    event HierarchyBurn(address indexed recipient, uint256 amount);

    event NodeAdded(address indexed user);

    event NodeRemoved(address indexed user);

    event ReferrerBound(address indexed downline, address indexed referrer);

    event ReceiverInitialized(address indexed receiver);

    modifier onlyLBP() {
        if (msg.sender != address(lbp)) revert OnlyLBP();
        _;
    }

    constructor(
        HashrateRegistry registry,
        address receiver,
        address[] memory migUsers,
        address[] memory migUplines
    ) ERC20("LBP Hashrate", "hLBP") {
        address _lbp = registry.lbp();
        address _pair = registry.pair();
        address _refVault = registry.refVault();
        if (_lbp == address(0) || _pair == address(0) || _refVault == address(0)) {
            revert ZeroAddress();
        }
        if (receiver == address(0) || receiver == DEAD) revert ZeroAddress();
        lbp = ILBP(_lbp);
        pair = IPancakePair(_pair);
        refVault = _refVault;

        referrer[receiver] = receiver;
        emit ReceiverInitialized(receiver);
        emit ReferrerBound(receiver, receiver);

        if (migUsers.length != migUplines.length) revert ZeroAddress();
        uint256 len = migUsers.length;
        for (uint256 i; i < len; ) {
            address u = migUsers[i];
            address r = migUplines[i];

            if (u != address(0) && r != address(0) && u != r && u != DEAD && r != DEAD && referrer[u] == address(0)) {
                referrer[u] = r;
                emit ReferrerBound(u, r);
            }
            unchecked { ++i; }
        }
    }

    function notifyCredit(
        address user,
        uint256 lpDelta,
        uint256 currentRUsdt,
        uint256 currentTotalLp
    ) external onlyLBP nonReentrant returns (address refToReward, uint256 hashrateUsed) {
        if (user == address(0) || lpDelta == 0 || user == DEAD) return (address(0), 0);
        if (currentTotalLp == 0) return (address(0), 0);

        uint256 hashAmount = 2 * lpDelta * currentRUsdt / currentTotalLp;

        unchecked {
            registeredLp[user] += lpDelta;
        }

        if (hashAmount == 0) {

            emit HashrateCredited(user, lpDelta, 0);
            return (address(0), 0);
        }

        _mint(user, hashAmount);

        emit HashrateCredited(user, lpDelta, hashAmount);

        if (hashAmount >= REF_REWARD_USDT) {
            address ref = referrer[user];
            if (ref != address(0) && ref != DEAD && !rewardTriggered[user]) {
                rewardTriggered[user] = true;
                return (ref, hashAmount);
            }
        }

        return (address(0), 0);
    }

    function notifyDebit(address user, uint256 lpRemoved) external onlyLBP nonReentrant {
        if (user == address(0) || lpRemoved == 0) return;

        uint256 registered = registeredLp[user];
        if (registered < lpRemoved) revert InsufficientRegisteredLp();

        uint256 bal = balanceOf(user);
        uint256 hashAmount = (lpRemoved == registered) ? bal : (bal * lpRemoved) / registered;

        unchecked {
            registeredLp[user] = registered - lpRemoved;
        }

        if (hashAmount > 0) _burn(user, hashAmount);

        emit HashrateDebited(user, lpRemoved, hashAmount);
    }

    function notifyTradingOpened(uint64 _openTime) external onlyLBP {
        if (tradingOpened) return;
        tradingOpened = true;
        openTime = _openTime;
        lastEmissionUpdate = _openTime;

        (, uint112 r1, ) = pair.getReserves();
        lastTickRLbp = r1;
    }

    function notifyHarvest(address user) external onlyLBP nonReentrant {
        _harvest(user);
    }

    function notifyMagicBind(address from, address to) external onlyLBP nonReentrant returns (bool) {
        return _tryBindReferral(from, to);
    }

    function pendingRewards(address user) external view returns (uint256 total) {
        if (user == DEAD || user == address(0)) return 0;

        uint256 hash = balanceOf(user);
        bool node = isNode[user];
        if (hash == 0 && !node) return 0;

        (uint256 liveStatic, uint256 liveNode,, ) = _previewAccumulators();

        if (hash > 0) {
            uint256 idx = userIndex[user];
            if (liveStatic > idx) {
                total = (hash * (liveStatic - idx)) / 1e18;
            }
        }

        if (node) {
            uint256 nIdx = userNodeIndex[user];
            if (liveNode > nIdx) {
                total += (liveNode - nIdx) / 1e18;
            }
        }
    }

    function _update(address from, address to, uint256 value) internal override {

        uint256 fromBal = from == address(0) ? 0 : balanceOf(from);

        if (
            from != address(0) && to != address(0) && from != DEAD && to != DEAD
                && from != to
        ) {
            if (fromBal >= VALID_INVITE_USDT && fromBal - value < VALID_INVITE_USDT) {
                revert TransferBelowValidFloor();
            }
        }

        if (from != address(0)) {
            if (from != DEAD) _harvest(from);
            if (to != address(0) && to != DEAD && to != from) _harvest(to);
        }

        if (
            from != address(0) && to != address(0) && msg.sender == from
                && (value == REFCODE_AMOUNT || value == 0)
        ) {
            _tryBindReferral(from, to);
        }

        if (
            value > 0 && from != address(0) && to != address(0) && from != to
                && from != DEAD && to != DEAD
        ) {
            if (fromBal > 0) {
                uint256 fromLedger = registeredLp[from];
                uint256 lpProp = (fromLedger * value) / fromBal;

                if (lpProp == 0 && fromLedger > 0) lpProp = 1;
                if (lpProp > fromLedger) lpProp = fromLedger;
                if (lpProp > 0) {
                    unchecked {
                        registeredLp[from] = fromLedger - lpProp;
                        registeredLp[to] += lpProp;
                    }
                }
            }
        }

        super._update(from, to, value);

        if (from != address(0) && from != DEAD) {
            _propagateDown(from, value);
            _updateNodeStatus(from);
        }
        if (to != address(0) && to != DEAD) {
            _propagateUp(to, value);
            _updateNodeStatus(to);
        }
    }

    function _harvest(address user) internal {
        if (user == DEAD) return;
        _tickEmission();

        uint256 hash = balanceOf(user);
        uint256 accStatic = staticAccPerShare;

        if (hash > 0) {
            uint256 delta = accStatic - userIndex[user];
            if (delta > 0) {
                uint256 staticReward = (hash * delta) / 1e18;
                if (staticReward > 0) {
                    lbp.mintReward(user, staticReward);
                    emit StaticReward(user, staticReward);
                    _distributeDynamic(user, staticReward);
                }
                userIndex[user] = accStatic;
            }
        } else {

            userIndex[user] = accStatic;
        }

        if (isNode[user]) {
            uint256 accNode = nodeAccPerShare;
            uint256 nodeDelta = accNode - userNodeIndex[user];
            if (nodeDelta > 0) {
                uint256 nodeReward = nodeDelta / 1e18;
                if (nodeReward > 0) {
                    lbp.mintReward(user, nodeReward);
                    emit NodeReward(user, nodeReward);
                }
                userNodeIndex[user] = accNode;
            }
        }
    }

    function _distributeDynamic(address originUser, uint256 staticAmount) internal {
        uint256 dynamicPool = (staticAmount * DYNAMIC_POOL_BPS) / 10_000;
        if (dynamicPool == 0) return;

        address current = referrer[originUser];
        uint256 hierarchyShare;
        uint256 usedShares;

        for (uint256 gen; gen < 15;) {
            if (current == address(0)) break;

            uint256 ratio;
            uint256 threshold;
            unchecked {
                ratio = (RATIOS_PACKED >> (gen * 12)) & 0xFFF;
                threshold = (THRESHOLDS_PACKED >> (gen * 4)) & 0xF;
            }
            uint256 share = (dynamicPool * ratio) / 10_000;

            if (share == 0) break;

            if (validDownlines[current] >= threshold) {
                lbp.mintReward(current, share);
                emit DynamicReward(current, originUser, uint8(gen + 1), share);
            } else {
                unchecked { hierarchyShare += share; }
                emit HierarchyBurn(current, share);
            }
            unchecked { usedShares += share; }

            current = referrer[current];
            unchecked {
                ++gen;
            }
        }

        if (usedShares < dynamicPool) {
            unchecked { hierarchyShare += dynamicPool - usedShares; }
        }

        if (hierarchyShare > 0) {
            lbp.mintReward(refVault, hierarchyShare);
        }
    }

    function _tickEmission() internal {
        (
            uint256 liveStatic,
            uint256 liveNode,
            uint256 emissionDelta,
            bool advanced
        ) = _previewAccumulators();
        if (!advanced) return;
        if (liveStatic != staticAccPerShare) staticAccPerShare = liveStatic;
        if (liveNode != nodeAccPerShare) nodeAccPerShare = liveNode;
        if (emissionDelta > 0) accountedEmission += emissionDelta;
        lastEmissionUpdate = uint64(block.timestamp);

        (, uint112 r1, ) = pair.getReserves();
        if (r1 != lastTickRLbp) lastTickRLbp = r1;
    }

    function _previewAccumulators()
        internal
        view
        returns (uint256 liveStatic, uint256 liveNode, uint256 emissionDelta, bool advanced)
    {
        liveStatic = staticAccPerShare;
        liveNode = nodeAccPerShare;
        if (!tradingOpened) return (liveStatic, liveNode, 0, false);
        if (block.timestamp <= lastEmissionUpdate) return (liveStatic, liveNode, 0, false);

        uint256 ts = totalSupply();
        uint256 nodeCt = totalNodeCount;
        if (ts == 0 && nodeCt == 0) {
            bool preopenStage = lastEmissionUpdate == openTime
                && lbp.lastTransfer() != address(0);
            return (liveStatic, liveNode, 0, !preopenStage);
        }

        emissionDelta = _calculateEmission(uint256(lastTickRLbp));
        if (emissionDelta == 0) return (liveStatic, liveNode, 0, true);

        uint256 staticPart = emissionDelta * EMIT_STATIC_PCT / 100;
        uint256 nodePart = emissionDelta * EMIT_NODE_PCT / 100;

        uint256 effectiveEmission;
        if (ts > 0 && staticPart > 0) {
            liveStatic += (staticPart * 1e18) / ts;

            effectiveEmission += emissionDelta - nodePart;
        }
        if (nodeCt > 0 && nodePart > 0) {
            liveNode += (nodePart * 1e18) / nodeCt;
            effectiveEmission += nodePart;
        }
        emissionDelta = effectiveEmission;
        advanced = true;
    }

    function _calculateEmission(uint256 circ) internal view returns (uint256) {
        uint256 startTime = lastEmissionUpdate;
        uint256 endTime = block.timestamp;
        if (endTime <= startTime) return 0;

        uint256 t_start = (startTime - openTime) / 1 days;
        uint256 t_end = (endTime - openTime) / 1 days;

        uint256 totalB;
        uint256 decay_t_end;

        if (t_start == t_end) {
            decay_t_end = PowMath.pow998(t_start);
            uint256 dailyB = circ * 160 * decay_t_end / 10_000 / 1e18;
            totalB = dailyB * (endTime - startTime) / 1 days;
        } else {
            uint256 nextDayBoundary = openTime + (t_start + 1) * 1 days;
            uint256 dayStartOfTEnd = openTime + t_end * 1 days;

            uint256 decay_start = PowMath.pow998(t_start);
            uint256 dailyB_start = circ * 160 * decay_start / 10_000 / 1e18;
            uint256 headSegment = dailyB_start * (nextDayBoundary - startTime) / 1 days;

            decay_t_end = PowMath.pow998(t_end);
            uint256 dailyB_end = circ * 160 * decay_t_end / 10_000 / 1e18;
            uint256 tailSegment = dailyB_end * (endTime - dayStartOfTEnd) / 1 days;

            uint256 middleSegment;
            if (t_end > t_start + 1) {

                uint256 decay_first_full = decay_start * 998 / 1000;
                if (decay_first_full > decay_t_end) {
                    uint256 decayDiff = decay_first_full - decay_t_end;
                    middleSegment = circ * 160 * decayDiff * 500 / 10_000 / 1e18;
                }
            }

            totalB = headSegment + middleSegment + tailSegment;
        }

        uint256 decay_t_end_plus_1 = decay_t_end * 998 / 1000;
        uint256 aCum = D0 * (1e18 - decay_t_end_plus_1) / 2e15;
        uint256 accounted = accountedEmission;
        uint256 aRemaining = aCum > accounted ? aCum - accounted : 0;

        return totalB < aRemaining ? totalB : aRemaining;
    }

    function _propagateUp(address user, uint256 amount) internal {
        address ref = referrer[user];
        if (ref == address(0) || ref == DEAD) return;

        uint256 oldShared = sharedHashrate[ref];
        uint256 newShared;
        unchecked { newShared = oldShared + amount; sharedHashrate[ref] = newShared; }

        bool sharedCrossedUp = oldShared < NODE_PERF_USDT && newShared >= NODE_PERF_USDT;
        if (sharedCrossedUp || isNode[ref]) {
            _updateNodeStatus(ref);
        }

        uint256 hashAfter = balanceOf(user);
        uint256 hashBefore;
        unchecked {
            hashBefore = hashAfter - amount;
        }

        if (hashBefore < VALID_INVITE_USDT && hashAfter >= VALID_INVITE_USDT) {
            unchecked {
                validDownlines[ref]++;
            }
        }
    }

    function _propagateDown(address user, uint256 amount) internal {
        address ref = referrer[user];
        if (ref == address(0) || ref == DEAD) return;

        uint256 oldShared = sharedHashrate[ref];
        if (oldShared < amount) revert SharedHashrateUnderflow();
        uint256 newShared;
        unchecked { newShared = oldShared - amount; sharedHashrate[ref] = newShared; }

        bool sharedCrossedDown = oldShared >= NODE_PERF_USDT && newShared < NODE_PERF_USDT;
        if (sharedCrossedDown || isNode[ref]) {
            _updateNodeStatus(ref);
        }

        uint256 hashAfter = balanceOf(user);
        uint256 hashBefore;
        unchecked {
            hashBefore = hashAfter + amount;
        }
        if (hashBefore >= VALID_INVITE_USDT && hashAfter < VALID_INVITE_USDT) {
            if (validDownlines[ref] > 0) {
                unchecked {
                    validDownlines[ref]--;
                }
            }
        }
    }

    function _updateNodeStatus(address user) internal {
        if (user == DEAD) return;

        bool wasNode = isNode[user];
        bool qualifies =
            balanceOf(user) >= NODE_LP_USDT && sharedHashrate[user] >= NODE_PERF_USDT;

        if (!wasNode && qualifies) {
            isNode[user] = true;
            unchecked {
                totalNodeCount++;
            }
            userNodeIndex[user] = nodeAccPerShare;
            emit NodeAdded(user);
        } else if (wasNode && !qualifies) {

            uint256 delta = nodeAccPerShare - userNodeIndex[user];
            if (delta > 0) {
                uint256 reward = delta / 1e18;
                if (reward > 0) lbp.mintReward(user, reward);
            }
            unchecked {
                totalNodeCount--;
            }
            isNode[user] = false;
            emit NodeRemoved(user);
        }
    }

    function _executeBind(address from, address to) internal {
        referrer[from] = to;

        uint256 existingHash = balanceOf(from);
        if (existingHash > 0) {
            unchecked {
                sharedHashrate[to] += existingHash;
            }
            _updateNodeStatus(to);

            if (existingHash >= VALID_INVITE_USDT) {
                unchecked {
                    validDownlines[to]++;
                }
            }
        }

        emit ReferrerBound(from, to);
    }

    function _tryBindReferral(address from, address to) internal returns (bool) {

        if (referrer[from] != address(0)) return false;
        if (from == DEAD) return false;
        if (from == to) return false;
        if (to == DEAD) return false;

        if (referrer[to] == address(0)) revert InvalidBind();

        _executeBind(from, to);
        return true;
    }
}
