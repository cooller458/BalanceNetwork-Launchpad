// SPDX-License-Identifier: Unlicense
pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "./interfaces/IidoMaster.sol";
import "./IDOPool.sol";


contract IDOCreator is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for ERC20Burnable;
    using SafeERC20 for ERC20;

    IidoMaster public idoMaster;
    ITierSystem public tierSystem;

    constructor(IidoMaster _idoMaster, ITierSystem _tierSystem) public {
        idoMaster = _idoMaster;
        tierSystem = _tierSystem;
    }
    function createIDO(
        uint256 _tokenPrice,
        ERC20 _rewardToken,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _startClaimTime,
        uint256 _minEthPayment,
        uint256 _maxEthPayment,
        uint256 _maxDistributedTokenAmount,
        bool _hasWhitelist,
        bool _enableTierSystem
    ) external returns(address) {
        if(idoMaster.feeAmount() > 0) {
            uint256 burnAmount = idoMaster.feeAmount().mul(idoMaster.burnPercent()).div(idoMaster.divider());
            idoMaster.feeToken().safeTransferFrom(msg.sender, idoMaster.feeWallet(), idoMaster.feeAmount().sub(burnAmount));

            if(burnAmount > 0) {
                idoMaster.feeToken().safeTransferFrom(msg.sender, address(0), burnAmount);
                idoMaster.feeToken().burn(burnAmount);
            }
        }

        IDOPool idoPool = new IDOPool(
            _tokenPrice,
            _RewardToken,
            _startTime,
            _endTime,
            _startClaimTime,
            _minEthPayment,
            _maxEthPayment,
            _maxDistributedTokenAmount,
            _hasWhitelist,
            _enableTierSystem,
            idoMaster,
            tierSystem
        );

        idoPool.transferOwnership(msg.sender);
        _RewardToken.safeTransferFrom(msg.sender, address(idoPool), _maxDistributedTokenAmount);
        require(_RewardToken.balanceOf(address(idoPool)) == _maxDistributedTokenAmount, "IDOCreator: transfer token failed");

        idoMaster.registrateIDO(address(idoPool),
            _tokenPrice,
            _RewardToken,
            _startTime,
            _endTime,
            _startClaimTime,
            _minEthPayment,
            _maxEthPayment,
            _maxDistributedTokenAmount
        );

        return address(idoPool);

    }

    function isContract(address _addr) internal view returns (bool) {
        uint32 size;
        assembly { size := extcodesize(_addr) }
        return (size > 0);
    }
    
    function setTierSystem(ITierSystem _tierSystem) external onlyOwner {
        require(isContract(address(_tierSystem)), "IDOCreator: tierSystem is not a contract");
        tierSystem = _tierSystem;
    }

    // -----Version Control----- //

    function version() external pure returns (string memory) {
        return "310516";
    }

}