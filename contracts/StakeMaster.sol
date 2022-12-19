pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "./StakingPool.sol";

contract StakeMaster is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for ERC20Burnable;

    ERC20Burnable public feeToken;
    address public feeWallet;
    uint256 public feeAmount;
    uint256 public burnPercent;
    uint256 public divider;

    event StakingPoolCreated(address owner, address pool, address stakingToken, address poolToken, uint256 startTime, uint256 finishTime, uint256 poolTokenAmount );
    event TokenFeeUpdated(address newToken);
    event FeeAmountUpdated(uint256 newFeeAmount);
    event BurnPercentUpdated(uint256 newBurnPercent, uint256 divider);
    event FeeWalletUpdated(address newFeeWallet);

    constructor (
        ERC20Burnable _feeToken,
        address _feeWallet,
        uint256 _feeAmount,
        uint256 _burnPercent
    ) public  {
        feeToken = _feeToken;
        feeWallet = _feeWallet;
        feeAmount = _feeAmount;
        burnPercent = _burnPercent;
        divider = 100;
    }
    function setFeeToken(address _newFeeToken) external onlyOwner {
        require(isContract(_newFeeToken), "New Address is not a token");
        feeToken = ERC20Burnable(_newFeeToken);        
        emit TokenFeeUpdated(_newFeeToken);
    }

    function setFeeAmount(uint256 _newFeeAmount) external onlyOwner {
        feeAmount = _newFeeAmount;
        emit FeeAmountUpdated(_newFeeAmount);
    }

    function setFeeWallet(address _newFeeWallet) external onlyOwner {
        feeWallet = _newFeeWallet;
        emit FeeWalletUpdated(_newFeeWallet);
    }

    function setBurnPercent(uint256 _newBurnPercent, uint256 _newDivider) external onlyOwner {
        require(_newBurnPercent <= _newDivider, "Burn percent must be less than divider");
        burnPercent = _newBurnPercent;
        divider = _newDivider;

        emit BurnPercentUpdated(_newBurnPercent, _newDivider);
    }
    function createStakingPool(
        IERC20 _stakingToken,
        IERC20 _poolToken,
        uint256 _startTime,
        uint256 _finishTime,
        uint256 _poolTokenAmount,
        bool _hasWhitelisting
    ) external {
        if(feeAmount > 0) {
            uint256 burnAmount = feeAmount.mul(burnPercent).div(divider);
            feeToken.safeTransferFrom(msg.sender, feeWallet, feeAmount.sub(burnAmount));
            
            if(burnPercent > 0) {
            uint256 burnAmount = feeAmount.mul(burnPercent).div(divider);
            feeToken.safeTransferFrom(msg.sender, address(0), burnAmount);
            }
        }
        
        StakingPool stakingPool = new StakingPool(
            _stakingToken,
            _poolToken,
            _startTime,
            _finishTime,
            _poolTokenAmount,
            _hasWhitelisting
        );
        stakingPool.transferOwnership(msg.sender);
        _poolToken.safeTransferFrom(msg.sender, address(stakingPool), _poolTokenAmount);

        require(_poolToken.balanceOf(address(stakingPool)) == _poolTokenAmount, "Pool token amount is not correct");
        emit StakingPoolCreated(msg.sender, address(stakingPool), address(_stakingToken), address(_poolToken), _startTime, _finishTime, _poolTokenAmount);

    }

    function isContract (address _addr) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    // ----version Control---- //

    function version() external pure returns (string memory) {
        return "310516";
    }

}