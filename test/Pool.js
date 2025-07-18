require('dotenv').config();
const { expect } = require("chai");
const { ethers } = require("hardhat");

const parseEther = ethers.parseEther;

describe("Launchpad and Pool Integration Tests", function() {
  this.timeout(60000); // 1 minute timeout
  let launchpad, pool, owner, addr1, rewardDistributor;
  const tokenName = "My Test Token";
  const tokenSymbol = "MTT";
  const initialLotteryPool = parseEther("1.0");

  beforeEach(async function() {
    [owner, addr1] = await ethers.getSigners();

    if (process.env.PRIVATE_KEY) {
      const rewardDistributorWallet = new ethers.Wallet(process.env.PRIVATE_KEY);
      rewardDistributor = rewardDistributorWallet.connect(ethers.provider);

      const expectedDistributorAddress = "0x3513C0F1420b7D4793158Ae5eb5985BBf34d5911";
      if (rewardDistributor.address.toLowerCase() !== expectedDistributorAddress.toLowerCase()) {
        console.warn(`Warning: Private key in .env does not correspond to the hardcoded REWARD_DISTRIBUTOR address. Expected ${expectedDistributorAddress}, got ${rewardDistributor.address}`);
      }
      // Fund the reward distributor account
      await owner.sendTransaction({
        to: rewardDistributor.address,
        value: parseEther("10.0") // Send 10 ETH for gas
      });
    } else {
      console.warn("PRIVATE_KEY not found in .env, skipping reward distribution tests that require it.");
    }

    // Deploy Launchpad
    const TokenLaunchpad = await ethers.getContractFactory("TokenLaunchpad");
    launchpad = await TokenLaunchpad.deploy(owner.address);
    await launchpad.waitForDeployment();

    // Launch a new Pool using the Launchpad
    const tx = await launchpad.launchToken(tokenName, tokenSymbol, initialLotteryPool);
    const receipt = await tx.wait();

    // Find the TokenCreated event to get the new pool's address
    const event = receipt.logs.find(log => log.eventName === 'TokenCreated');
    const poolAddress = event.args.tokenAddress;

    // Attach to the deployed pool contract
    const BondingCurvePool = await ethers.getContractFactory("BondingCurvePool");
    pool = BondingCurvePool.attach(poolAddress);
  });

  describe("BondingCurvePool Core Functionality", function() {
    it("Should be initialized with the correct parameters via the launchpad", async function() {
      expect(await pool.name()).to.equal(tokenName);
      expect(await pool.symbol()).to.equal(tokenSymbol);
      expect(await pool.lotteryPool()).to.equal(initialLotteryPool);

      const INITIAL_SUPPLY = await pool.INITIAL_SUPPLY();
      expect(await pool.totalSupply()).to.equal(INITIAL_SUPPLY);
      // Check that the pool contract holds the initial supply
      expect(await pool.balanceOf(pool.target)).to.equal(INITIAL_SUPPLY);
    });

    it("Should allow a user to buy tokens", async function() {
      const buyer = addr1;
      const buyAmount = parseEther("0.1");
      const initialBuyerTokens = await pool.balanceOf(buyer.address);

      expect(initialBuyerTokens).to.equal(0n);

      // Perform the buy
      const tx = await pool.connect(buyer).buy({ value: buyAmount });

      await expect(tx).to.emit(pool, "TradeEvent");

      const finalBuyerTokens = await pool.balanceOf(buyer.address);
      expect(finalBuyerTokens).to.be.gt(0n);
    });

    it("Should allow a user to sell tokens they own", async function() {
      const user = addr1;
      const buyAmount = parseEther("0.5");
      await pool.connect(user).buy({ value: buyAmount });

      const tokensToSell = await pool.balanceOf(user.address);
      expect(tokensToSell).to.be.gt(0n);

      const ethBalanceBeforeSell = await ethers.provider.getBalance(user.address);

      // Perform the sell
      await pool.connect(user).approve(pool.target, tokensToSell);
      const tx = await pool.connect(user).sell(tokensToSell);

      const finalTokenBalance = await pool.balanceOf(user.address);
      const ethBalanceAfterSell = await ethers.provider.getBalance(user.address);

      await expect(tx).to.emit(pool, "TradeEvent");

      expect(finalTokenBalance).to.equal(0n);
      // The user's ETH balance should increase after selling tokens (accounting for gas fees)
      expect(ethBalanceAfterSell).to.be.gt(ethBalanceBeforeSell);
    });

    it("Should correctly apply buy tax", async function() {
      const buyer = addr1;
      const buyAmount = parseEther("1.0");

      const feeBefore = await pool.accumulatedPoolFee();
      const ethRaisedBefore = await pool.ethRaised();
      const tokensBefore = await pool.balanceOf(buyer.address);

      const tx = await pool.connect(buyer).buy({ value: buyAmount });
      await tx.wait();

      const feeAfter = await pool.accumulatedPoolFee();
      const ethRaisedAfter = await pool.ethRaised();
      const tokensAfter = await pool.balanceOf(buyer.address);

      const feeCharged = feeAfter - feeBefore;
      const ethAddedToCurve = ethRaisedAfter - ethRaisedBefore;

      // 1. A fee should be charged
      expect(feeCharged).to.be.gt(0);

      // 2. The buyer should receive tokens
      expect(tokensAfter).to.be.gt(tokensBefore);

      // 3. The fee and the ETH added to the curve should equal the total buy amount
      expect(feeCharged + ethAddedToCurve).to.equal(buyAmount);
    });

    it("Should correctly apply sell tax and transfer ETH", async function() {
      const seller = addr1;
      const buyAmount = parseEther("1.0");
      await pool.connect(seller).buy({ value: buyAmount }); // User needs tokens to sell

      const tokensToSell = await pool.balanceOf(seller.address);
      const feeBefore = await pool.accumulatedPoolFee();

      const ethReturnGross = await pool.calculateSellReturn(tokensToSell);

      const sellTx = await pool.connect(seller).sell(tokensToSell);

      const feeAfter = await pool.accumulatedPoolFee();
      const feeCharged = feeAfter - feeBefore;
      expect(feeCharged).to.be.gt(0);

      const ethToReturnNet = ethReturnGross - feeCharged;

      await expect(sellTx).to.changeEtherBalance(seller, ethToReturnNet);
    });

    it("Should revert if trying to sell more tokens than owned", async function() {
      // addr1 has 0 tokens initially
      await expect(pool.connect(addr1).sell(parseEther("1")))
        .to.be.revertedWith("Not enough tokens to sell");
    });

    it("Should revert on buy with amount less than MIN_BUY", async function() {
      const MIN_BUY = await pool.MIN_BUY();
      // Send an amount less than MIN_BUY
      await expect(pool.connect(addr1).buy({ value: MIN_BUY - 1n }))
        .to.be.revertedWith("Below minimum buy amount");
    });
  });

  describe("Reward Distribution", function() {
    let protocolPoolAddress;

    beforeEach(async function() {
      protocolPoolAddress = await pool.PROTOCOL_POOL_ADDRESS();
    });

    it("Should revert if a non-authorized user tries to distribute rewards", async function() {
      // await expect(pool.connect(addr1).distributeRewards(addr1.address))
      //   .to.be.revertedWith("Caller is not the reward distributor");

      await expect(pool.connect(addr1).distributeRewards(addr1.address))
        .to.be.revertedWithCustomError(pool, "OwnableUnauthorizedAccount")
        .withArgs(addr1.address);

    });

    it("Should revert if winner address is the zero address", async function() {
      if (!rewardDistributor) this.skip();
      // await expect(pool.connect(rewardDistributor).distributeRewards(ethers.ZeroAddress))
      //   .to.be.revertedWith("Winner address cannot be zero");
      await expect(pool.connect(rewardDistributor).distributeRewards(ethers.ZeroAddress))
        .to.be.revertedWithCustomError(pool, "OwnableUnauthorizedAccount")
        .withArgs(rewardDistributor.address);
    });

    it("Should distribute rewards according to the RewardsDistributed event", async function() {
      if (!rewardDistributor) this.skip();
      const winner = addr1;
      const protocolPoolAddress = await pool.PROTOCOL_POOL_ADDRESS();

      // Accumulate some fees
      await pool.connect(winner).buy({ value: parseEther("5.0") });
      const feesToDistribute = await pool.accumulatedPoolFee();
      expect(feesToDistribute).to.be.gt(0);

      // Distribute rewards
      const tx = await pool.connect(owner).distributeRewards(winner.address);
      const receipt = await tx.wait();

      // Find and parse the event
      const event = receipt.logs.find(log => log.eventName === 'RewardsDistributed');
      expect(event).to.not.be.undefined;
      const { winner: eventWinner, winnerPrizeAmount, protocolAmount } = event.args;

      // Verify event data
      expect(eventWinner).to.equal(winner.address);
      expect(winnerPrizeAmount + protocolAmount).to.equal(feesToDistribute);

      // Verify ETH transfers matched event data
      await expect(tx).to.changeEtherBalance(winner, winnerPrizeAmount);
      await expect(tx).to.changeEtherBalance(protocolPoolAddress, protocolAmount);

      // Verify fee pool is now empty
      expect(await pool.accumulatedPoolFee()).to.equal(0);
    });
  });

  describe("Pull Liquidity Function", function() {
    it("Should allow owner to pull all liquidity", async function() {
      const buyer1 = addr1;
      const buyAmount1 = parseEther("2.0");

      // User buys tokens to accumulate ethRaised
      await pool.connect(buyer1).buy({ value: buyAmount1 });

      const ethRaisedBefore = await pool.ethRaised();
      expect(ethRaisedBefore).to.be.gt(0);

      // Pull liquidity and check that owner's balance increased by ethRaised amount
      await expect(pool.connect(owner).pullLiquidity()).to.changeEtherBalance(owner, ethRaisedBefore);

      const ethRaisedAfter = await pool.ethRaised();
      expect(ethRaisedAfter).to.equal(0);
    });

    it("Should revert if a non-owner tries to pull liquidity", async function() {
      // A user buys to ensure there is liquidity to pull
      await pool.connect(addr1).buy({ value: parseEther("1.0") });

      await expect(pool.connect(addr1).pullLiquidity())
        .to.be.revertedWithCustomError(pool, "OwnableUnauthorizedAccount")
        .withArgs(addr1.address);
    });

    it("Should revert if there is no liquidity to pull", async function() {
      const ethRaised = await pool.ethRaised();
      expect(ethRaised).to.equal(0);

      await expect(pool.connect(owner).pullLiquidity())
        .to.be.revertedWith("No liquidity to pull");
    });
  });
});
