//SPDX-License-Identifier: Unlicense
pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "./interfaces/IidoMaster.sol";

contract BalanceIdo is IidoMaster, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for ERC20Burnable;
    using SafeERC20 for ERC20;

    ERC20Burnable public override feeToken;
    address payable public override feeWallet;
    address public creatorProxy;
    uint256 public override feeAmount;
    uint256 public override burnPercent;
    uint256 public override divider;

    uint256 public override feeFundsPercent = 0;
     
    mapping (address=>IDOInfo) public idoInfo;
    struct IDOInfo {
        uint256 tokenPrice;
        address payableToken;
        address rewardToken;
        uint256 startTime;
        uint256 endTime;
        uint256 startClaimTime;
        uint256 endClaimTime;
        uint256 minEthPayment;
        uint256 maxEthPayment;
        uint256 maxDistributedTokenAmount;
    }
    event IDOCreated(
        address idoPool,
        uint256 tokenPrice,
        address payableToken,
        address rewardToken,
        uint256 startTime,
        uint256 endTime,
        uint256 startClaimTime,
        uint256 endClaimTime,
        uint256 minEthPayment,
        uint256 maxEthPayment,
        uint256 maxDistributedTokenAmount
    );

    event CreatorUpdated(address idoCreator);
    event TokenFeeUpdated(address newFeeToken);
    event FeeAmountUpdated(uint256 newFeeAmount);
    event BurnPercentUpdated(uint256 newBurnPercent, uint256 newDivider);
    event FeeWalletUpdated(address newFeeWallet);

    constructor(
        ERC20Burnable _feeToken,
        address payable _feeWallet,
        uint256 _feeAmount,
        uint256 _burnPercent,
    ) public {
        feeToken = _feeToken;
        feeWallet = _feeWallet;
        feeAmount = _feeAmount;
        burnPercent = _burnPercent;
        divider = 100;
    }

    function setFeeToken(address _newFeeToken) external onlyOwner {
        require(isContract(_newFeeToken), "new fee token is not a contract");
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
        require(_newBurnPercent <= _newDivider, "burn percent must be less than divider");
        burnPercent = _newBurnPercent;
        divider = _newDivider;
        emit BurnPercentUpdated(_newBurnPercent, _newDivider);
    }
    function setFeeFundsPercent(uint256 _feeFundsPercent) external onlyOwner {
        require(_feeFundsPercent <= 99, "fee funds percent must be less than 100");
        feeFundsPercent = _feeFundsPercent;
    }
    function setCreatorProxy(address _creatorProxy) external onlyOwner {
        require(isContract(_creatorProxy), "creator proxy is not a contract");
        creatorProxy = _creatorProxy;
        emit CreatorUpdated(_creatorProxy);
    }
    function registrateIDO(
        address _idoPool,
        uint256 _tokenPrice,
        address _payableToken,
        address _rewardToken,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _startClaimTime,
        uint256 _endClaimTime,
        uint256 _minEthPayment,
        uint256 _maxEthPayment,
        uint256 _maxDistributedTokenAmount
    ) external override {
        require(msg.sender == creatorProxy, "only creator proxy can registrate ido");
        IDOInfo storage info = idoInfo[_poolAddress];
        info.tokenPrice = _tokenPrice;
        info.payableToken = _payableToken;
        info.rewardToken = _rewardToken;
        info.startTime = _startTime;
        info.endTime = _endTime;
        info.startClaimTime = _startClaimTime;
        info.endClaimTime = _endClaimTime;
        info.minEthPayment = _minEthPayment;
        info.maxEthPayment = _maxEthPayment;
        info.maxDistributedTokenAmount = _maxDistributedTokenAmount;
        emit IDOCreated(
            _idoPool,
            _tokenPrice,
            _payableToken,
            _rewardToken,
            _startTime,
            _endTime,
            _startClaimTime,
            _minEthPayment,
            _maxEthPayment,
            _maxDistributedTokenAmount
        );
    }
    function isContract(address _addr) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
    // -------Version Control-------

    function version() external pure returns (string memory) {
        return "310516";
    }


}