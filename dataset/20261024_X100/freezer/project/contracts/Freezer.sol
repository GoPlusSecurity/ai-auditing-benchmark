// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {OperatorLockable} from "./OperatorLockable.sol";
import {DexTreasury} from "./DexTreasury.sol";
import {IFreezeHook} from "./interfaces/IFreezeHook.sol";
import {ITokenSource} from "./interfaces/ITokenSource.sol";

contract Freezer is OperatorLockable, DexTreasury, ITokenSource {
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Metadata;

    struct Frost {
        uint256 amount;
        address owner;
        uint8 tier;
        uint256 frozenAt;
        uint256 ownedAt;
    }

    struct Account {
        uint256 accruedNum;
        uint256 lastAccrualAt;
        uint256 lastClaimAt;
        uint256 firstFreezeAt;
        uint256 frostCount;
    }

    struct AccountView {
        uint256 accruedNum;
        uint256 lastAccrualAt;
        uint256 lastClaimAt;
        uint256 firstFreezeAt;
        uint256 frostCount;
        uint256 frozenTotal;
    }

    struct TierInfo {
        uint8 tier;
        uint256 term;
        uint256 weight;
    }

    struct FrostView {
        uint256 id;
        address owner;
        uint8 tier;
        uint256 amount;
        uint256 frozenAt;
        uint256 ownedAt;
        uint256 unfreezeAt;
        uint256 lockedTill;
        address lockedFor;
    }

    uint256 public constant MAX_FROSTS = 100;
    uint256 public constant CLAIM_COOLDOWN = 1 days;

    uint256 public constant DENOM = 3650 days;
    uint256 public constant YEAR = 365 days;
    uint8 public constant TIERS = 3;

    IERC20Metadata private immutable _token;

    uint256 public immutable candidacyFee;

    uint256 public nextFrostId = 1;
    uint256 public totalFrozen;
    uint256 public activeFrosts;
    IFreezeHook private immutable _freezeHook;
    address private immutable _freezerMarket;

    mapping(uint8 tier => uint256) public totalFrozenIn;
    mapping(uint8 tier => uint256) public activeFrostsIn;
    mapping(address owner => Account) private _accounts;
    mapping(address owner => mapping(uint8 tier => uint256)) private _tierTotal;
    mapping(uint256 frostId => Frost) private _frosts;

    event CandidacyFeeChanged(uint256 oldFee, uint256 newFee);
    event FrostCreated(uint256 indexed id, address indexed owner);
    event FrostChanged(uint256 indexed id);
    event FrostRemoved(uint256 indexed id, address indexed owner);
    event Frozen(uint256 indexed id, address indexed owner, uint8 tier, uint256 amount);
    event Unfrozen(uint256 indexed id, address indexed owner, uint8 tier, uint256 amount, uint256 left);
    event Merged(uint256 indexed id, uint256 indexed intoId, address indexed owner, uint8 tier);

    event Upgraded(uint256 indexed id, address indexed owner, uint8 fromTier, uint8 toTier, uint256 amount, uint256 frozenAt);
    event Transferred(
        uint256 indexed id,
        uint256 indexed remainderId,
        address indexed from,
        address to,
        uint8 tier,
        uint256 amount,
        uint256 frozenAt,
        uint256 lockedTill
    );
    event Returned(uint256 indexed id, address indexed from, address indexed to, uint8 tier, uint256 amount);
    event Claimed(address indexed owner, uint256 claimAmount);

    error InvalidTier(uint8 tier);
    error ZeroAmount();
    error ZeroAddress();
    error InvalidReceiver(address to);
    error NonexistentFrost(uint256 id);
    error IncorrectOwner(uint256 id, address owner, address expected);
    error FrostLocked(uint256 id, uint256 lockedTill);
    error FrostNotLocked(uint256 id);
    error StillFrozen(uint256 id, uint256 unfreezeAt);
    error InsufficientFrost(uint256 id, uint256 balance, uint256 needed);
    error TooManyFrosts(address owner, uint256 max);
    error TierMismatch(uint256 id, uint8 tier, uint8 expected);
    error NotAnUpgrade(uint256 id, uint8 tier, uint8 newTier);
    error InvalidListLength(uint256 length, uint256 minimum);
    error ClaimTooEarly(address owner, uint256 availableAt);
    error NothingToClaim(address owner);
    error RewardsDepleted();
    error AddressWithoutCode(address address_);
    error TreasuryBelowFrozen(uint256 balance, uint256 frozen);
    error OnlyMarketAccess();

    constructor(
        IERC20Metadata token_,
        uint256 dexSellCap_,
        address freezeHook_,
        address freezerMarket_,
        address dexModule_,
        Config memory dex
    ) DexTreasury(dexModule_, address(token_), dexSellCap_, dex) {
        require(address(token_) != address(0) && freezerMarket_ != address(0), ZeroAddress());
        require(freezeHook_ == address(0) || freezeHook_.code.length != 0, AddressWithoutCode(freezeHook_));
        require(freezerMarket_.code.length != 0, AddressWithoutCode(freezerMarket_));

        _token = token_;
        _freezeHook = IFreezeHook(freezeHook_);
        _freezerMarket = freezerMarket_;
        candidacyFee = 100 * 10 ** token_.decimals();

        emit CandidacyFeeChanged(0, candidacyFee);
    }

    function freeze(uint8 tier, uint256 amount, address referrer) external returns (uint256 id) {
        require(tier < TIERS, InvalidTier(tier));
        require(amount != 0, ZeroAmount());

        address sender = _msgSender();
        _requireSlot(sender);

        _token.safeTransferFrom(sender, address(this), amount);

        id = _freeze(sender, tier, amount);
        _notifyFreezeHook(sender, referrer, amount);
    }

    function unfreeze(uint256[] calldata ids) external returns (uint256 released) {
        require(ids.length != 0, InvalidListLength(ids.length, 1));

        released = 0;

        address sender = _msgSender();
        _settle(sender);

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            Frost memory frost = _requireFrostOf(sender, id);

            _requireFree(id);

            uint256 unfreezeAt = _unfreezeAt(frost);
            require(unfreezeAt <= block.timestamp, StillFrozen(id, unfreezeAt));

            released += frost.amount;

            _tierTotal[sender][frost.tier] -= frost.amount;
            totalFrozenIn[frost.tier] -= frost.amount;
            _destroy(sender, id);

            emit Unfrozen(id, sender, frost.tier, frost.amount, 0);
        }

        totalFrozen -= released;
        _onStakeChanged(sender);

        _token.safeTransfer(sender, released);
    }

    function unfreezeOne(uint256 id, uint256 amount) external {
        require(amount != 0, ZeroAmount());

        address sender = _msgSender();
        Frost memory frost = _requireFrostOf(sender, id);

        _requireFree(id);
        require(amount <= frost.amount, InsufficientFrost(id, frost.amount, amount));

        uint256 unfreezeAt = _unfreezeAt(frost);
        require(unfreezeAt <= block.timestamp, StillFrozen(id, unfreezeAt));

        _settle(sender);

        uint256 left = frost.amount - amount;
        if (left == 0) {
            _destroy(sender, id);
        } else {
            _frosts[id].amount = left;
            emit FrostChanged(id);
        }

        _tierTotal[sender][frost.tier] -= amount;
        totalFrozen -= amount;
        totalFrozenIn[frost.tier] -= amount;
        _onStakeChanged(sender);

        _token.safeTransfer(sender, amount);

        emit Unfrozen(id, sender, frost.tier, amount, left);
    }

    function merge(uint256[] calldata ids) external returns (uint256 newId) {
        require(ids.length >= 2, InvalidListLength(ids.length, 2));

        address sender = _msgSender();
        _settle(sender);

        uint8 tier = _requireFrostOf(sender, ids[0]).tier;
        uint256 mergedAmount;
        uint256 mergedFrozenAt;

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            Frost memory frost = _requireFrostOf(sender, id);

            _requireFree(id);
            require(frost.tier == tier, TierMismatch(id, frost.tier, tier));

            mergedAmount += frost.amount;
            if (frost.frozenAt > mergedFrozenAt) {
                mergedFrozenAt = frost.frozenAt;
            }

            _destroy(sender, id);
        }

        newId = _create(sender, tier, mergedAmount, mergedFrozenAt, block.timestamp);

        for (uint256 i = 0; i < ids.length; ++i) {
            emit Merged(ids[i], newId, sender, tier);
        }
    }

    function upgrade(uint256 id, uint8 newTier) external {
        require(newTier < TIERS, InvalidTier(newTier));

        address sender = _msgSender();
        Frost memory frost = _requireFrostOf(sender, id);
        require(newTier > frost.tier, NotAnUpgrade(id, frost.tier, newTier));

        _requireFree(id);

        _settle(sender);

        _tierTotal[sender][frost.tier] -= frost.amount;
        _tierTotal[sender][newTier] += frost.amount;
        totalFrozenIn[frost.tier] -= frost.amount;
        totalFrozenIn[newTier] += frost.amount;
        activeFrostsIn[frost.tier] -= 1;
        activeFrostsIn[newTier] += 1;

        _frosts[id].tier = newTier;
        _frosts[id].frozenAt = block.timestamp;
        _frosts[id].ownedAt = block.timestamp;

        _onStakeChanged(sender);

        emit Upgraded(id, sender, frost.tier, newTier, frost.amount, block.timestamp);
        emit FrostChanged(id);
    }

    function claim() external {
        address sender = _msgSender();

        uint256 availableAt = _accounts[sender].lastClaimAt + CLAIM_COOLDOWN;
        require(block.timestamp >= availableAt, ClaimTooEarly(sender, availableAt));
        require(_pending(sender) != 0, NothingToClaim(sender));

        _settle(sender);

        Account storage account = _accounts[sender];
        uint256 accrued = account.accruedNum / DENOM;
        uint256 available = availableRewards();
        uint256 claimAmount = accrued < available ? accrued : available;
        require(claimAmount != 0, RewardsDepleted());

        account.accruedNum -= claimAmount * DENOM;
        account.lastClaimAt = block.timestamp;

        _token.safeTransfer(sender, claimAmount);

        emit Claimed(sender, claimAmount);
    }

    function lock(uint256 id, uint256 lockTill) public override {
        super.lock(id, lockTill);

        emit FrostChanged(id);
    }

    function unlock(uint256 id) public override {
        bool wasLocked = isLocked(id);

        super.unlock(id);

        if (wasLocked) {
            emit FrostChanged(id);
        }
    }

    function transferPart(
        address from,
        uint256 id,
        uint256 amount,
        address to
    ) external returns (uint256 remainderId) {
        require(_msgSender() == _freezerMarket, OnlyMarketAccess());
        require(to != address(0) && to != address(this) && to != from, InvalidReceiver(to));
        require(amount != 0, ZeroAmount());

        Frost memory frost = _requireFrostOf(from, id);
        require(amount <= frost.amount, InsufficientFrost(id, frost.amount, amount));

        address lockedFor = lockedForOf(id);
        require(lockedFor == address(0) || lockedFor == from, FrostLocked(id, lockTillOf(id)));

        _requireAllowance(from, _msgSender());
        _requireSlot(to);

        remainderId = _move(id, frost, amount, to);

        emit Transferred(id, remainderId, from, to, frost.tier, amount, frost.frozenAt, lockTillOf(id));
    }

    function returnLocked(uint256 id) external {
        require(_msgSender() == _freezerMarket, OnlyMarketAccess());
        address to = lockedForOf(id);
        require(to != address(0), FrostNotLocked(id));

        _requireAllowance(to, _msgSender());

        Frost memory frost = _requireFrost(id);

        require(to != frost.owner, InvalidReceiver(to));

        _requireSlot(to);

        _move(id, frost, frost.amount, to);
        _unlock(id);

        emit Returned(id, frost.owner, to, frost.tier, frost.amount);
    }

    function token() public view override returns (IERC20) {
        return _token;
    }

    function freezerMarket() external view returns (address) {
        return _freezerMarket;
    }

    function freezeHook() external view returns (address) {
        return address(_freezeHook);
    }

    function getAccount(address owner) external view returns (AccountView memory) {
        Account memory account = _accounts[owner];

        return AccountView({
            accruedNum: account.accruedNum,
            lastAccrualAt: account.lastAccrualAt,
            lastClaimAt: account.lastClaimAt,
            firstFreezeAt: account.firstFreezeAt,
            frostCount: account.frostCount,
            frozenTotal: frozenOf(owner)
        });
    }

    function frozenOf(address owner) public view returns (uint256 total) {
        total = 0;
        for (uint8 tier = 0; tier < TIERS; ++tier) {
            total += _tierTotal[owner][tier];
        }
    }

    function frozenByTierOf(address owner) external view returns (uint256[] memory out) {
        out = new uint256[](TIERS);
        for (uint8 tier = 0; tier < TIERS; ++tier) {
            out[tier] = _tierTotal[owner][tier];
        }
    }

    function pendingOf(address owner) external view returns (uint256) {
        return _pending(owner);
    }

    function tierTotalOf(address owner, uint8 tier) external view returns (uint256) {
        return _tierTotal[owner][tier];
    }

    function tiers() external pure returns (TierInfo[] memory out) {
        out = new TierInfo[](TIERS);
        for (uint8 tier = 0; tier < TIERS; ++tier) {
            out[tier] = TierInfo({tier: tier, term: _term(tier), weight: _weight(tier)});
        }
    }

    function totalFrozenByTier() external view returns (uint256[] memory out) {
        out = new uint256[](TIERS);
        for (uint8 tier = 0; tier < TIERS; ++tier) {
            out[tier] = totalFrozenIn[tier];
        }
    }

    function activeFrostsByTier() external view returns (uint256[] memory out) {
        out = new uint256[](TIERS);
        for (uint8 tier = 0; tier < TIERS; ++tier) {
            out[tier] = activeFrostsIn[tier];
        }
    }

    function unfreezeAtOf(uint256 id) external view returns (uint256) {
        Frost memory frost = _frosts[id];
        return frost.owner == address(0) ? 0 : _unfreezeAt(frost);
    }

    function getFrost(uint256 id) external view returns (FrostView memory) {
        return _frostView(id);
    }

    function getFrosts(uint256[] calldata ids) external view returns (FrostView[] memory out) {
        out = new FrostView[](ids.length);
        for (uint256 i = 0; i < ids.length; ++i) {
            out[i] = _frostView(ids[i]);
        }
    }

    function availableRewards() public view returns (uint256) {
        uint256 balance = _token.balanceOf(address(this));
        return balance > totalFrozen ? balance - totalFrozen : 0;
    }

    function isApprovedForAll(address owner, address operator) public view override returns (bool) {
        return _operatorPermitted(operator) && super.isApprovedForAll(owner, operator);
    }

    function _freeze(address owner, uint8 tier, uint256 amount) private returns (uint256 id) {
        _settle(owner);

        Account storage account = _accounts[owner];
        if (account.firstFreezeAt == 0) {
            account.firstFreezeAt = block.timestamp;
        }

        id = _create(owner, tier, amount, block.timestamp, block.timestamp);

        _tierTotal[owner][tier] += amount;
        totalFrozen += amount;
        totalFrozenIn[tier] += amount;
        _onStakeChanged(owner);

        emit Frozen(id, owner, tier, amount);
    }

    function _move(uint256 id, Frost memory frost, uint256 amount, address to) private returns (uint256 remainderId) {
        remainderId = 0;

        _settle(frost.owner);
        _settle(to);

        _tierTotal[frost.owner][frost.tier] -= amount;
        _tierTotal[to][frost.tier] += amount;
        _onStakeChanged(frost.owner);
        _onStakeChanged(to);

        _frosts[id].owner = to;
        _frosts[id].ownedAt = block.timestamp;
        _accounts[frost.owner].frostCount -= 1;
        _accounts[to].frostCount += 1;

        if (amount != frost.amount) {
            _frosts[id].amount = amount;
            remainderId = _create(frost.owner, frost.tier, frost.amount - amount, frost.frozenAt, frost.ownedAt);
        }

        emit FrostChanged(id);
    }

    function _create(
        address owner,
        uint8 tier,
        uint256 amount,
        uint256 frozenAt,
        uint256 ownedAt
    ) private returns (uint256 id) {
        id = nextFrostId++;
        _frosts[id] = Frost({amount: amount, owner: owner, tier: tier, frozenAt: frozenAt, ownedAt: ownedAt});
        _accounts[owner].frostCount += 1;
        activeFrosts += 1;
        activeFrostsIn[tier] += 1;

        emit FrostCreated(id, owner);
    }

    function _destroy(address owner, uint256 id) private {
        uint8 tier = _frosts[id].tier;

        delete _frosts[id];
        _accounts[owner].frostCount -= 1;
        activeFrosts -= 1;
        activeFrostsIn[tier] -= 1;

        _unlock(id);

        emit FrostRemoved(id, owner);
    }

    function _settle(address owner) private {
        Account storage account = _accounts[owner];
        uint256 earned = _accruedNumSince(owner, account.lastAccrualAt);
        if (earned != 0) {
            account.accruedNum += earned;
        }
        account.lastAccrualAt = block.timestamp;
    }

    function _notifyFreezeHook(address owner, address referrer, uint256 amount) private {
        IFreezeHook hook = _freezeHook;
        if (address(hook) != address(0)) {
            hook.onFreeze(owner, referrer, amount, _accounts[owner].firstFreezeAt);
        }
    }

    function _requireSlot(address owner) private view {
        require(_accounts[owner].frostCount < MAX_FROSTS, TooManyFrosts(owner, MAX_FROSTS));
    }

    function _requireFrost(uint256 id) private view returns (Frost memory frost) {
        frost = _frosts[id];
        require(frost.owner != address(0), NonexistentFrost(id));
    }

    function _requireFrostOf(address owner, uint256 id) private view returns (Frost memory frost) {
        frost = _requireFrost(id);
        require(frost.owner == owner, IncorrectOwner(id, frost.owner, owner));
    }

    function _requireFree(uint256 id) private view {
        require(!isLocked(id), FrostLocked(id, lockTillOf(id)));
    }

    function _accruedNumSince(address owner, uint256 since) private view returns (uint256) {
        if (since == 0 || since >= block.timestamp) {
            return 0;
        }

        uint256 elapsed = block.timestamp - since;
        uint256 weighted;
        for (uint8 tier = 0; tier < TIERS; ++tier) {
            uint256 total = _tierTotal[owner][tier];
            if (total != 0) {
                weighted += total * _weight(tier);
            }
        }
        return weighted * elapsed;
    }

    function _pending(address owner) private view returns (uint256) {
        Account storage account = _accounts[owner];
        return (account.accruedNum + _accruedNumSince(owner, account.lastAccrualAt)) / DENOM;
    }

    function _frostView(uint256 id) private view returns (FrostView memory out) {
        Frost memory frost = _frosts[id];
        if (frost.owner == address(0)) {
            return out;
        }

        out = FrostView({
            id: id,
            owner: frost.owner,
            tier: frost.tier,
            amount: frost.amount,
            frozenAt: frost.frozenAt,
            ownedAt: frost.ownedAt,
            unfreezeAt: _unfreezeAt(frost),
            lockedTill: lockTillOf(id),
            lockedFor: lockedForOf(id)
        });
    }

    function _ownerOf(uint256 id) internal view override returns (address) {
        return _frosts[id].owner;
    }

    function _operatorPermitted(address operator) internal view override returns (bool) {
        return operator == _freezerMarket;
    }

    function _requireAllowance(address owner, address operator) internal view override {
        _requireOperatorPermitted(operator);
        require(isApprovedForAll(owner, operator), NotApproved(owner, operator));
    }

    function _stakeOf(address account) internal view override returns (uint256) {
        return frozenOf(account);
    }

    function _collectCandidacyFee(address payer) internal override {
        _token.safeTransferFrom(payer, address(this), candidacyFee);
    }

    function _afterExecute(uint256) internal view override {
        uint256 balance = _token.balanceOf(address(this));
        require(balance >= totalFrozen, TreasuryBelowFrozen(balance, totalFrozen));
    }

    function _unfreezeAt(Frost memory frost) private pure returns (uint256) {
        return frost.frozenAt + _term(frost.tier);
    }

    function _term(uint8 tier) private pure returns (uint256) {
        return (uint256(tier) * 2 + 1) * YEAR;
    }

    function _weight(uint8 tier) private pure returns (uint256) {
        return uint256(tier) + 1;
    }
}
