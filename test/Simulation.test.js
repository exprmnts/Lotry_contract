const { expect } = require("chai");
const { ethers } = require("hardhat");
const { formatEther } = ethers;

describe("Market Simulation as a Test", function() {
  this.timeout(60000); // 1 minute timeout for the simulation

  it("for LOTTERY POOL = 1 ETH, should deploy a token, perform a series of buys, and log the market state", async function() {
    // --- Setup ---
    const [owner, buyer] = await ethers.getSigners();
    const tokenName = "Simulation Token";
    const tokenSymbol = "SIM";
    const initialLotteryPool = ethers.parseEther("1.0");
    const ethToUsdRate = 2795.68;

    console.log("\n  Deploying contracts to create a new token with a 1 ETH lottery pool...");
    // Deploy Launchpad
    const TokenLaunchpad = await ethers.getContractFactory("TokenLaunchpad");
    const launchpad = await TokenLaunchpad.deploy(owner.address);
    await launchpad.waitForDeployment();

    // Launch a new Pool using the Launchpad
    const tx = await launchpad.launchToken(tokenName, tokenSymbol, initialLotteryPool);
    const receipt = await tx.wait();

    const tokenCreatedEvent = receipt.logs.find(log => {
      return log.eventName === 'TokenCreated';
    });
    const poolAddress = tokenCreatedEvent.args.tokenAddress;

    // Attach to the deployed pool contract
    const BondingCurvePool = await ethers.getContractFactory("BondingCurvePool");
    const pool = BondingCurvePool.attach(poolAddress);
    console.log(`  Pool deployed at: ${pool.target}`);
    console.log("  -------------------------------------------------------------------------------------------------------------------");


    // --- Initial State Logging ---
    // Note: The liquidity pool is a conceptual value calculated in the constructor.
    // We replicate the calculation here for display purposes, using the known tax rate of 20%.
    const TAX_RATE_NUMERATOR = 20n;
    const TAX_RATE_DENOMINATOR = 100n;
    const liquidityPool = (initialLotteryPool * TAX_RATE_DENOMINATOR) / TAX_RATE_NUMERATOR;

    const vTokenReserve = await pool.virtualTokenReserve();
    const vEthReserve = await pool.virtualEthReserve();
    const tokensInContract = await pool.balanceOf(pool.target);
    const ethInContract = await pool.ethRaised(); // Will be 0 initially

    console.log("  --- Initial Contract State ---");
    console.log(`  Conceptual Liquidity Pool: ${formatEther(liquidityPool)} ETH (Calculated from 1 ETH Lottery Pool / 20%)`);
    console.log(`  Virtual Token Reserve:     ${parseFloat(formatEther(vTokenReserve)).toLocaleString()} tokens`);
    console.log(`  Virtual ETH Reserve:       ${formatEther(vEthReserve)} ETH`);
    console.log(`  Tokens in Contract:        ${parseFloat(formatEther(tokensInContract)).toLocaleString()} tokens`);
    console.log(`  ETH Raised in Contract:    ${formatEther(ethInContract)} ETH`);
    console.log("  -------------------------------------------------------------------------------------------------------------------");


    // --- Simulation ---
    // We will buy until at least 800 M tokens (80 % of supply) have been sold.
    const targetTokensSold = ethers.parseEther("800000000"); // 800 M tokens with 18 decimals
    let tokensSoldTotal = 0n;
    let iteration = 0;
    let buyAmountWei = ethers.parseEther("1"); // start with 1 ETH
    const buyTableData = [];
    const INITIAL_SUPPLY = await pool.INITIAL_SUPPLY();

    console.log("  Adaptive buy loop commencing (target 800 M tokens sold)…");
    console.log(`  Using ETH/USD Rate: $${ethToUsdRate}`);
    console.log("  -------------------------------------------------------------------------------------------------------------------");


    while ((tokensSoldTotal < targetTokensSold || !(await pool.potRaised())) && iteration < 50) {
      const balanceBefore = await pool.balanceOf(buyer.address);
      await pool.connect(buyer).buy({ value: buyAmountWei });
      const balanceAfter = await pool.balanceOf(buyer.address);
      const tokensReceived = balanceAfter - balanceBefore;

      tokensSoldTotal += tokensReceived;

      const tokensLeft = await pool.balanceOf(pool.target);
      const ethRaised = await pool.ethRaised();
      const currentPrice = await pool.calculateCurrentPrice();
      const potRaised = await pool.potRaised();
      const accumulatedPoolFee = await pool.accumulatedPoolFee();

      const circulatingSupply = INITIAL_SUPPLY - tokensLeft;
      const marketCapInEth = (circulatingSupply * currentPrice) / (10n ** 18n);
      const marketCapInUsd = parseFloat(formatEther(marketCapInEth)) * ethToUsdRate;

      buyTableData.push({
        Iteration: iteration,
        "Buy (ETH)": parseFloat(formatEther(buyAmountWei)).toFixed(4),
        "Tokens Received": parseFloat(formatEther(tokensReceived)).toLocaleString(),
        "Cum Tokens Sold": parseFloat(formatEther(tokensSoldTotal)).toLocaleString(),
        "Tokens Left": parseFloat(formatEther(tokensLeft)).toLocaleString(),
        "Token Price (ETH)": parseFloat(formatEther(currentPrice)).toFixed(18),
        "Market Cap (USD)": marketCapInUsd.toLocaleString('en-US', { style: 'currency', currency: 'USD' }),
        "ETH Raised": parseFloat(formatEther(ethRaised)).toFixed(18),
        "Accum Fee": parseFloat(formatEther(accumulatedPoolFee)).toFixed(6),
        "Pot Raised": potRaised ? 'YES' : 'NO',
      });

      // Prepare next iteration
      buyAmountWei *= 2n; // double the ETH commitment each round
      if (buyAmountWei > ethers.parseEther("1000")) {
        buyAmountWei = ethers.parseEther("1000");
      }
      iteration++;
    }

    console.log("\n  --- Adaptive Buy Loop Results ---");
    console.table(buyTableData);
    console.log("  -------------------------------------------------------------------------------------------------------------------");

    // --- Final Tax Collection Logging ---
    const finalPoolFee = await pool.accumulatedPoolFee();
    const potRaised = await pool.potRaised();

    console.log("\n  --- Final Tax Collections ---");
    console.log(`  Accumulated Pool Fee:  ${formatEther(finalPoolFee)} ETH`);
    console.log("  -------------------------------------------------------------------------------------------------------------------");


    // --- Sell Simulation ---
    const seller = buyer; // The user who bought tokens will now sell
    const sellerBalanceTotal = await pool.balanceOf(seller.address);

    // Sell 10%, then 30%, then 50% of the seller's balance to demonstrate mixed activity
    const sellAmountsWei = [
      sellerBalanceTotal / 10n,
      (sellerBalanceTotal * 3n) / 10n,
      sellerBalanceTotal / 2n,
    ];
    const sellTableData = [];

    console.log("\n  Performing proportional sells (10 %, 30 %, 50 % of holdings)…");

    for (const sellAmount of sellAmountsWei) {
      const currentSellerBalance = await pool.balanceOf(seller.address);
      if (currentSellerBalance < sellAmount) {
        console.log(`\n  Skipping sell of ${formatEther(sellAmount)} tokens, seller only has ${formatEther(currentSellerBalance)} tokens.`);
        continue;
      }

      const ethBalanceBefore = await ethers.provider.getBalance(seller.address);

      const sellTx = await pool.connect(seller).sell(sellAmount);
      const sellReceipt = await sellTx.wait();
      const gasUsed = sellReceipt.gasUsed * sellTx.gasPrice;

      const ethBalanceAfter = await ethers.provider.getBalance(seller.address);
      const ethReceived = (ethBalanceAfter - ethBalanceBefore) + gasUsed;

      // Get state after sell
      const tokensLeft = await pool.balanceOf(pool.target);
      const ethRaised = await pool.ethRaised();
      const currentPrice = await pool.calculateCurrentPrice();
      const potRaised = await pool.potRaised();
      const accumulatedPoolFee = await pool.accumulatedPoolFee();

      const circulatingSupply = INITIAL_SUPPLY - tokensLeft;
      const marketCapInEth = (circulatingSupply * currentPrice) / (10n ** 18n);
      const marketCapInUsd = parseFloat(formatEther(marketCapInEth)) * ethToUsdRate;

      sellTableData.push({
        "Sell (Tokens)": parseFloat(formatEther(sellAmount)).toLocaleString(),
        "ETH Received": parseFloat(formatEther(ethReceived)).toFixed(18),
        "Tokens Left in Contract": parseFloat(formatEther(tokensLeft)).toLocaleString(),
        "ETH Raised in Contract": parseFloat(formatEther(ethRaised)).toFixed(18),
        "Token Price (ETH)": parseFloat(formatEther(currentPrice)).toFixed(18),
        "Market Cap (USD)": marketCapInUsd.toLocaleString('en-US', { style: 'currency', currency: 'USD' }),
        "Pot Raised (ETH)": potRaised ? 'YES' : 'NO',
        "Accumulated Pool Fee (ETH)": parseFloat(formatEther(accumulatedPoolFee)).toFixed(18),
      });
    }

    console.log("\n  --- Sell Simulation Results ---");
    console.table(sellTableData);
    console.log("  -------------------------------------------------------------------------------------------------------------------");


    // Add a simple assertion to make it a valid test
    const finalEthRaised = await pool.ethRaised();
    expect(finalEthRaised).to.be.gt(0);
  });
}); 
