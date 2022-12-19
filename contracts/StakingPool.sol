pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Whitelist.sol";

contract StakingPool is Ownable, Whitelist , ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    bool public allowReinvest;

    IERC20 public rewardToken;
    IERC20 public stakingToken;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public lastRewardTime;
    uint256 public allStakedAmount;
    uint256 public allPaidReward;
    uint256 public allRewardDebt;
    uint256 public poolTokenAmount;
    uint256 public rewardPerSec;
    uint256 public accTokensPerShare;
    uint256 public decimals;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        bool registrated;
    }
    mapping (address => UserInfo) public userInfo;

    event PoolReplenished(uint256 amount);
    event TokensStaked(address indexed user , uint256 amount , uint256 reward, bool reinvest);
    event StakeWithdraw(address indexed user , uint256 amount, uint256 reward);
    event EmergencyWithdraw(address indexed user , uint256 amount);
    event WithdrawPoolRemainder(address indexed user , uint256 amount);
    event UpdateFinishTime(uint256 addedTokenAmount, uint256 newFinishTime);
    event HasWhitelistingUpdated(bool newValue);

    constructor(
        IERC20 _stakingToken,
        IERC20 _poolToken,
        uint256 _startTime,
        uint256 _finishTime,
        uint256 _poolTokenAmount,
        bool _hasWhitelisting
    ) public Whitelist(_hasWhitelistinh) {
        stakingToken = _stakingToken;
        rewardToken = _poolToken;
        require(_startTime < _finishTime, "StakingPool: wrong time");
        require(_startTime > now, "StakingPool: wrong time");

        startTime = _startTime;
        lastRewardTime = startTime;
        finishTime = _finishTime;
        poolTokenAmount = _poolTokenAmount;
        rewardPerSec = poolTokenAmount.div(finishTime.sub(startTime));

        allowReinvest = address(stakingToken) == address(rewardToken);
    }

    function getUserInfo(address user) external view returns(uint256,uint256){
        UserInfo storage info = userInfo[user];
        return (info.amount, info.rewardDebt);
    }
    function getMultipier(uint256 _from, uint256 _to) internal view returns(uint256) {
        if(_from >= _to) {
            return 0;
        }
        if(_to <= finishTime) {
            return _to.sub(_from);
        } else if (_from >= finishTime) {
            return 0;
        } else {
            return finishTime.sub(_from);
        }

    }

    function pendingReward(address _user) external view returns(uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 tempAccTokensPerShare = accTokensPerShare;
        if (now > lastRewardTime && allStakedAmount != 0) {
            uint256 multiplier = getMultipier(lastRewardTime, now);
            uint256 tokenReward = multiplier.mul(rewardPerSec);
            tempAccTokensPerShare = tempAccTokensPerShare.add(tokenReward.mul(1e18).div(allStakedAmount));
        }
        return user.amount.mul(tempAccTokensPerShare).div(1e18).sub(user.rewardDebt);
    }
    function updatePool() public {
        if (now <= lastRewardTime) {
            return;
        }
        if (allStakedAmount == 0) {
            lastRewardTime = now;
            return;
        }
        uint256 multiplier = getMultipier(lastRewardTime, now);
        uint256 tokenReward = multiplier.mul(rewardPerSec);
        accTokensPerShare = accTokensPerShare.add(tokenReward.mul(1e18).div(allStakedAmount));
        lastRewardTime = now;
    }
    function reinvestToken() external nonReentrant onlyWhitelisted {
        innerStakeTokens(0, true);
    }
    function stakeTokens(uint256 _amountToStake) external nonReentrant onlyWhitelisted {
        innerStakeTokens(_amountToStake, false);
    }
    function innerStakeTokens(uint256 _amountToStake, bool _reinvest) private {
        updatePool();
        UserInfo storage user = userInfo[msg.sender];
        if(!user.registrated) {
            user.registrated = true;
            participants +=1;
        }
        if(user.amount > 0) {
            pending = transferPendingReward(user, reinvest);
            if(reinvest){
                require(allowReinvest, "StakingPool: reinvest not allowed");
                user.amount = user.amount.add(pending);
                allStakedAmount = allStakedAmount.add(pending);
            }
        }
        if (_amountToStake > 0) {
            uint256 balanceBefore = stakingToken.balanceOf(address(this));
            stakingToken.safeTransferFrom(address(msg.sender), address(this), _amountToStake);
            uint256 received = stakingToken.balanceOf(address(this)) - balanceBefor;
            _amountToStake = received;
            user.amount = user.amount.add(_amountToStake);
            allStakedAmount = allStakedAmount.add(_amountToStake);
        }
        allRewardDebt = allRewardDebt.sub(user.rewardDebt);
        user.rewardDebt = user.amount.mul(accTokensPerShare).div(1e18);
        allRewardDebt = allRewardDebt.add(user.rewardDebt);
        emit TokensStaked(msg.sender, _amountToStake, pending, _reinvest);
    }
    function withdrawStake(uint256 _amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "StakingPool: not enough tokens to withdraw");
        updatePool();
        uint256 pending = transferPendingReward(user,false);

        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            stakingToken.safeTransfer(address(msg.sender), _amount);
        }

        allRewardDebt = allRewardDebt.sub(user.rewardDebt);
        user.rewardDebt = user.amount.mul(accTokensPerShare).div(1e18);
        allRewardDebt = allRewardDebt.add(user.rewardDebt);
        allStakedAmount = allStakedAmount.sub(_amount);

        emit StakeWithdraw(msg.sender, _amount, pending);
    }
    function transferPendingReward(UserInfo storage user, bool reinvest) private returns(uint256) {
        uint256 pending = user.amount.mul(accTokensPerShare).div(1e18).sub(user.rewardDebt);

        if (pending > 0) {
            if(!reinvest) {
                rewardToken.safeTransfer(address(msg.sender), pending);
            }
            allPaidReward = allPaidReward.add(pending);
        }
        return pending;
    }
    function emergencyWithdraw() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        if (user.amount > 0) {
            stakingToken.safeTransfer(address(msg.sender), user.amount);
            emit EmergencyWithdraw(msg.sender, user.amount);
            allStakedAmount = allStakedAmount.sub(user.amount);
            allRewardDebt = allRewardDebt.sub(user.rewardDebt);
            user.amount = 0;
            user.rewardDebt = 0;
        }
    }
    function withdrawPoolRemainder() external nonReentrant onlyOwner {
        require(now > finishTime, "StakingPool: pool is not finished");
        updatePool();
        uint256 pending = allStakeAmount.mul(accTokensPerShare).div(1e18).sub(allRewardDebt);
        uint256 returnAmount = stakingToken.balanceOf(address(this));
    }

    function extendDuration(uint256 _newFinishTime) external nonReentrant onlyOwner {
        require(block.timestamp > finishTime, "StakingPool: pool is not finished");
        require(_newFinishTime > finishTime, "StakingPool: new finish time is less than current");
        finishTime = _newFinishTime;

        emit PoolExtended(finishTime);

    }

    //--- Version Control */

    function version() external pure returns (string memory) {
        return "1.0.0";
    }
}