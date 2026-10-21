// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "./IERC20.sol";
import {IUniswapV2Router02} from "./IUniswapV2Router02.sol";
import {IUniswapV2Pair} from "./IUniswapV2Pair.sol";
import {ITG} from "./ITG.sol";



import {IERC20Upgradeable} from "./IERC20Upgradeable.sol";
 import {UUPSUpgradeable} from "./UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "./OwnableUpgradeable.sol";
library Math {
    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint40 a, uint40 b) internal pure returns (uint40) {
        return a < b ? a : b;
    }

    function min256(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

contract TGing is   UUPSUpgradeable,OwnableUpgradeable {
    event Staked(address indexed user, uint256 amount, uint256 timestamp, uint256 index);
    event RewardPaid(address indexed user, uint256 reward, uint40 timestamp, uint256 index);
    event Transfer(address indexed from, address indexed to, uint256 amount);
 




    address public TGpool;
    address public TGMK;


    uint256 public witeTime = 24 hours;
 
    IUniswapV2Router02  ROUTER = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IERC20 public  USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);

    ITG public TG;

    uint8 public constant decimals = 18;
    string public constant name = "Computility";
    string public constant symbol = "Computility";

    uint256 public totalSupply;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public investAmount;
    mapping(address user => uint256 index) public userIndex;
    mapping(address user => uint256 index) public recommendUsers;
    mapping(address user => Record[] stakingRecords) public userStakeRecord;
    mapping(address user => RecordUSDT[] stakingRecords) public userStakeRecordUSDT;
    mapping(address user => RecordUSDT stakingRecords) public userStakeUSDT;
    RecordTT[] public t_supply;
    // 30%
    uint256[] public recommendrateRate =[1500,100,300,200,500,100,100,100,100];
    uint256[] public limitedRate = [500,50,100,50,200,25,25,25,25];
    uint256   COMPOUND = 0; // 1% 24 hours

     mapping(uint256 time => uint256 COMPOUND) public USDTCOMPOUND;
     mapping(address user => uint256 time) public selltime;

    address[] public PERPETUAL;
    uint256 public lastOrderTime;

    uint40 public TG30DayTime;
    mapping(address user => address[] zt) public recommendList;
    uint256 public TGfirstprice = 1e18;



    uint256 public LSnum;
    mapping(uint256 Lnum => uint256 lastreward) public rewardLists;
    mapping(uint256 Lnum => address[] lastPERPETUALs) public PERPETUALLists;
    address private   WBNB;
    address private   OP ;



    uint256 public MAXrewardindex;
    address public BNBpool;
    address public TGUSDTpair;
    address public UPaddress;
    mapping(address => uint160) public teaminvestAmount;
    mapping(address => bool) public register;

     mapping(address user => uint256 index) public yl1;
     mapping(address user => uint256 index) public buyamount;
     mapping(address user => uint256 index) public yl;


 
    struct RecordTT {
        uint40 stakeTime;
        uint160 tamount;
    }

    struct Record {
        uint40 stakeTime;
        uint160 amount;
        bool status;
        uint40 limited;
    }

    struct RecordUSDT {
        uint40 stakeTime;
        uint160 amount;
        bool status;
        uint40 limited;
    }





    modifier onlyEOA() {
        require(tx.origin == msg.sender, "EOA");
        _;
    }

    
 
 function initialize()external initializer{
        require(0x37EfA4fc61f9A05D4766B2bdce2111EDeFf25561 ==msg.sender, "Ownable: caller is not the OP");
        __Ownable_init();
        ROUTER = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
        WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;



        OP = 0xc55ca91C0d5482379c775e87B750450F33B6474F;
        UPaddress = 0x2336C862Ab05CF83d224209fC79d5D2179A50C2E;
        TGpool = 0x850a3b9e935E3b4d4C71edf983eB3267534e552F;
        BNBpool = 0xceDdE9EAe01381C476eC3b16a22c5154Fe4c59a2;

        // TGpool = 0xceDdE9EAe01381C476eC3b16a22c5154Fe4c59a2;
        TGMK = 0xa47a5E443c377cc28412597c6a646586BAF62C7A;

        USDT.approve(address(ROUTER), type(uint256).max);
        USDTCOMPOUND[86400]     = 10050;
        USDTCOMPOUND[604800]    = 10445;
        USDTCOMPOUND[1296000]   = 11269 ;
        USDTCOMPOUND[2592000]   = 13478;
        recommendrateRate = [1500,100,300,200,500,100,100,100,100];
        limitedRate = [500,50,100,50,200,25,25,25,25];
        TGfirstprice = 1e10;

      }
    function _authorizeUpgrade(address) internal override onlyOwner {}
    function setUSDT(address  USD ) external onlyOwner {
        USDT = IERC20(USD);
        USDT.approve(address(ROUTER), type(uint256).max);
    }
     function setTGMK(address  MK ) external onlyOwner {
        TGMK =  MK;
     
    }

    function swapBNB(uint256 amount)external returns (uint256 BNBa)  {
        uint256  price  =   getmobilityandPrice();
        BNBa  = amount * price/1e18;
        IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c).transferFrom(BNBpool, msg.sender, BNBa);
        TG.transferFrom(msg.sender, address(1), amount);
    }

    function getmobilityandPrice( ) private  view returns( uint256  price )   {
        uint256 dead = TG.balanceOf(address(0xdead));
        uint256 pair = TG.balanceOf(TGUSDTpair);
        uint256 total = TG.totalSupply();
        uint256 mobility = total - dead- pair;
        uint256 BNBa= IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c).balanceOf(BNBpool);
        price =  BNBa*1e18/mobility;
     }
     function getTGprice()public view returns (uint256 burn1,uint256 price,uint256 oneprice) {

            burn1 = TG.balanceOf(address(0xdead));

            uint256 TGbalance = TG.balanceOf(address(TGUSDTpair));
             uint256 usdtbalance = USDT.balanceOf(address(TGUSDTpair));
            price = usdtbalance*1e18/TGbalance;
            oneprice = TGfirstprice;
        }


    function getprice( ) external   view returns( uint256  price )   {
        price  =   getmobilityandPrice();
     }

    function setTGUSDTpair(address TGUSDTpairaddress ) external   onlyOwner   {
        TGUSDTpair  =   TGUSDTpairaddress;
     }

  function setBNBpool(address BNBpoolADD ) external   onlyOwner   {
        BNBpool  =   BNBpoolADD;
     }

    function setTGpool(address stakeTime) external onlyOwner {
        TGpool =  stakeTime ;
    }

    function setTG(address _TG) external onlyOwner {
        TG = ITG(_TG);
        TG.approve(address(ROUTER), type(uint256).max);
    }

    function setWiteTime(uint40 _witeTime) external onlyOwner {
        witeTime = (_witeTime);
    }

    function network1In() public view returns (uint256 value) {
        uint256 len = t_supply.length;
        if (len == 0) return 0;
        uint256 one_last_time = block.timestamp - 1 minutes;
        uint256 last_supply = totalSupply;

        for (uint256 i = len - 1; i >= 0; i--) {
            RecordTT storage stake_tt = t_supply[i];
            if (one_last_time > stake_tt.stakeTime) {
                break;
            } else {
                last_supply = stake_tt.tamount;
            }
            if (i == 0) break;
        }
        return totalSupply - last_supply;
    }

    function maxStakeAmount() public view returns (uint256) {
        uint256 lastIn = network1In();
        uint112 reverseu = TG.getReserveU();
        uint256 p1 = reverseu / 100;
        if (lastIn > p1) return 0;
        else return Math.min256(p1 - lastIn, 1000 ether);
    }



    function stake(uint160 _amount, uint256 amountOutMin, uint40 limited) external onlyEOA {
        require(_amount <= maxStakeAmount(), "<100");
        swapAndAddLiquidity(_amount, amountOutMin);
        mint(msg.sender, _amount, limited);
        _settlePERPETUALReward();
        if(_amount > 50 ether){
            lastOrderTime = block.timestamp;
             PERPETUAL.push(msg.sender);
        }
    }


    function getSuperior(address sender) external view onlyEOA returns(address) {
       return  TG.inviter(sender);
    }

     function Invite(address parent) external onlyEOA {
        require(TG.inviter(parent)!=address(0) ||parent == UPaddress , "no register");
        setInvite(msg.sender,  parent);
    }

    function setInvite(address sender,address parent) private   {
        address up = TG.inviter(sender);
        if (up == address(0)) {
            TG.blindEx(sender, parent);
         }
    }

    // function stakeWithInviter(uint160 _amount, uint256 amountOutMin, address parent,uint40 limited) external onlyEOA {
    //     require(_amount <= maxStakeAmount(), "<100");
    //     swapAndAddLiquidity(_amount, amountOutMin);
    //     mint(msg.sender, _amount,limited);
    //     setInvite(msg.sender,  parent);
    //     if(_amount > 50 ether){
    //         lastOrderTime = block.timestamp;
    //         PERPETUAL.push(msg.sender);
    //     }
    // }

// buy
  function swapUsdtToTG(uint256 tokenAmount) public   {
        USDT.transferFrom(msg.sender, address(this), tokenAmount);
        address[] memory path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(TG);
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0,  
            path,
            msg.sender,
            block.timestamp
        );
    }
    // sell
  function swapTGToUSDT(uint256 tokenAmount) public   {
        TG.transferFrom(msg.sender, address(this), tokenAmount);
         address[] memory path = new address[](2);
        path[0] = address(TG);
        path[1] = address(USDT);

        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0,  
            path,
            msg.sender,
            block.timestamp
        );
    }


    function setTeaminvestAmount(address sender,uint160 _amount) private   {
       address up = TG.inviter(sender);
        if (up != address(0)) {
            teaminvestAmount[sender]  = teaminvestAmount[sender]+_amount;
            setTeaminvestAmount(up, _amount);
        }
    }

      function setTeaminvestAmount30(address sender,uint160 _amount) private   {
       address up = TG.inviter(sender);
        if (up != address(0)) {
            yl1[sender]  = yl1[sender]+_amount;
            setTeaminvestAmount30(up, _amount);
        }
    }


       function setTeaminvestAmountSUB30(address sender,uint160 _amount) private    {
       address up = TG.inviter(sender);
        if (up != address(0)) {
            if(yl1[sender] > _amount){
                yl1[sender]  = yl1[sender] - _amount;
            }
            else {
                 yl1[sender]  =0;
            }
            setTeaminvestAmountSUB30(up, _amount);
        }
    }
    
 
    function setTeaminvestAmountSUB(address sender,uint160 _amount) private    {
       address up = TG.inviter(sender);
        if (up != address(0)) {
            if(teaminvestAmount[sender] > _amount){
                teaminvestAmount[sender]  = teaminvestAmount[sender] - _amount;
            }
            else {
                 teaminvestAmount[sender]  =0;
            }
            setTeaminvestAmountSUB(up, _amount);
        }
    }
    

    function swapAndAddLiquidity(uint160 _amount, uint256 amountOutMin) private  {
        USDT.transferFrom(msg.sender, address(this), _amount);
        investAmount[msg.sender] = investAmount[msg.sender] + _amount;
       address up = TG.inviter(msg.sender);
        if(!register[msg.sender]&&investAmount[msg.sender]  >=200e18&&up!=UPaddress ){
            register[msg.sender]  = true;
            recommendUsers[up] = recommendUsers[up] + 1;
        }
        setTeaminvestAmount(msg.sender,  _amount);
        tgaddLiquidity(   _amount,   amountOutMin);
    }


function tgaddLiquidity( uint160 _amount, uint256 amountOutMin) private     {
        address[] memory path = new address[](2);
        path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(TG);
        uint256 balb = TG.balanceOf(address(this));
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amount / 2, amountOutMin, path, address(this), block.timestamp
        );
        uint256 bala = TG.balanceOf(address(this));
        ROUTER.addLiquidity(
            address(USDT),
            address(TG),
            _amount / 2,
            bala - balb,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(0),
            block.timestamp
        );
    }

    function mint(address sender, uint160 _amount, uint40 limited) private  {
        require(0 < USDTCOMPOUND[limited], "limited err");
        RecordTT memory tsy;
        tsy.stakeTime = uint40(block.timestamp);
        tsy.tamount = uint160(totalSupply);
        t_supply.push(tsy);
        Record memory order;
        order.stakeTime = uint40(block.timestamp);
        order.amount = _amount;
        order.status = false;
        order.limited = limited;

        if(limited == 2592000){
            setTeaminvestAmount30(msg.sender,  _amount);

        }

        totalSupply += _amount;
        balances[sender] += _amount;
        Record[] storage cord = userStakeRecord[sender];
        uint256 stake_index = cord.length;
        cord.push(order);
        emit Transfer(address(0), sender, _amount);
        emit Staked(sender, _amount, block.timestamp, stake_index);
    }
 
    function _settlePERPETUALReward()internal    {
        address[] storage cord = PERPETUAL;

        if(lastOrderTime > 0 && (block.timestamp - lastOrderTime) > 1 days && MAXrewardindex<cord.length - 1 ){

             uint256 OrderPool =  USDT.balanceOf(address(TGpool));
             USDT.transferFrom(TGpool, address(this), OrderPool);

         uint256   reward = OrderPool / 2;
            uint256 min =  0;
            if(cord.length-MAXrewardindex >=10){
                min = cord.length-10;

            }else{
                min =  MAXrewardindex;
            }
            uint256 index =  0;
        if (cord.length > 0) {
            for (uint256 i =min; i < cord.length; i++) {

                    PERPETUALLists[LSnum].push(PERPETUAL[cord.length - min +index]);

                    if( min == cord.length-10){
                        if(i == cord.length-1){
                            if(USDT.balanceOf(address(this))>reward)
                            USDT.transfer(PERPETUAL[min +index], reward);
                        }else{
                            if(USDT.balanceOf(address(this))>reward/9)
                            USDT.transfer(PERPETUAL[min +index], reward/9);
                        }
                    }else{
                        if(i == cord.length-1){
                            if(USDT.balanceOf(address(this))>reward)
                            USDT.transfer(PERPETUAL[ min +index], reward);

                        }else{
                            if(USDT.balanceOf(address(this))>reward/(cord.length-MAXrewardindex-1))
                            USDT.transfer(PERPETUAL[ min +index], reward/(cord.length-MAXrewardindex-1));
                        }
                    }
                index = index+1;
            }
        }
        rewardLists[LSnum] = reward;
        MAXrewardindex = cord.length-1;
        LSnum = LSnum+1;
    } 
    }
 

    function gettlePERPETUALRewardinfo()public  view  returns (address[] memory playerarr, uint256 reward) {
             uint256 OrderPool =  USDT.balanceOf(address(TGpool));
 
            reward = OrderPool / 2;
            address[] storage cord = PERPETUAL;
            uint256 minI =  0;
            if(cord.length-MAXrewardindex >10){
                minI = cord.length-10;
                playerarr = new address[](10);

            }else{
                minI = MAXrewardindex;
                playerarr = new address[](cord.length-MAXrewardindex);
            }
            uint256 index =  0;

        if (cord.length > 0) {
            for (uint256 i =minI; i < cord.length; i++) {
                playerarr[index] = PERPETUAL[ minI +index];
                index = index+1;
            }
        }
 
    }


    function getHistoryPERPETUALRewardinfo(uint256 index)public  view  returns (address[] memory playerarr, uint256 reward) {
        playerarr = PERPETUALLists[index];
        reward = rewardLists[index];
    }
     function recordbalanceOf(address account) external view returns (uint256 balance) {
        Record[] storage cord = userStakeRecord[account];
        if (cord.length > 0) {
            for (uint256 i = cord.length - 1; i >= 0; i--) {
                Record storage user_record = cord[i];
                if (user_record.status == false) {
                    balance += caclItem(user_record);
                } 
                if (i == 0) break;
            }
        }
    }


 
    function balanceOf(address account) external view returns (uint256 balance) {
        balance = balances[account];
    }

    function caclItem(Record storage user_record) private view returns (uint256 reward) {
        uint256 stake_amount =  (user_record.amount);
        uint40 stake_time = user_record.stakeTime;
        uint40 stake_period = (uint40(block.timestamp) - stake_time);
        stake_period = Math.min(stake_period, user_record.limited);
        if (stake_period == 0) reward = reward;
        else reward =  stake_amount*(USDTCOMPOUND[user_record.limited])/10000;
    }

    function rewardOfSlot(address user, uint8 index) public view returns (uint256 reward) {
        Record storage user_record = userStakeRecord[user][index];
        return caclItem(user_record);
    }

    function stakeCount(address user) external view returns (uint256 count) {
        count = userStakeRecord[user].length;
    }

    function unstake(uint256 index) external onlyEOA returns (uint256) {

 
        selltime[msg.sender] = block.timestamp;
  
        (uint256 reward, uint256 stake_amount) = burn(index);
        uint256 bal_this = TG.balanceOf(address(this));

        uint256 usdt_this = USDT.balanceOf(address(this));

        address[] memory path = new address[](2);
        path = new address[](2);
        path[0] = address(TG);
        path[1] = address(USDT);
        ROUTER.swapTokensForExactTokens(reward, bal_this, path, address(this), block.timestamp);
        uint256 bal_now = TG.balanceOf(address(this));
        uint256 usdt_now = USDT.balanceOf(address(this));
        uint256 amount_TG = bal_this - bal_now;
        uint256 amount_usdt = usdt_now - usdt_this;

        uint256 interset;
        if (amount_usdt > stake_amount) {
            interset = amount_usdt - stake_amount;
        }
        uint256 fee = interset  ;
        uint256 feeS =  DistributeSuperiorIncome(msg.sender, fee);
        uint256 bldx  =    interset *3/10  - feeS;

        USDT.transfer(TGMK, interset/10);


        USDT.transfer(TGMK, bldx);
    

        USDT.transfer(msg.sender,amount_usdt -interset*4/10 );

        TG.recycle(amount_TG);

        investAmount[msg.sender] =investAmount[msg.sender] - stake_amount;
        if(investAmount[msg.sender]<200e18&&register[msg.sender] ){
            address up = TG.getInviter(msg.sender);
            register[msg.sender] = false;
            if ( recommendUsers[up] >= 1) {
                recommendUsers[up] = recommendUsers[up] -1;
            }  
        }
         setTeaminvestAmountSUB(msg.sender,  uint160(stake_amount));
 
        return reward;
    }









     
    function DistributeSuperiorIncome(address UPsender, uint256 fee) private  returns (uint256 feesS)  {

              feesS = 0;


          if (fee > 0) {
            address up = TG.inviter(UPsender);
            if (up == address(0)) {
                up = address(TG);
            }
            uint256 total =0;

        for (uint256 i = 0; i < 9; i++) {
            if (up == address(0)){
                break;
            }        
            total =recommendUsers[up];

                    
            if(i  <3&&  total>2){
                USDT.transfer(up, fee * recommendrateRate[i]/10000);
                feesS = feesS + fee * recommendrateRate[i]/10000;
            } 
            if (i >=3 && i <5 &&total>3){
                USDT.transfer(up, fee * recommendrateRate[i]/10000);
                feesS = feesS + fee * recommendrateRate[i]/10000;
            }
                 
            if (i >=5  &&total>5){
                USDT.transfer(up, fee * recommendrateRate[i]/10000);
                feesS = feesS + fee * recommendrateRate[i]/10000;
            }
            up = TG.inviter(up);
            }
        }
    }

    function burn(uint256 index) private  returns (uint256 reward, uint256 amount) {
        address sender = msg.sender;
        Record[] storage cord = userStakeRecord[sender];
        Record storage user_record = cord[index];
        uint256 stakeTime = user_record.stakeTime;
        require(block.timestamp - stakeTime >= user_record.limited, "limited");
        if(user_record.limited == 2592000){
            setTeaminvestAmountSUB30(msg.sender,user_record.amount);
        }
        require(user_record.status == false, "alw");
        amount = user_record.amount;
        totalSupply -= amount;
        balances[sender] -= amount;
        emit Transfer(sender, address(0), amount);
 
        reward = caclItem(user_record);
        user_record.status = true;
        userIndex[sender] = userIndex[sender] + 1;

        emit RewardPaid(sender, reward, uint40(block.timestamp), index);
    }
 
    function sync() external {
        uint256 w_bal = IERC20(USDT).balanceOf(address(this));
        address pair = TG.uniswapV2Pair();
        IERC20(USDT).transfer(pair, w_bal);
        IUniswapV2Pair(pair).sync();
    }
    function emergencyWithdrawTG(address to, uint256 _amount) external onlyOwner {
        TG.transfer(to, _amount);
    }
    function emergencyWithdrawUSDT(address to, uint256 _amount) external onlyOwner {
        USDT.transfer(to, _amount);
    }
    struct Users {
        address account;
        uint112 bal;
        uint40 st;
    }

    function setOP(address to) external onlyOwner {
        OP = to;
    }

    function yingshe(address[] calldata account,uint112[] calldata bal,uint40[] calldata st,uint40[] calldata limited) external   {
        
        require(OP ==msg.sender, "Ownable: caller is not the OP");

        for (uint256 i = 0; i < account.length; i++) {
            uint256 _amount = bal[i];
            address to = account[i];
            uint40 stakeTime = st[i];
            uint40 limiteds = limited[i];

             yingsheOne( to, _amount, stakeTime, limiteds);

         }
    }


    function yingsheOne(address account,uint256 bal,uint40 st,uint40 limited) public    {
        
        require(OP ==msg.sender, "Ownable: caller is not the OP");

             uint256 _amount = bal;
            address to = account;
            uint40 stakeTime = st;

            Record memory order;
            order.stakeTime = stakeTime;
            order.amount = uint160(_amount);
            order.status = false;
            order.limited = limited;

            totalSupply += _amount;
            balances[to] += _amount;
            Record[] storage cord = userStakeRecord[to];
            uint256 stake_index = cord.length;
            cord.push(order);


       address up = TG.inviter(account);
        investAmount[account] = investAmount[account] + _amount;

        if(!register[account]&&investAmount[account]  >=200e18&&up!=UPaddress ){
            register[account]  = true;
            recommendUsers[up] = recommendUsers[up] + 1;
        }
        setTeaminvestAmount(account,   uint160(_amount));

            emit Transfer(address(0), to, _amount);
            emit Staked(to, _amount, stakeTime, stake_index);
        // }
    }




    function setInviteOP(address sender,address parent) public  {
        require(OP ==msg.sender, "Ownable: caller is not the OP");

        address up = TG.inviter(sender);
        if (up == address(0)) {
            TG.blindEx(sender, parent);
         }
    }

    function getrefOrder(address account) external view returns(Record[] memory RecordOrder) {
        return  userStakeRecord[account];
    }

    function getrefUSDTOrder(address account) external view returns(RecordUSDT memory RecordOrder) {
        return  userStakeUSDT[account];
    }

   function getrefSubordinateList(address account) external view returns(address[] memory List) {
        return  recommendList[account];
    }
    
    receive() external payable {
        buy();
    }
    uint256 public minsssss = 100000000000000000;   


     function buy() internal  {
 
    }


}

interface IWBNB {
    function deposit() external payable;
    function withdraw(uint wad) external;
}