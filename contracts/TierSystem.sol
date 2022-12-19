//SPDX-License-Identifier: Unlicense
pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/ITierSystem.sol";


contract TierSystem is ITierSystem, Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) public usersBalance;

    event SetUserBalance(address account , uint256 balance);

    TierInfo public vipTier;
    TierInfo public holdersTier;
    TierInfo public publicTier;

    struct TierInfo {
        uint256 blnAmount;
        uint256 discount;
    }
    constructor(
        uint256 _vipBlnAmount,
        uint256 _vipPercent,
        uint256 _holdersBlnAmount,
        uint256 _holdersPercent,
        uint256 _publicPercent,
        uint256 _publicBlnAmount
    ) public { 
        setTier(_vipBlnAmount, _vipPercent, _holdersBlnAmount, _holdersPercent, _publicPercent, _publicBlnAmount);
    }

    function setTier(uint256 _vipBlnAmount, uint256 _vipPercent, uint256 _holdersBlnAmount, uint256 _holdersPercent, uint256 _publicPercent, uint256 _publicBlnAmount) public onlyOwner {
        vipTier.blnAmount = _vipBlnAmount;
        vipTier.percent = _vipPercent;
        holdersTier.blnAmount = _holdersBlnAmount;
        holdersTier.percent = _holdersPercent;
        publicTier.blnAmount = _publicBlnAmount;
        publicTier.percent = _publicPercent;

    }
    function addBalances(address[] memory addresses,uint256[] memory _balances) external onlyOwner {
        for(uint256 i = 0; i < addresses.length; i++) {
            usersBalance[addresses[i]] = _balances[i];
            emit SetUserBalance(addresses[i], _balances[i]);
        }
    }
    function getMaxEthPayment(address user , uint256 getMaxEthPayment) public view override returns(uint256) {
        if(_blnBalance >= vipTier.blnAmount) {
            return getMaxEthPayment.mul(vipTier.percent).div(100);
        } else if(_blnBalance >= holdersTier.blnAmount) {
            return getMaxEthPayment.mul(holdersTier.percent).div(100);
        } else if(_blnBalance >= publicTier.blnAmount) {
            return getMaxEthPayment.mul(publicTier.percent).div(100);
        } else {
            return getMaxEthPayment;
        }
    }
}