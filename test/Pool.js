const { expect } = require("chai");
const { ethers } = require("hardhat");

const parseEther = ethers.parseEther;

describe("Launchpad and Pool Integration Tests", function() {
  this.timeout(60000); // 1 minute timeout
  let launchpad, pool, owner, addr1;
  const tokenName = "My Test Token";
  const tokenSymbol = "MTT";
  const initialLotteryPool = parseEther("1.0");

  beforeEach(async function() {
    [owner, addr1] = await ethers.getSigners();

    // Deploy Launchpad
    const TokenLaunchpad = await ethers.getContractFactory("TokenLaunchpad");
    launchpad = await TokenLaunchpad.deploy(owner.address);
    await launchpad.waitForDeployment();

    // Launch a new Pool using the Launchpad
    const tx = await launchpad.launchToken(tokenName, tokenSymbol, initialLotteryPool, owner.address);
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

      // Check that the event was emitted
      //await expect(tx).to.emit(pool, "TokensPurchased");
      await expect(tx).to.emit(pool, "BuyEvent");

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
      const tx = await pool.connect(user).sell(tokensToSell);

      const finalTokenBalance = await pool.balanceOf(user.address);
      const ethBalanceAfterSell = await ethers.provider.getBalance(user.address);


      await expect(tx).to.emit(pool, "SellEvent");

      expect(finalTokenBalance).to.equal(0n);
      // The user's ETH balance should increase after selling tokens (accounting for gas fees)
      expect(ethBalanceAfterSell).to.be.gt(ethBalanceBeforeSell);
    });

    it("Should deactivate lottery tax when the lottery pool target is met", async function() {
      expect(await pool.isLotteryTaxActive()).to.be.true;

      // The lottery pool target is 1 ETH. The lottery tax is 20%.
      // To meet the target, a total of 1 / 0.20 = 5 ETH worth of buys must occur.
      const requiredBuyGross = parseEther("5.0");

      const tx = await pool.connect(addr1).buy({ value: requiredBuyGross });

      await expect(tx)
        .to.emit(pool, "LotteryTaxStatusChanged")
        .withArgs(false);

      expect(await pool.isLotteryTaxActive()).to.be.false;
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

  describe("Reward Distribution", function () {
    let devAddress, protocolPoolAddress;

    beforeEach(async function() {
        // As per launchpad logic, the devAddress is the owner of the launchpad contract
        devAddress = owner.address;
        protocolPoolAddress = await pool.PROTOCOL_POOL_ADDRESS();
    });

    it("Should revert if a non-owner tries to distribute rewards", async function () {
      await expect(pool.connect(addr1).distributeRewards(addr1.address))
        .to.be.revertedWithCustomError(pool, "OwnableUnauthorizedAccount")
        .withArgs(addr1.address);
    });

    it("Should revert if winner address is the zero address", async function () {
      await expect(pool.distributeRewards(ethers.ZeroAddress))
        .to.be.revertedWith("Winner address cannot be zero");
    });

    it("Should correctly distribute funds when lottery target is exceeded", async function () {
      const winner = addr1;
      // 5 ETH buy is needed to meet 1 ETH lottery pool (20% tax)
      // We will send 6 ETH to exceed it.
      const buyAmount = parseEther("6.0");
      await pool.connect(winner).buy({ value: buyAmount });

      const lotteryTaxBefore = await pool.accumulatedLotteryTax();
      const protocolTaxBefore = await pool.accumulatedProtocolTax();
      const devTaxBefore = await pool.accumulatedDevTax();

      // Sanity check
      const expectedLotteryTax = (buyAmount * 20n) / 100n; // 1.2 ETH
      expect(lotteryTaxBefore).to.equal(expectedLotteryTax);

      const winnerBalanceBefore = await ethers.provider.getBalance(winner.address);
      const protocolBalanceBefore = await ethers.provider.getBalance(protocolPoolAddress);
      const devBalanceBefore = await ethers.provider.getBalance(devAddress);

      const tx = await pool.distributeRewards(winner.address);
      const receipt = await tx.wait();
      const gasCost = receipt.gasUsed * tx.gasPrice;

      await expect(tx).to.emit(pool, "RewardsDistributed");

      const winnerBalanceAfter = await ethers.provider.getBalance(winner.address);
      const protocolBalanceAfter = await ethers.provider.getBalance(protocolPoolAddress);
      const devBalanceAfter = await ethers.provider.getBalance(devAddress);
      
      const remainder = lotteryTaxBefore - initialLotteryPool; // 1.2 - 1.0 = 0.2 ETH

      expect(winnerBalanceAfter).to.equal(winnerBalanceBefore + initialLotteryPool);
      expect(protocolBalanceAfter).to.equal(protocolBalanceBefore + protocolTaxBefore + remainder);
      expect(devBalanceAfter).to.equal(devBalanceBefore + devTaxBefore - gasCost);

      expect(await pool.accumulatedLotteryTax()).to.equal(0);
      expect(await pool.accumulatedProtocolTax()).to.equal(0);
      expect(await pool.accumulatedDevTax()).to.equal(0);
    });

    it("Should correctly distribute funds when lottery target is NOT met", async function () {
      const winner = addr1;
      // We will send 1 ETH, which is not enough to meet the 1 ETH lottery tax.
      const buyAmount = parseEther("1.0");
      await pool.connect(winner).buy({ value: buyAmount });

      const lotteryTaxBefore = await pool.accumulatedLotteryTax();
      const protocolTaxBefore = await pool.accumulatedProtocolTax();
      const devTaxBefore = await pool.accumulatedDevTax();

      // Sanity check
      const expectedLotteryTax = (buyAmount * 20n) / 100n; // 0.2 ETH
      expect(lotteryTaxBefore).to.equal(expectedLotteryTax);
      expect(lotteryTaxBefore).to.be.lt(initialLotteryPool);

      const winnerBalanceBefore = await ethers.provider.getBalance(winner.address);
      const protocolBalanceBefore = await ethers.provider.getBalance(protocolPoolAddress);
      const devBalanceBefore = await ethers.provider.getBalance(devAddress);
      
      const tx = await pool.distributeRewards(winner.address);
      const receipt = await tx.wait();
      const gasCost = receipt.gasUsed * tx.gasPrice;
      
      await expect(tx).to.emit(pool, "RewardsDistributed");

      const winnerBalanceAfter = await ethers.provider.getBalance(winner.address);
      const protocolBalanceAfter = await ethers.provider.getBalance(protocolPoolAddress);
      const devBalanceAfter = await ethers.provider.getBalance(devAddress);

      // Winner gets whatever was collected in the lottery tax pool
      expect(winnerBalanceAfter).to.equal(winnerBalanceBefore + lotteryTaxBefore);
      // Remainder is 0
      expect(protocolBalanceAfter).to.equal(protocolBalanceBefore + protocolTaxBefore);
      expect(devBalanceAfter).to.equal(devBalanceBefore + devTaxBefore - gasCost);
      
      expect(await pool.accumulatedLotteryTax()).to.equal(0);
      expect(await pool.accumulatedProtocolTax()).to.equal(0);
      expect(await pool.accumulatedDevTax()).to.equal(0);
    });
  });
});
