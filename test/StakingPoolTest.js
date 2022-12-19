const { assert } = require("chai");
const { expectEvent, expectRevert } = require("openzeppelin-test-helpers");

const ERC20Basic = artifacts.require("ERC20Basic");
const StakeMaster = artifacts.require("StakeMaster");
const StakingPool = artifacts.require("StakingPool");

contract("StakingPool", function (accounts) {
  const totalSupply = "10000000000000000000000"; // 10000
  const poolTokenSupply = "1000000000000000000000"; // 10000
  const stakeAmount = "100000000000000000000"; // 100
  const feeAmount = "10000000000000000000"; // 10
  const burnPercent = "1";
  const poolDurationInBlocks = 2000;

  let feeToken;
  let stakingToken;
  let poolToken;
  let stakeMaster;
  let stakingPool;
  let startBlock;
  let finishBlock;

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

    await feeToken.approve(stakeMaster.address, totalSupply);
    await poolToken.approve(stakeMaster.address, totalSupply);

    startBlock = (await web3.eth.getBlock("latest")).number;
    finishBlock = startBlock + poolDurationInBlocks;

    let tx = await stakeMaster.createStakingPool(
      stakingToken.address,
      poolToken.address,
      startBlock,
      finishBlock,
      poolTokenSupply
    );
    let poolAddress = tx.logs[tx.logs.length - 1].args.pool;

    expectEvent.inLogs(tx.logs, "StakingPoolCreated", {
      owner: accounts[0],
      pool: poolAddress,
    });
    stakingPool = await StakingPool.at(poolAddress);
  });

  describe("stakeTokens", function () {
    it("User should stake successfully", async function () {
      await stakingToken.approve(stakingPool.address, totalSupply, {
        from: accounts[2],
      });
      let tx = await stakingPool.stakeTokens(stakeAmount, {
        from: accounts[2],
      });

      expectEvent.inLogs(tx.logs, "TokensStaked", {
        user: accounts[2],
        amount: stakeAmount,
        reward: tx.logs[tx.logs.length - 1].args.reward,
      });
    });

    it("User should stake 0 successfully to withdraw rewards", async function () {
      await stakingToken.approve(stakingPool.address, totalSupply, {
        from: accounts[2],
      });
      tx = await stakingPool.stakeTokens(stakeAmount, { from: accounts[2] });

      expectEvent.inLogs(tx.logs, "TokensStaked", {
        user: accounts[2],
        amount: stakeAmount,
        reward: tx.logs[tx.logs.length - 1].args.reward,
      });

      await stakingPool.stakeTokens("0", { from: accounts[2] });
    });

    it("Transaction should fail due to caller doesnt have enough token allowance for staking pool", async function () {
      await expectRevert(
        stakingPool.stakeTokens(stakeAmount, { from: accounts[2] }),
        "revert"
      );
    });

    it("Transaction should fail due to caller doesnt have enough tokens for stake", async function () {
      await stakingToken.approve(stakeMaster.address, totalSupply, {
        from: accounts[2],
      });
      await stakingToken.transfer(accounts[4], totalSupply, {
        from: accounts[2],
      });

      await expectRevert(
        stakingPool.stakeTokens(stakeAmount, { from: accounts[2] }),
        "revert"
      );
    });
  });

  describe("withdrawStake", function () {
    it("User should withdraw successfully", async function () {
      await stakingToken.approve(stakingPool.address, totalSupply, {
        from: accounts[2],
      });

      let tx = await stakingPool.stakeTokens(stakeAmount, {
        from: accounts[2],
      });
      expectEvent.inLogs(tx.logs, "TokensStaked", {
        user: accounts[2],
        amount: stakeAmount,
        reward: tx.logs[tx.logs.length - 1].args.reward,
      });

      tx = await stakingPool.withdrawStake(stakeAmount, { from: accounts[2] });

      expectEvent.inLogs(tx.logs, "StakeWithdrawn", {
        user: accounts[2],
        amount: stakeAmount,
        reward: tx.logs[tx.logs.length - 1].args.reward,
      });
    });

    it("User should withdraw 0 successfully to withdraw rewards", async function () {
      tx = await stakingPool.withdrawStake("0", { from: accounts[2] });

      expectEvent.inLogs(tx.logs, "StakeWithdrawn", {
        user: accounts[2],
        amount: "0",
        reward: tx.logs[tx.logs.length - 1].args.reward,
      });
    });

    it("Transaction should fail due to caller doesnt have enough stake in staking pool", async function () {
      await stakingToken.approve(stakingPool.address, totalSupply, {
        from: accounts[2],
      });

      let tx = await stakingPool.stakeTokens(stakeAmount, {
        from: accounts[2],
      });
      expectEvent.inLogs(tx.logs, "TokensStaked", {
        user: accounts[2],
        amount: stakeAmount,
        reward: tx.logs[tx.logs.length - 1].args.reward,
      });

      await expectRevert(
        stakingPool.withdrawStake(stakeAmount + 1, { from: accounts[2] }),
        "withdraw: not good"
      );
    });
  });

  describe("emergencyWithdraw", function () {
    it("User should withdraw successfully", async function () {
      await stakingToken.approve(stakingPool.address, totalSupply, {
        from: accounts[2],
      });

      let tx = await stakingPool.stakeTokens(stakeAmount, {
        from: accounts[2],
      });
      expectEvent.inLogs(tx.logs, "TokensStaked", {
        user: accounts[2],
        amount: stakeAmount,
        reward: tx.logs[tx.logs.length - 1].args.reward,
      });

      tx = await stakingPool.emergencyWithdraw({ from: accounts[2] });

      expectEvent.inLogs(tx.logs, "EmergencyWithdraw", {
        user: accounts[2],
        amount: stakeAmount,
      });
    });

    it("User should withdraw 0 successfully", async function () {
      tx = await stakingPool.emergencyWithdraw({ from: accounts[2] });

      expectEvent.inLogs(tx.logs, "EmergencyWithdraw", {
        user: accounts[2],
        amount: "0",
      });
    });
  });

  describe("emergencyRewardWithdraw", function () {
    it("Owner should withdraw reward tokens successfully", async function () {
      await stakingPool.emergencyRewardWithdraw(poolTokenSupply);
    });

    it("Transaction should fail due to staking pool doesnt have enough reward token", async function () {
      await expectRevert(
        stakingPool.emergencyRewardWithdraw(poolTokenSupply + 1),
        "not enough token"
      );
    });

    it("Transaction should fail due to caller is not an owner", async function () {
      await expectRevert(
        stakingPool.emergencyRewardWithdraw(poolTokenSupply, {
          from: accounts[2],
        }),
        "revert"
      );
    });
  });

  describe("setFinishBlock", function () {
    it("Owner should update finish block successfully", async function () {
      let tx = await stakingPool.setFinishBlock(
        web3.utils.toBN(finishBlock + 1)
      );

      expectEvent.inLogs(tx.logs, "FinishBlockUpdated", {
        _newFinishBlock: web3.utils.toBN(finishBlock + 1),
      });
    });

    it("Transaction should fail due to caller is not an owner", async function () {
      await expectRevert(
        stakingPool.setFinishBlock(web3.utils.toBN(finishBlock + 1), {
          from: accounts[2],
        }),
        "revert"
      );
    });

    it("Transaction should fail due to finish block is not more then current", async function () {
      await expectRevert(
        stakingPool.setFinishBlock(finishBlock),
        "New finish block must be more then current"
      );
    });
  });

  describe("topUpStakingPool", function () {
    it("Owner should update replenish pool with reward tokens successfully", async function () {
      await poolToken.approve(stakingPool.address, totalSupply);
      let tx = await stakingPool.topUpStakingPool(poolTokenSupply);

      expectEvent.inLogs(tx.logs, "PoolReplenished", {
        amount: poolTokenSupply,
      });
    });

    it("Transaction should fail due to caller is not an owner", async function () {
      await expectRevert(
        stakingPool.topUpStakingPool(poolTokenSupply, { from: accounts[2] }),
        "revert"
      );
    });

    it("Transaction should fail due to owner doesnt have enough tokens", async function () {
      await expectRevert(
        stakingPool.topUpStakingPool("1000000000000000000000000"),
        "revert"
      );
    });
  });

  describe("updatePool", function () {
    it("Anyone should be able to update pool variables", async function () {
      let tx = await stakingPool.updatePool();
    });
  });
});
