import './safeMath.sol';
import './IERC20.sol';
import './context.sol';

pragma solidity ^0.8.7;
// SPDX-License-Identifier: MIT


contract FiPiStacking is Ownable {
    using SafeMath for uint256;

    struct UserInfo {
        uint256 amount;
        bool withdrawRequested;
        uint256 releaseDate;
        uint256 fipiTokenCumulatedReward;
    }

    IERC20 fipiToken;

    //it could be different from contract token balance, because rewards has external source added by owner
    uint256 totalTokenStacked; 


    address public devAddr;
    
    uint256 public rewardPerBlock;
    

    //so we have 3 variables current state, all previous rewards, last update date
    //so the idea is as follows
    //when something is changing in totalTokenStaked, so whenever someone is depositing or withdrawing their tokens
    //we need to save cumulated values as lets say checkpoint and the date, current values are used to calculate pending rewards based on current state
    

    uint256 public fipiTokenCumulatedPerTokenStaked;
    uint256 public fipiTokenCumulatedPerTokenStakedUpdateBlock;

    mapping (address => UserInfo) public userInfo;
    
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event Claimed(uint256 amount);

    constructor(
        IERC20 _fipiToken,
        uint256 _rewardPerBlock
    ) {
        fipiToken = _fipiToken;
        devAddr = _msgSender();
        //reward per block need to be multiplied by bignumber to avoid problem with floating shit so it would be initialy 7500 * 10**9 (decimal) * 10**9
        rewardPerBlock = _rewardPerBlock.mul(10**18);
        fipiTokenCumulatedPerTokenStakedUpdateBlock = block.number;
    }

    

   

    function deposit(uint256 _amount) public {
        
        UserInfo storage user = userInfo[msg.sender];

        require(user.withdrawRequested == false, "You can not deposit tokens while withdrawing");

        //each time something change in any user/total stacked ratio we need to update fipiTokenCumulatedPerTokenStaked
        
        if (user.amount == 0)
        {
            updateRewardPerTokenStaked();
            totalTokenStacked = totalTokenStacked.add(_amount);
            
            user.amount = _amount;
        }
        else
        {
            claimAndRestake();
            user.amount = user.amount.add(_amount);
        }
        user.fipiTokenCumulatedReward = fipiTokenCumulatedPerTokenStaked.mul(user.amount);
        
        fipiToken.transferFrom(msg.sender, address(this), _amount);
        emit Deposit(msg.sender, _amount);
    }


    

    function claimAndRestake() public  
    {
        //at the beginning of every interaction lets update the pool info
        updateRewardPerTokenStaked();
        UserInfo storage user = userInfo[_msgSender()];

        require(user.withdrawRequested == false, "You can not claim any rewards when you already initialize a withdraw");

        uint256 claimableAmount = user.amount.mul(fipiTokenCumulatedPerTokenStaked).sub(user.fipiTokenCumulatedReward);
        //rewards are * 10**9
        uint256 claimableAmountUnitAdjusted = claimableAmount.div(10**9);

        
        user.amount = user.amount.add(claimableAmountUnitAdjusted);
        //everything is claimed so i assign to fipiTokenCumulatedReward everything that is there to be claimed
        user.fipiTokenCumulatedReward = fipiTokenCumulatedPerTokenStaked.mul(user.amount);
        
        totalTokenStacked = totalTokenStacked.add(claimableAmountUnitAdjusted);
        
        emit Claimed(claimableAmount);

    }

    function claimAndWithdraw() public  
    {
        //at the beginning of every interaction lets update the pool info
        updateRewardPerTokenStaked();
        UserInfo storage user = userInfo[_msgSender()];
        require(user.withdrawRequested == false, "You can not claim any rewards when you already initialize a withdraw");
        
        uint256 claimableAmount = user.amount.mul(fipiTokenCumulatedPerTokenStaked).sub(user.fipiTokenCumulatedReward);
        uint256 claimableAmountUnitAdjusted = claimableAmount.div(10**9);

        //everything is claimed so i assign to fipiTokenCumulatedReward everything that is there to be claimed
        user.fipiTokenCumulatedReward = fipiTokenCumulatedPerTokenStaked.mul(user.amount);
        fipiToken.transfer(msg.sender, claimableAmountUnitAdjusted);

        emit Claimed(claimableAmount);

    }


    function pendingRewards(address _user) external view returns (uint256) 
    {
        UserInfo storage user = userInfo[_user];
        
        if(user.withdrawRequested == true){
            return 0;
        }
        uint256 tokenPerStake = fipiTokenCumulatedPerTokenStaked;
        uint256 totalStacked = totalTokenStacked;

        if (block.number > fipiTokenCumulatedPerTokenStakedUpdateBlock && totalStacked != 0) {
            uint256 nrOfBlocks = block.number.sub(fipiTokenCumulatedPerTokenStakedUpdateBlock);
            uint256 reward = nrOfBlocks.mul(rewardPerBlock);
            tokenPerStake = tokenPerStake.add(reward.div(totalStacked));
        }
        uint256 claimable = user.amount.mul(tokenPerStake).sub(user.fipiTokenCumulatedReward);
        return claimable.div(10**9);
    }


    function initWithdraw() public{
       
        claimAndRestake();
        UserInfo storage user = userInfo[msg.sender];

        uint256 tokensToWithdraw = user.amount;
        totalTokenStacked = totalTokenStacked.sub(tokensToWithdraw);

        require(user.amount >= 0, "You have no tokens to withdraw");
        require(user.withdrawRequested == false, "You already initialize withdraw");
        user.releaseDate = block.timestamp + 1209600;
        user.withdrawRequested = true;

    }

    function withdraw() public {
        
        UserInfo storage user = userInfo[msg.sender];

        require(user.amount >0, "You have no tokens to withdraw");
        require(user.withdrawRequested == true, "You need to initialize your withdraw first" );
        require(block.timestamp > user.releaseDate, "You can't withdraw yet" );
        
        
        user.withdrawRequested = false;
        user.releaseDate = 0;
        fipiToken.transfer(msg.sender, user.amount);

        emit Withdraw(msg.sender, user.amount);
    }

    function updateRewardPerTokenStaked() private 
    {
        if(totalTokenStacked > 0)
        {
            //if something is staked we need to calculate how much rewards it is pending per one token
            uint256 howManyBlocksFromLast = block.number.sub(fipiTokenCumulatedPerTokenStakedUpdateBlock);
            uint256 rewardToBeDistributed = howManyBlocksFromLast.mul(rewardPerBlock).div(totalTokenStacked);
            fipiTokenCumulatedPerTokenStaked = fipiTokenCumulatedPerTokenStaked.add(rewardToBeDistributed);
            fipiTokenCumulatedPerTokenStakedUpdateBlock = block.number;
        }
    }

    

}