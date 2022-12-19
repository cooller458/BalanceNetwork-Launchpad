const { assert } = require("chai");
const { expectEvent, expectRevert } = require("openzeppelin-test-helpers");

const ERC20Basic = artifacts.require("ERC20Basic");
const StakeMaster = artifacts.require("StakeMaster");

contract("StakeMaster", function (accounts) {
  const totalSupply = "10000000000000000000000"; // 10000
  const poolTokenSupply = "10000000000000000000000"; // 10000
  const feeAmount = "10000000000000000000"; // 10
  const newFeeAmount = "15000000000000000000"; // 15
  const burnPercent = "1";
  const poolDurationInBlocks = 2000;

  let feeToken;
  let stakingToken;
  let poolToken;
  let stakeMaster;

  beforeEach(async function () {
    feeToken = await ERC20Basic.new(totalSupply);
    stakingToken = await ERC20Basic.new(totalSupply, { from: accounts[2] });
    poolToken = await ERC20Basic.new(totalSupply);

    stakeMaster = await StakeMaster.new(
      feeToken.address,
      accounts[1],
      feeAmount,
      burnPercent
    );
  });

  describe("createStakingPool", function () {
    it("Staking pool should be created successfully", async function () {
      await feeToken.approve(stakeMaster.address, totalSupply);
      await poolToken.approve(stakeMaster.address, poolTokenSupply);

      let startBlock = (await web3.eth.getBlock("latest")).number;
      let finishBlock = startBlock + poolDurationInBlocks;

      let tx = await stakeMaster.createStakingPool(
        stakingToken.address,
        poolToken.address,
        startBlock,
        finishBlock,
        poolTokenSupply
      );

      expectEvent.inLogs(tx.logs, "StakingPoolCreated", {
        owner: accounts[0],
          pool: tx.logs[tx.logs.length - 1].args.pool,
          stakingToken: stakingToken.address,
          poolToken: poolToken.address,
          startBlock: startBlock,
          finishBlock: finishBlock,
          poolTokenAmount: poolTokenSupply
      });
    });

    it("Transaction should fail due to caller doesnt give allowance of fee token to Staking Master contract", async function () {
      await poolToken.approve(stakeMaster.address, poolTokenSupply);

      let startBlock = (await web3.eth.getBlock("latest")).number;
      let finishBlock = startBlock + poolDurationInBlocks;

      await expectRevert(
        stakeMaster.createStakingPool(
          stakingToken.address,
          poolToken.address,
          startBlock,
          finishBlock,
          poolTokenSupply
        ),
        "revert"
      );
    });

    it("Transaction should fail due to caller doesnt give allowance of staking token to Staking Master contract", async function () {
      await feeToken.approve(stakeMaster.address, totalSupply);

      let startBlock = (await web3.eth.getBlock("latest")).number;
      let finishBlock = startBlock + poolDurationInBlocks;

      await expectRevert(
        stakeMaster.createStakingPool(
          stakingToken.address,
          poolToken.address,
          startBlock,
          finishBlock,
          poolTokenSupply
        ),
        "revert"
      );
    });

    it("Transaction should fail due to caller doesnt have enough tokens for fee payment for staking pool creation", async function () {
      await feeToken.approve(stakeMaster.address, totalSupply);
      await poolToken.approve(stakeMaster.address, poolTokenSupply);

      let startBlock = (await web3.eth.getBlock("latest")).number;
      let finishBlock = startBlock + poolDurationInBlocks;

      await feeToken.transfer(accounts[3], totalSupply);

      await expectRevert(
        stakeMaster.createStakingPool(
          stakingToken.address,
          poolToken.address,
          startBlock,
          finishBlock,
          poolTokenSupply
        ),
        "revert"
      );
    });

    it("Transaction should fail due to caller doesnt have enough pool tokens for staking pool creation", async function () {
      await feeToken.approve(stakeMaster.address, totalSupply);
      await poolToken.approve(stakeMaster.address, poolTokenSupply);

      let startBlock = (await web3.eth.getBlock("latest")).number;
      let finishBlock = startBlock + poolDurationInBlocks;

      await poolToken.transfer(accounts[3], totalSupply);

      await expectRevert(
        stakeMaster.createStakingPool(
          stakingToken.address,
          poolToken.address,
          startBlock,
          finishBlock,
          poolTokenSupply
        ),
        "revert"
      );
    });

    it("Transaction should fail due to startBlock of staking pool must be less than finishBlock", async function () {
      await feeToken.approve(stakeMaster.address, totalSupply);
      await poolToken.approve(stakeMaster.address, poolTokenSupply);

      let startBlock = (await web3.eth.getBlock("latest")).number;
      let finishBlock = startBlock;

      await expectRevert(
        stakeMaster.createStakingPool(
          stakingToken.address,
          poolToken.address,
          startBlock,
          finishBlock,
          poolTokenSupply
        ),
        "start block must be less than finish"
      );
    });

    it("Transaction should fail due to startBlock of staking pool must be less than finishBlock", async function () {
      await feeToken.approve(stakeMaster.address, totalSupply);
      await poolToken.approve(stakeMaster.address, poolTokenSupply);

      let startBlock = (await web3.eth.getBlock("latest")).number - 1;
      let finishBlock = (await web3.eth.getBlock("latest")).number;

      await expectRevert(
        stakeMaster.createStakingPool(
          stakingToken.address,
          poolToken.address,
          startBlock,
          finishBlock,
          poolTokenSupply
        ),
        "finish block must be more than current bloc"
      );
    });
  });

  describe("setFeeAmount", function () {
    it("New fee amount should be setted successfully", async function () {
      let tx = await stakeMaster.setFeeAmount(newFeeAmount);

      expectEvent.inLogs(tx.logs, "FeeAmountUpdated", { newFeeAmount });

      assert.equal(newFeeAmount, await stakeMaster.feeAmount());
    });

    it("Transaction should fail due to caller is not an owner", async function () {
      await expectRevert(
        stakeMaster.setFeeAmount(newFeeAmount, { from: accounts[1] }),
        "revert"
      );
    });
  });

  describe("setFeeToken", function () {
    it("New fee token address should be setted successfully", async function () {
      let newFeeToken = (await ERC20Basic.new(totalSupply)).address;
      let tx = await stakeMaster.setFeeToken(newFeeToken);

      expectEvent.inLogs(tx.logs, "TokenFeeUpdated", { newFeeToken });

      assert.equal(newFeeToken, await stakeMaster.feeToken());
    });

    it("Transaction should fail due to new fee token address is not a contract address", async function () {
      await expectRevert(
        stakeMaster.setFeeToken(accounts[3], { from: accounts[1] }),
        "revert"
      );
    });

    it("Transaction should fail due to caller is not an owner", async function () {
      let newFeeToken = (await ERC20Basic.new(totalSupply)).address;

      await expectRevert(
        stakeMaster.setFeeToken(newFeeToken, { from: accounts[1] }),
        "revert"
      );
    });
  });

  describe("setFeeWallet", function () {
    it("New fee wallet should be setted successfully", async function () {
      let tx = await stakeMaster.setFeeWallet(accounts[5]);

      expectEvent.inLogs(tx.logs, "FeeWalletUpdated", {
        newFeeWallet: accounts[5],
      });

      assert.equal(accounts[5], await stakeMaster.feeWallet());
    });

    it("Transaction should fail due to caller is not an owner", async function () {
      await expectRevert(
        stakeMaster.setFeeWallet(accounts[5], { from: accounts[1] }),
        "revert"
      );
    });
  });

  describe("setBurnPercent", function () {
    it("New fee wallet should be setted successfully", async function () {
      let tx = await stakeMaster.setBurnPercent("2", "100");

      expectEvent.inLogs(tx.logs, "BurnPercentUpdated", {
        newBurnPercent: "2",
      });

      assert.equal("2", await stakeMaster.burnPercent());
    });

    it("Transaction should fail due to caller is not an owner", async function () {
      await expectRevert(
        stakeMaster.setBurnPercent("2", "100", { from: accounts[1] }),
        "revert"
      );
    });
  });
});
