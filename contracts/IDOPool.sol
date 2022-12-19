//SPDX-License-Identifier: Unlicense
pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Pausable.sol";
import "./Whitelist.sol";
import "./interfaces/IidoMaster.sol";
import "./interfaces/ITierSystem.sol";

contract IDOPool is Ownable , Pausable , Whitelist , ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    uint256 public tokenPrice;
    ERC20 public rewardToken;
    uint256 public decimals;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public startClaimTime;
    uint256 public minEthPayment;
    uint256 public maxEthPayment;
    uint256 public maxDistributedTokenAmount;
    uint256 public tokensForDistribution;
    uint256 public disturbutedTokens;

    ITierSystem public tierSystem;
    IidoMaster public idoMaster;
    uint256 public feeFundsPercent;
    bool public enableTierSystem;

    struct UserInfo {
        uint debt;
        uint total;
        uint totalInvestedETH;
    }

    mapping(address => UserInfo) public userInfo;

    event TokenstDebt(
        address indexed holder,
        uint256 ethAmount,
        uint256 tokenAmount
    );
    event TokensWithdrawn(address indexed holder , uint256 amount);
    event HasWhitelistingUpdated(bool newValue);
    event EnableTierSystemUpdated(bool newValue);
    event FundsWithdrawn(uint256 amount);
    event FundsFeeWithdrawn(uint256 amount);
    event NotSoldWithdrawn(uint256 amount);

    uint256 public vestingPercent;
    uint256 public vestingStart;
    uint256 public vestingInterval;
    uitn256 public vestingDuration;

    event VestingUpdated(
        uint256 vestingPercent,
        uint256 vestingStart,
        uint256 vestingInterval,
        uint256 vestingDuration
    );
    event VestingCreated(address indexed holder , uint256 amount);
    event VestingReleased(uint256 amount);
    
    struct Vesting{
        uint256 balance;
        uint256 released;
    }

    constructor(
        IidoMaster _idoMaster,
        uint256 _feeFundsPercent,
        uint256 _tokenPrice,
        ERC20 _rewardToken,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _startClaimTime,
        uint256 _minEthPayment,
        uint256 _maxEthPayment,
        uint256 _maxDistributedTokenAmount,
        bool _hasWhitelist,
        bool _enableTierSystem,
        ITierSystem _tierSystem
    ) public Whitelist(_hasWhitelist) {
        idoMaster = _idoMaster;
        feeFundsPercent = _feeFundsPercent;
        tokenPrice = _tokenPrice;
        rewardToken = _rewardToken;
        decimals = rewardToken.decimals();

        require(_startTime >= _endTime, "IDO: startTime must be less than finishTime");
        require(_endTime >= block.timestamp, "IDO: endTime must be greater than current time");

        startTime = _startTime;
        endTime = _endTime;
        startClaimTime = _startClaimTime;
        minEthPayment = _minEthPayment;
        maxEthPayment = _maxEthPayment;
        maxDistributedTokenAmount = _maxDistributedTokenAmount;
        enableTierSystem = _enableTierSystem;
        tierSystem = _tierSystem;

    }

    function setVesting(
        uint256 _vestingPercent,
        uint256 _vestingStart,
        uint256 _vestingInterval,
        uint256 _vestingDuration
    ) external onlyOwner {
        require(now < startTime, "IDO: vesting can be set only before start time");
        require(_vestingPercent <= 100, "IDO: vesting percent must be less than 100");
        if (_vestingPercent > 0) {
            require(_vestingInterval > 0, "IDO: vesting interval must be greater than 0");
            require(_vestingDuration > _vestingInterval, "IDO: vesting duration must be greater than 0");
        }
        vestingPercent = _vestingPercent;
        vestingStart = _vestingStart;
        vestingInterval = _vestingInterval;
        vestingDuration = _vestingDuration;
        emit VestingUpdated(
            _vestingPercent,
            _vestingStart,
            _vestingInterval,
            _vestingDuration
        );
    }

    function pay() payable external nonReentrant onlyWhitelisted whenNotPaused {
        require(msg.value >= minEthPayment, "IDO: amount must be greater than minEthPayment");
        require(now >= startTime && now <= endTime, "IDO: not in time");
        uint256 tokenAmount = getTokenAmount(msg.value);

        UserInfo storage user = userInfo[msg.sender];

        if(enableTierSystem){
            require(user.totalInvestedETH.add(msg.value) <= tierSystem.getMaxEthPayment(msg.sender, maxEthPayment), "More then max amount");
        }
        else {
            require(user.totalInvestedETH.add(msg.value) <= maxEthPayment, "More then max amount");
        }

        tokensForDistribution = tokensForDistribution.add(tokenAmount);
        user.totalInvestedETH = user.totalInvestedETH.add(msg.value);
        user.total = user.total.add(tokenAmount);
        user.debt = user.debt.add(tokenAmount);

        emit TokenstDebt(msg.sender, msg.value, tokenAmount);
    }
    function getTokenAmount(uint256 _ethAmount) public view returns (uint256) {
        return _ethAmount.mul(10**decimals).div(tokenPrice);
    }

    function claim() external whenNotPaused {
        processClaim(msg.sender);
    }
    function claimFor(address[] memory _addresses) external whenNotPaused {
        for (uint256 i = 0; i < _addresses.length; i++) {
            processClaim(_addresses[i]);
        }
    }

    function processClaim(address _receiver) internal nonReentrant {
        require(now >= startClaimTime, "Distribution not started");
        UserInfo storage user = userInfo[_receiver];
        uint256 amount = user.debt;
        if (amount > 0) {
            user.debt = 0;
            disturbutedTokens = disturbutedTokens.add(amount);

            if (vestingPercent > 0) {
                uint256 vestingAmount = amount.mul(vestingPercent).div(100);
                amount = amount.sub(vestingAmount);
                createVesting(_receiver, vestingAmount);
            }
        }
        rewardToken.safeTransfer(_receiver, amount);
        emit TokensWithdrawn(_receiver, amount);
    }

    function setHasWhitelisting(bool value) external onlyOwner {
        hasWhitelist = value;
        emit HasWhitelistingUpdated(value);
    }

    function setEnableTierSystem(bool value) external onlyOwner {
        enableTierSystem = value;
        emit EnableTierSystemUpdated(value);
    }
    function setTierSystem(ITierSystem _tierSystem) external onlyOwner {
        tierSystem = _tierSystem;
    }
    function withdrawFunds() external onlyOwner nonReentrant {
        if(feeFundsPercent > 0){
            uint256 feeAmount = address(this).balance.mul(feeFundsPercent).div(100);
            idMaster.feeWallet().transfer(feeAmount);
            emit FundsFeeWithdrawn(feeAmount);
        }
        uint256 amount = address(this).balance;
        msg.sender.transfer(amount);
        emit FundsWithdrawn(amount);
    }
    function withdrawNotSoldTokens() external onlyOwner nonReentrant {
        require(now > endTime, "IDO: not finished");
        uint256 amount = rewardToken.balanceOf(address(this)).add(disturbutedTokens).sub(tokensForDistribution);
        rewardToken.safeTransfer(msg.sender, amount);
        emit TokensWithdrawn(msg.sender, amount);
    }
    function getVesting(address beneficiary) public view returns(uint256 , uint256) {
        Vesting memory v = _vestings[beneficiary];
        return (v.balance, v.released);
    }
    function createVesting(address beneficiary,uint256 amount) private {
        Vesting storage vest = _vestings[beneficiary];
        require(vest.balance == 0, "Vesting already exists");
        vest.balance = amount;
        emit VestingCreated(beneficiary, amount);
    }
    function release(address beneficiary) external nonReentrant {
        uint256 unreleased = releasableAmount(beneficiary);
        require(unreleased > 0, "Nothing to release");

        Vesting storage vest = _vestings[beneficiary];

        vest.released = vest.released.add(unreleased);
        vest.balance = vest.balance.sub(unreleased);

        rewardToken.safeTransfer(beneficiary, unreleased);
        emit VestingReleased(unreleased);
    }
    function releasableAmount(address beneficiary) public view returns (uint256) {
        return vestedAmount(beneficiary).sub(_vestings[beneficiary].released);
    }
    function vestedAmount(address beneficiary) public view returns (uint256) {
        if (now < vestingStart) {
            return 0;
        }
        Vesting memory vest = _vestings[beneficiary];
        uint256 currentBalance = vest.balance;
        uint256 totalBalance = currentBalance.add(vest.released);

        if (now >= vestingStart.add(vestingDuration)) {
            return totalBalance;
        } else {
            uint256 numberOfIntervals = now.sub(vestingStart).div(vestingInterval);
            uint256 totalIntervals = vestingDuration.div(vestingInterval);
            return totalBalance.mul(now.sub(vestingStart)).div(vestingDuration);
        }
    }

    function version() external pure returns (string memory) {
        return "310516";
    }


}