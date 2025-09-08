const { expect } = require("chai");
const { ethers } = require("hardhat");
const { formatEther } = ethers;

// Helper Functions
const formatTokens = (amount) => parseFloat(formatEther(amount)).toLocaleString();
const formatUsd = (amount) => amount.toLocaleString('en-US', { style: 'currency', currency: 'USD' });

const calculateMarketCapEth = (price, circulatingSupply, virtualTokenReserve) => {
  return (price * (circulatingSupply + virtualTokenReserve)) / (10n ** 18n);
};

const ethToUsd = (ethAmount, rate) => {
    // Check if ethAmount is a BigInt, if so, format it. Otherwise, assume it's a number.
    const ethValue = typeof ethAmount === 'bigint' ? parseFloat(formatEther(ethAmount)) : ethAmount;
    return ethValue * rate;
};


describe("Market Simulation as a Test", function() {
  this.timeout(60000); // 1 minute timeout for the simulation

  it("for LOTTERY POOL = 1 ETH, should deploy a token, perform a series of buys, and log the market state", async function() {
    // --- Setup ---
    const [owner, buyer] = await ethers.getSigners();
    const tokenName = "Simulation Token";
    const tokenSymbol = "SIM";
    const initialLotteryPool = ethers.parseEther("1.0");
    const ethToUsdRate = 4316.23;

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
    // We replicate the calculation here for display purposes, using the known tax rate of 50%.
    const TAX_RATE_NUMERATOR = 20n; // Updated to match Pool.sol contract
    const TAX_RATE_DENOMINATOR = 100n;
    const liquidityPool = (initialLotteryPool * TAX_RATE_DENOMINATOR) / TAX_RATE_NUMERATOR;

    const vTokenReserve = await pool.virtualTokenReserve();
    const vEthReserve = await pool.virtualEthReserve();
    const tokensInContract = await pool.balanceOf(pool.target);
    const ethInContract = await pool.ethRaised(); // Will be 0 initially

    // Retrieve constants and initial metrics
    const INITIAL_SUPPLY = await pool.INITIAL_SUPPLY();
    const initialPrice = await pool.calculateCurrentPrice();
    const initialCirculatingSupply = INITIAL_SUPPLY - tokensInContract;
    // New market cap calculation: price * (circulating supply + virtual tokens)
    const initialMarketCapInEth = calculateMarketCapEth(initialPrice, initialCirculatingSupply, vTokenReserve);
    const initialMarketCapInUsd = ethToUsd(initialMarketCapInEth, ethToUsdRate);

    console.log("  --- Initial Contract State ---");
    console.log(`  Conceptual Liquidity Pool: ${formatEther(liquidityPool)} ETH (Calculated from 1 ETH Lottery Pool / 50%)`);
    console.log(`  Virtual Token Reserve:     ${formatTokens(vTokenReserve)} tokens`);
    console.log(`  Virtual ETH Reserve:       ${formatEther(vEthReserve)} ETH`);
    console.log(`  Tokens in Contract:        ${formatTokens(tokensInContract)} tokens`);
    console.log(`  ETH Raised in Contract:    ${formatEther(ethInContract)} ETH`);
    console.log(`  Initial Token Price:       ${parseFloat(formatEther(initialPrice)).toFixed(18)} ETH`);
    console.log(`  Initial Market Cap (USD):  ${formatUsd(initialMarketCapInUsd)}`);
    console.log("  -------------------------------------------------------------------------------------------------------------------");


    // --- Simulation ---
    // We will buy until at least 500 M tokens (50 % of supply) have been sold.
    const targetTokensSold = ethers.parseEther("500000000"); // 500 M tokens with 18 decimals
    let tokensSoldTotal = 0n;
    let iteration = 0;
    let buyAmountWei = ethers.parseEther("1"); // start with 1 ETH
    const buyTableData = [];
    // const INITIAL_SUPPLY = await pool.INITIAL_SUPPLY(); // already defined above

    console.log("  Adaptive buy loop commencing (target 500 M tokens sold)…");
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
      const vTokenReserve = await pool.virtualTokenReserve();
      const vEthReserve = await pool.virtualEthReserve();

      const circulatingSupply = INITIAL_SUPPLY - tokensLeft;
      // New market cap calculation: price * (circulating supply + virtual tokens)
      const marketCapInEth = calculateMarketCapEth(currentPrice, circulatingSupply, vTokenReserve);
      const marketCapInUsd = ethToUsd(marketCapInEth, ethToUsdRate);

      buyTableData.push({
        "Buy (ETH)": parseFloat(formatEther(buyAmountWei)).toFixed(4),
        "Tokens Received": formatTokens(tokensReceived),
        "Cum Tokens Sold": formatTokens(tokensSoldTotal),
        "Tokens Left": formatTokens(tokensLeft),
        "Virtual Token Reserve": formatTokens(vTokenReserve),
        "Virtual ETH Reserve": parseFloat(formatEther(vEthReserve)).toFixed(4),
        "Token Price (ETH)": parseFloat(formatEther(currentPrice)).toFixed(18),
        "Market Cap (ETH/USD)": `${parseFloat(formatEther(marketCapInEth)).toFixed(4)} / ${formatUsd(marketCapInUsd)}`,
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
      // New market cap calculation: price * (circulating supply + virtual tokens)
      const marketCapInEth = calculateMarketCapEth(currentPrice, circulatingSupply, vTokenReserve);
      const marketCapInUsd = ethToUsd(marketCapInEth, ethToUsdRate);

      sellTableData.push({
        "Sell (Tokens)": formatTokens(sellAmount),
        "ETH Received": parseFloat(formatEther(ethReceived)).toFixed(18),
        "Tokens Left in Contract": formatTokens(tokensLeft),
        "ETH Raised in Contract": parseFloat(formatEther(ethRaised)).toFixed(18),
        "Token Price (ETH)": parseFloat(formatEther(currentPrice)).toFixed(18),
        "Market Cap (ETH/USD)": `${parseFloat(formatEther(marketCapInEth)).toFixed(4)} / ${formatUsd(marketCapInUsd)}`,
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

  it("should simulate 50 buys with varying amounts and show price increases with tax analysis", async function() {
    this.timeout(120000); // 2 minutes timeout for this simulation

    // --- Setup ---
    const [owner, ...buyers] = await ethers.getSigners();
    
    if (buyers.length === 0) {
      throw new Error("No buyer accounts found. Please ensure your Hardhat network is configured with multiple accounts.");
    }

    // --- Config ---
    const numberOfBuys = 50;
    const minBuyAmount = ethers.parseEther("0.001"); // 0.001 ETH
    const maxBuyAmount = ethers.parseEther("0.5");   // 0.5 ETH
    const ethToUsdRate = 4316.23;

    console.log(`\n\n===================================================================================================================`);
    console.log(`  PRICE INCREASE SIMULATION: ${numberOfBuys} buys with varying amounts (${formatEther(minBuyAmount)} to ${formatEther(maxBuyAmount)} ETH)`);
    console.log(`===================================================================================================================\n`);
    console.log(`  Using ${buyers.length} buyer accounts for the simulation (wallets will be reused).`);

    const tokenName = "Price Analysis Token";
    const tokenSymbol = "PAT";
    const initialLotteryPool = ethers.parseEther("1.0");

    console.log(`  Deploying contracts for price increase analysis...`);
    // Deploy Launchpad
    const TokenLaunchpad = await ethers.getContractFactory("TokenLaunchpad");
    const launchpad = await TokenLaunchpad.deploy(owner.address);
    await launchpad.waitForDeployment();

    // Launch a new Pool
    const tx = await launchpad.launchToken(tokenName, tokenSymbol, initialLotteryPool);
    const receipt = await tx.wait();
    
    const tokenCreatedEvent = receipt.logs.find(log => {
      return log.eventName === 'TokenCreated';
    });

    if (!tokenCreatedEvent) {
      throw new Error("TokenCreated event not found");
    }
    const poolAddress = tokenCreatedEvent.args.tokenAddress;

    // Attach to the deployed pool contract
    const BondingCurvePool = await ethers.getContractFactory("BondingCurvePool");
    const pool = BondingCurvePool.attach(poolAddress);
    console.log(`  Pool deployed at: ${pool.target}`);
    console.log("  -------------------------------------------------------------------------------------------------------------------");

    // --- Initial State Logging ---
    const TAX_RATE_NUMERATOR = 20n; // Updated to match Pool.sol contract
    const TAX_RATE_DENOMINATOR = 100n;
    const liquidityPool = (initialLotteryPool * TAX_RATE_DENOMINATOR) / TAX_RATE_NUMERATOR;

    const vTokenReserve = await pool.virtualTokenReserve();
    const vEthReserve = await pool.virtualEthReserve();
    const tokensInContract = await pool.balanceOf(pool.target);
    const ethInContract = await pool.ethRaised();

    const INITIAL_SUPPLY = await pool.INITIAL_SUPPLY();
    const initialPrice = await pool.calculateCurrentPrice();
    const initialCirculatingSupply = INITIAL_SUPPLY - tokensInContract;
    // New market cap calculation: price * (circulating supply + virtual tokens)
    const initialMarketCapInEth = calculateMarketCapEth(initialPrice, initialCirculatingSupply, vTokenReserve);
    const initialMarketCapInUsd = ethToUsd(initialMarketCapInEth, ethToUsdRate);

    console.log("  --- Initial Contract State ---");
    console.log(`  Conceptual Liquidity Pool: ${formatEther(liquidityPool)} ETH (Calculated from 1 ETH Lottery Pool / 50%)`);
    console.log(`  Virtual Token Reserve:     ${formatTokens(vTokenReserve)} tokens`);
    console.log(`  Virtual ETH Reserve:       ${formatEther(vEthReserve)} ETH`);
    console.log(`  Tokens in Contract:        ${formatTokens(tokensInContract)} tokens`);
    console.log(`  ETH Raised in Contract:    ${formatEther(ethInContract)} ETH`);
    console.log(`  Initial Token Price:       ${parseFloat(formatEther(initialPrice)).toFixed(18)} ETH ($${ethToUsd(initialPrice, ethToUsdRate).toFixed(8)})`);
    console.log(`  Initial Market Cap:        ${formatEther(initialMarketCapInEth)} ETH (${formatUsd(initialMarketCapInUsd)})`);
    console.log("  -------------------------------------------------------------------------------------------------------------------");

    // --- Generate varying buy amounts ---
    // Use smaller, more realistic buy amounts to avoid exhausting token supply
    const buyAmounts = [];
    for (let i = 0; i < numberOfBuys; i++) {
      // Create a more conservative distribution to avoid running out of tokens
      const ratio = i / (numberOfBuys - 1); // 0 to 1
      const linearRatio = ratio; // Linear distribution instead of exponential
      const buyAmountWei = minBuyAmount + BigInt(Math.floor(Number(maxBuyAmount - minBuyAmount) * linearRatio));
      buyAmounts.push(buyAmountWei);
    }

    // --- Simulation ---
    let tokensSoldTotal = 0n;
    const buyTableData = [];
    let previousPrice = initialPrice;
    
    const buyRecords = []; // Store each buy transaction individually

    console.log(`\n  Price Increase Analysis starting...`);
    console.log(`  Buy amounts vary from ${formatEther(minBuyAmount)} ETH to ${formatEther(maxBuyAmount)} ETH`);
    console.log(`  Using ETH/USD Rate: $${ethToUsdRate}`);
    console.log("  -------------------------------------------------------------------------------------------------------------------");

    for (let i = 0; i < numberOfBuys; i++) {
      const buyAmount = buyAmounts[i];
      const currentBuyer = buyers[i % buyers.length];
      
      // Check if we have enough tokens left in the contract
      const tokensLeftInContract = await pool.balanceOf(pool.target);
      if (tokensLeftInContract < ethers.parseEther("1000000")) { // Stop if less than 1M tokens left
        console.log(`\n  ⚠️  Stopping simulation at buy #${i + 1} - insufficient tokens remaining (${formatTokens(tokensLeftInContract)} tokens left)`);
        break;
      }
      
      // Calculate tax before the buy
      const potRaisedBefore = await pool.potRaised();
      let buyTaxRate;
      if (potRaisedBefore) {
        buyTaxRate = 0; // Phase 2: 0% buy tax
      } else {
        buyTaxRate = 20; // Phase 1: 20% buy tax
      }
      
      const grossEthAmount = buyAmount;
      const taxAmount = (grossEthAmount * BigInt(buyTaxRate)) / 100n;
      const netEthForCurve = grossEthAmount - taxAmount;
      
      const balanceBefore = await pool.balanceOf(currentBuyer.address);
      
      try {
        await pool.connect(currentBuyer).buy({ value: buyAmount });
      } catch (error) {
        console.log(`\n  ⚠️  Buy #${i + 1} failed (${formatEther(buyAmount)} ETH): ${error.message}`);
        console.log(`  Tokens left in contract: ${formatTokens(tokensLeftInContract)}`);
        break;
      }
      
      const balanceAfter = await pool.balanceOf(currentBuyer.address);
      const tokensReceived = balanceAfter - balanceBefore;
      
      // Store the individual buy record
      buyRecords.push({
        buyer: currentBuyer,
        ethSpent: buyAmount,
        tokensReceived: tokensReceived,
      });
      
      tokensSoldTotal += tokensReceived;

      // Get state after buy
      const tokensLeft = await pool.balanceOf(pool.target);
      const ethRaised = await pool.ethRaised();
      const currentPrice = await pool.calculateCurrentPrice();
      const potRaised = await pool.potRaised();
      const accumulatedPoolFee = await pool.accumulatedPoolFee();

      // Calculate price increase
      const priceIncrease = currentPrice - initialPrice;
      const priceIncreasePercent = initialPrice > 0n ? 
        (Number(priceIncrease * 10000n / initialPrice)) / 100 : 0;

      const circulatingSupply = INITIAL_SUPPLY - tokensLeft;
      // New market cap calculation: price * (circulating supply + virtual tokens)
      const marketCapInEth = calculateMarketCapEth(currentPrice, circulatingSupply, vTokenReserve);
      const marketCapInUsd = ethToUsd(marketCapInEth, ethToUsdRate);

      // Calculate effective price per token bought (including tax impact)
      const effectivePricePerToken = tokensReceived > 0n ? 
        (grossEthAmount * (10n ** 18n)) / tokensReceived : 0n;

      buyTableData.push({
        "Buy #": i + 1,
        "Buyer": `${currentBuyer.address.substring(0, 6)}...`,
        "Buy Amount (ETH)": parseFloat(formatEther(buyAmount)).toFixed(4),
        "Buy Amount (USD)": `$${ethToUsd(buyAmount, ethToUsdRate).toFixed(2)}`,
        "Tax Rate": `${buyTaxRate}%`,
        "Tax Amount (ETH)": parseFloat(formatEther(taxAmount)).toFixed(6),
        "Net ETH to Curve": parseFloat(formatEther(netEthForCurve)).toFixed(6),
        "ETH in Contract": parseFloat(formatEther(ethRaised)).toFixed(4),
        "Tokens Received": formatTokens(tokensReceived),
        "Tokens Left in Curve": formatTokens(tokensLeft),
        "Effective Price/Token (ETH)": parseFloat(formatEther(effectivePricePerToken)).toFixed(12),
        "Curve Price (ETH)": parseFloat(formatEther(currentPrice)).toFixed(12),
        "Curve Price (USD)": `$${ethToUsd(currentPrice, ethToUsdRate).toFixed(8)}`,
        "Price Increase (%)": `${priceIncreasePercent.toFixed(4)}%`,
        "Market Cap (USD)": formatUsd(marketCapInUsd),
        "Pot Status": potRaised ? 'RAISED' : 'PENDING',
      });

      previousPrice = currentPrice;
    }

    console.log("\n  --- Price Increase Analysis Results ---");
    console.table(buyTableData);
    console.log("  -------------------------------------------------------------------------------------------------------------------");

    // Summary statistics
    const finalPrice = await pool.calculateCurrentPrice();
    const totalPriceIncrease = finalPrice - initialPrice;
    const totalPriceIncreasePercent = initialPrice > 0n ? 
      (Number(totalPriceIncrease * 10000n / initialPrice)) / 100 : 0;
    const finalAccumulatedFee = await pool.accumulatedPoolFee();

    console.log("\n  --- Summary Statistics ---");
    console.log(`  Initial Price:           ${parseFloat(formatEther(initialPrice)).toFixed(12)} ETH ($${ethToUsd(initialPrice, ethToUsdRate).toFixed(8)})`);
    console.log(`  Final Price:             ${parseFloat(formatEther(finalPrice)).toFixed(12)} ETH ($${ethToUsd(finalPrice, ethToUsdRate).toFixed(8)})`);
    console.log(`  Total Price Increase:    ${totalPriceIncreasePercent.toFixed(4)}%`);
    console.log(`  Total Tokens Sold:       ${formatTokens(tokensSoldTotal)}`);
    console.log(`  Total Tax Collected:     ${parseFloat(formatEther(finalAccumulatedFee)).toFixed(6)} ETH ($${ethToUsd(finalAccumulatedFee, ethToUsdRate).toFixed(2)})`);
    console.log(`  Lottery Pot Status:      ${await pool.potRaised() ? 'RAISED' : 'PENDING'}`);
    console.log("  -------------------------------------------------------------------------------------------------------------------");

    // --- Sell Simulation ---
    console.log(`\n\n===================================================================================================================`);
    console.log(`  SELL SIMULATION: Each of the ${buyRecords.length} buys will now be sold by the original buyer.`);
    console.log(`===================================================================================================================\n`);

    const contractEthBalance = await pool.ethRaised();
    if (contractEthBalance === 0n) {
      console.log("  Contract has no ETH. Skipping sell simulation.");
    } else {
      const sellTableData = [];
      let totalEthReceivedFromSells = 0n;
      let totalEthSpentOnBuys = 0n;

      for (let i = 0; i < buyRecords.length; i++) {
        const buyRecord = buyRecords[i];
        const { buyer: seller, ethSpent, tokensReceived: tokensToSell } = buyRecord;

        totalEthSpentOnBuys += ethSpent;

        // Check if the seller has enough tokens for this specific sale
        const sellerBalance = await pool.balanceOf(seller.address);
        if (sellerBalance < tokensToSell) {
          console.log(`  ⚠️  Skipping sell #${i + 1} for ${seller.address.substring(0,6)}...: Insufficient balance. Has ${formatEther(sellerBalance)}, needs ${formatEther(tokensToSell)}.`);
          continue;
        }

        const ethBalanceBefore = await ethers.provider.getBalance(seller.address);
        
        const sellTx = await pool.connect(seller).sell(tokensToSell);
        const sellReceipt = await sellTx.wait();
        const gasUsed = sellReceipt.gasUsed * sellTx.gasPrice;

        const ethBalanceAfter = await ethers.provider.getBalance(seller.address);
        const ethReceived = (ethBalanceAfter - ethBalanceBefore) + gasUsed;
        
        totalEthReceivedFromSells += ethReceived;
        
        const profit = ethReceived - ethSpent;
        const profitUsd = ethToUsd(profit, ethToUsdRate);

        const ethInContractAfterSell = await pool.ethRaised();

        sellTableData.push({
          "Sell #": i + 1,
          "Seller": `${seller.address.substring(0, 6)}...`,
          "Tokens Sold": formatTokens(tokensToSell),
          "ETH Spent (Buy)": parseFloat(formatEther(ethSpent)).toFixed(4),
          "ETH Received (Sell)": parseFloat(formatEther(ethReceived)).toFixed(4),
          "Profit/Loss (ETH)": `${parseFloat(formatEther(profit)).toFixed(4)}`,
          "Profit/Loss (USD)": `${formatUsd(profitUsd)}`,
          "ETH in Contract": parseFloat(formatEther(ethInContractAfterSell)).toFixed(4),
        });
      }

      console.log("\n  --- Individual Sell Results ---");
      console.table(sellTableData);
      console.log("  -------------------------------------------------------------------------------------------------------------------");
      
      // --- Overall Profit Summary ---
      const totalNetProfit = totalEthReceivedFromSells - totalEthSpentOnBuys;
      const totalNetProfitUsd = ethToUsd(totalNetProfit, ethToUsdRate);

      console.log("\n  --- Aggregate Sell Simulation Summary ---");
      console.log(`  Total ETH Spent on Buys:         ${parseFloat(formatEther(totalEthSpentOnBuys)).toFixed(4)} ETH`);
      console.log(`  Total ETH Received from Sells:   ${parseFloat(formatEther(totalEthReceivedFromSells)).toFixed(4)} ETH`);
      console.log(`  Total Net Profit/Loss (ETH):     ${parseFloat(formatEther(totalNetProfit)).toFixed(4)} ETH`);
      console.log(`  Total Net Profit/Loss (USD):     ${formatUsd(totalNetProfitUsd)}`);
      console.log("  -------------------------------------------------------------------------------------------------------------------");
    }

    // Add a simple assertion to make it a valid test
    const finalEthRaised = await pool.ethRaised();
    expect(finalEthRaised).to.be.gt(0);
    expect(finalPrice).to.be.gt(initialPrice);
  });

  it("should verify specific price progression: 1x → 20x at key milestones", async function() {
    this.timeout(60000);

    // --- Config ---
    const ethToUsdRate = 4316.23;
    const testBuyAmount = ethers.parseEther("0.1"); // 0.1 ETH per test buy, increased for faster progression

    // --- Setup ---
    console.log(`\n\n===================================================================================================================`);
    console.log(`  PRICE PROGRESSION VERIFICATION: Testing 1x → 20x price increase`);
    console.log(`===================================================================================================================\n`);

    const [owner, buyer] = await ethers.getSigners();
    
    const tokenName = "Price Progression Test";
    const tokenSymbol = "PPT";
    const initialLotteryPool = ethers.parseEther("1.0");

    console.log(`  Deploying contracts for price progression test...`);
    // Deploy Launchpad
    const TokenLaunchpad = await ethers.getContractFactory("TokenLaunchpad");
    const launchpad = await TokenLaunchpad.deploy(owner.address);
    await launchpad.waitForDeployment();

    // Launch a new Pool
    const tx = await launchpad.launchToken(tokenName, tokenSymbol, initialLotteryPool);
    const receipt = await tx.wait();
    
    const tokenCreatedEvent = receipt.logs.find(log => {
      return log.eventName === 'TokenCreated';
    });

    if (!tokenCreatedEvent) {
      throw new Error("TokenCreated event not found");
    }
    const poolAddress = tokenCreatedEvent.args.tokenAddress;

    // Attach to the deployed pool contract
    const BondingCurvePool = await ethers.getContractFactory("BondingCurvePool");
    const pool = BondingCurvePool.attach(poolAddress);
    console.log(`  Pool deployed at: ${pool.target}`);

    // Get initial state
    const INITIAL_SUPPLY = await pool.INITIAL_SUPPLY();
    const initialPrice = await pool.calculateCurrentPrice();
    const vTokenReserve = await pool.virtualTokenReserve();
    const tokensInContract = await pool.balanceOf(pool.target);
    const initialCirculatingSupply = INITIAL_SUPPLY - tokensInContract;
    // New market cap calculation: price * (circulating supply + virtual tokens)
    const initialMarketCapInEth = calculateMarketCapEth(initialPrice, initialCirculatingSupply, vTokenReserve);
    const initialMarketCapInUsd = ethToUsd(initialMarketCapInEth, ethToUsdRate);

    console.log("  --- Initial Contract State ---");
    console.log(`  Initial token supply: ${formatTokens(INITIAL_SUPPLY)} tokens`);
    console.log(`  Target initial price: ~0.000000005 ETH per token`);
    console.log(`  Actual initial price: ${parseFloat(formatEther(initialPrice)).toFixed(15)} ETH per token`);
    console.log("  -------------------------------------------------------------------------------------------------------------------");

    // Test milestone data
    const milestones = [];
    
    // Milestone 1: First buy (baseline - 1x)
    console.log("\n  🎯 MILESTONE 1: First Buy (Baseline - 1x price)");
    let balanceBefore = await pool.balanceOf(buyer.address);
    await pool.connect(buyer).buy({ value: testBuyAmount });
    let balanceAfter = await pool.balanceOf(buyer.address);
    let tokensReceived = balanceAfter - balanceBefore;
    let currentPrice = await pool.calculateCurrentPrice();
    let priceMultiplier = Number(currentPrice * 1000000n / initialPrice) / 1000000;
    
    milestones.push({
      stage: "First buy (1x)",
      tokensReceived: parseFloat(formatEther(tokensReceived)),
      price: parseFloat(formatEther(currentPrice)),
      priceMultiplier: priceMultiplier,
      tokensSold: parseFloat(formatEther(tokensReceived))
    });

    console.log(`  Tokens received: ${formatTokens(tokensReceived)}`);
    console.log(`  Price: ${parseFloat(formatEther(currentPrice)).toFixed(15)} ETH`);
    console.log(`  Price multiplier: ${priceMultiplier.toFixed(2)}x`);

    // Buy until we reach ~50% market cap (500M tokens sold)
    let tokensSoldTotal = tokensReceived;
    const target50Percent = INITIAL_SUPPLY / 2n; // 500M tokens
    
    console.log(`\n  📈 Buying towards 50% market cap (${formatTokens(target50Percent)} tokens)...`);
    
    let buyCount = 1;
    let dynamicBuyAmount = testBuyAmount;

    while (tokensSoldTotal < target50Percent && buyCount < 500) {
      balanceBefore = await pool.balanceOf(buyer.address);
      
      // Increase buy amount as price goes up to reach the target faster
      if (buyCount % 20 === 0) {
        dynamicBuyAmount *= 2n;
        if (dynamicBuyAmount > ethers.parseEther("10.0")) {
            dynamicBuyAmount = ethers.parseEther("10.0");
        }
      }

      await pool.connect(buyer).buy({ value: dynamicBuyAmount });
      balanceAfter = await pool.balanceOf(buyer.address);
      tokensReceived = balanceAfter - balanceBefore;
      tokensSoldTotal += tokensReceived;
      buyCount++;
      
      if (buyCount % 10 === 0) {
        currentPrice = await pool.calculateCurrentPrice();
        console.log(`  Buy #${buyCount}: ${formatTokens(tokensSoldTotal)} tokens sold, Price: ${parseFloat(formatEther(currentPrice)).toFixed(12)} ETH`);
      }
    }

    // Milestone 2: ~50% market cap (20x target)
    console.log("\n  🎯 MILESTONE 2: ~50% Market Cap (Target 20x price)");
    balanceBefore = await pool.balanceOf(buyer.address);
    await pool.connect(buyer).buy({ value: testBuyAmount });
    balanceAfter = await pool.balanceOf(buyer.address);
    tokensReceived = balanceAfter - balanceBefore;
    tokensSoldTotal += tokensReceived;
    currentPrice = await pool.calculateCurrentPrice();
    priceMultiplier = Number(currentPrice * 1000000n / initialPrice) / 1000000;
    
    milestones.push({
      stage: "Mid curve (~50% cap)",
      tokensReceived: parseFloat(formatEther(tokensReceived)),
      price: parseFloat(formatEther(currentPrice)),
      priceMultiplier: priceMultiplier,
      tokensSold: parseFloat(formatEther(tokensSoldTotal))
    });

    console.log(`  Tokens sold total: ${formatTokens(tokensSoldTotal)}`);
    console.log(`  Tokens received: ${formatTokens(tokensReceived)}`);
    console.log(`  Price: ${parseFloat(formatEther(currentPrice)).toFixed(15)} ETH`);
    console.log(`  Price multiplier: ${priceMultiplier.toFixed(2)}x`);

    // Summary table
    console.log("\n  --- PRICE PROGRESSION SUMMARY ---");
    console.table(milestones.map(m => ({
      "Buy Stage": m.stage,
      "Spend (ETH)": formatEther(testBuyAmount),
      "Tokens Received": m.tokensReceived.toLocaleString(),
      "Price per Token (ETH)": m.price.toFixed(15),
      "Price Increase vs First": `${m.priceMultiplier.toFixed(2)}x`,
      "Total Tokens Sold": m.tokensSold.toLocaleString()
    })));

    console.log("  -------------------------------------------------------------------------------------------------------------------");

    // Verify our targets were approximately met
    const milestone2Multiplier = milestones[1].priceMultiplier;
    
    console.log(`\n  🎯 TARGET VERIFICATION:`);
    console.log(`  Target at 50% cap: 20x price increase`);
    console.log(`  Actual at ~50% cap: ${milestone2Multiplier.toFixed(2)}x price increase`);
    
    // Assertions - allow for some tolerance around the 20x mark
    expect(milestone2Multiplier).to.be.closeTo(20, 2.0);
    expect(currentPrice).to.be.gt(initialPrice);
  });

  it("should demonstrate aggressive buying to deplete 500M tokens and show price explosion", async function() {
    this.timeout(120000); // 2 minutes timeout

    // --- Config ---
    const ethToUsdRate = 4316.23;

    // --- Setup ---
    console.log(`\n\n===================================================================================================================`);
    console.log(`  800M TOKEN DEPLETION SIMULATION: Aggressive buying until near curve exhaustion`);
    console.log(`===================================================================================================================\n`);

    const [owner, buyer] = await ethers.getSigners();
    
    const tokenName = "Depletion Test Token";
    const tokenSymbol = "DTT";
    const initialLotteryPool = ethers.parseEther("1.0");

    console.log(`  Deploying contracts for 800M token depletion test...`);
    // Deploy Launchpad
    const TokenLaunchpad = await ethers.getContractFactory("TokenLaunchpad");
    const launchpad = await TokenLaunchpad.deploy(owner.address);
    await launchpad.waitForDeployment();

    // Launch a new Pool
    const tx = await launchpad.launchToken(tokenName, tokenSymbol, initialLotteryPool);
    const receipt = await tx.wait();
    
    const tokenCreatedEvent = receipt.logs.find(log => {
      return log.eventName === 'TokenCreated';
    });

    if (!tokenCreatedEvent) {
      throw new Error("TokenCreated event not found");
    }
    const poolAddress = tokenCreatedEvent.args.tokenAddress;

    // Attach to the deployed pool contract
    const BondingCurvePool = await ethers.getContractFactory("BondingCurvePool");
    const pool = BondingCurvePool.attach(poolAddress);
    console.log(`  Pool deployed at: ${pool.target}`);

    // Get initial state
    const INITIAL_SUPPLY = await pool.INITIAL_SUPPLY();
    const initialPrice = await pool.calculateCurrentPrice();
    const initialVirtualTokenReserve = await pool.virtualTokenReserve();
    const initialVirtualEthReserve = await pool.virtualEthReserve();
    
    console.log(`  Initial token supply: ${formatTokens(INITIAL_SUPPLY)} tokens`);
    console.log(`  Initial price: ${parseFloat(formatEther(initialPrice)).toFixed(15)} ETH per token`);
    console.log(`  Initial virtual token reserve: ${formatTokens(initialVirtualTokenReserve)} tokens`);
    console.log(`  Initial virtual ETH reserve: ${parseFloat(formatEther(initialVirtualEthReserve)).toFixed(6)} ETH`);
    console.log(`  Target: Deplete 500M tokens (50% of supply)`);
    console.log("  -------------------------------------------------------------------------------------------------------------------");

    // Aggressive buying strategy
    let tokensSoldTotal = 0n;
    const target500M = (INITIAL_SUPPLY * 50n) / 100n; // 500M tokens
    const milestoneData = [];
    let buyAmount = ethers.parseEther("0.1"); // Start with 0.1 ETH buys
    let buyCount = 0;

    console.log(`\n  🚀 Starting aggressive buying to reach 500M tokens sold...`);
    console.log(`  Target tokens to sell: ${formatTokens(target500M)}`);

    while (tokensSoldTotal < target500M && buyCount < 1000) {
      const tokensLeftInContract = await pool.balanceOf(pool.target);
      
      // Stop if we're getting close to exhausting the contract
      if (tokensLeftInContract < ethers.parseEther("10000000")) { // Stop at 10M tokens left
        console.log(`\n  ⚠️  Stopping - only ${formatTokens(tokensLeftInContract)} tokens left in contract`);
        break;
      }

      try {
        const balanceBefore = await pool.balanceOf(buyer.address);
        await pool.connect(buyer).buy({ value: buyAmount });
        const balanceAfter = await pool.balanceOf(buyer.address);
        const tokensReceived = balanceAfter - balanceBefore;
        
        tokensSoldTotal += tokensReceived;
        buyCount++;

        // Log major milestones
        const percentSold = Number(tokensSoldTotal * 100n / INITIAL_SUPPLY);
        
        if (buyCount % 50 === 0 || percentSold >= 10 && buyCount % 10 === 0) {
          const currentPrice = await pool.calculateCurrentPrice();
          const priceMultiplier = Number(currentPrice * 1000000n / initialPrice) / 1000000;
          const tokensLeft = await pool.balanceOf(pool.target);
          
          console.log(`  Buy #${buyCount}: ${percentSold.toFixed(1)}% sold (${formatTokens(tokensSoldTotal)}) | Price: ${parseFloat(formatEther(currentPrice)).toFixed(12)} ETH (${priceMultiplier.toFixed(2)}x) | Tokens left: ${formatTokens(tokensLeft)}`);
          
          // Store milestone data
          if (percentSold >= 10 && percentSold % 10 < 1) { // Every 10%
            milestoneData.push({
              buyNumber: buyCount,
              percentSold: percentSold,
              tokensSold: parseFloat(formatEther(tokensSoldTotal)),
              tokensReceived: parseFloat(formatEther(tokensReceived)),
              price: parseFloat(formatEther(currentPrice)),
              priceMultiplier: priceMultiplier,
              buyAmount: parseFloat(formatEther(buyAmount)),
              tokensLeft: parseFloat(formatEther(tokensLeft))
            });
          }
        }

        // Increase buy amount as we progress to speed up the process
        if (buyCount % 100 === 0 && buyAmount < ethers.parseEther("5.0")) {
          buyAmount = buyAmount * 2n; // Double the buy amount every 100 buys
          console.log(`  📈 Increasing buy amount to ${formatEther(buyAmount)} ETH`);
        }

      } catch (error) {
        console.log(`\n  ❌ Buy #${buyCount + 1} failed: ${error.message}`);
        console.log(`  Attempted buy amount: ${formatEther(buyAmount)} ETH`);
        console.log(`  Tokens sold so far: ${formatTokens(tokensSoldTotal)}`);
        break;
      }
    }

    // Final state
    const finalPrice = await pool.calculateCurrentPrice();
    const finalPriceMultiplier = Number(finalPrice * 1000000n / initialPrice) / 1000000;
    const finalTokensLeft = await pool.balanceOf(pool.target);
    const finalPercentSold = Number(tokensSoldTotal * 100n / INITIAL_SUPPLY);

    console.log(`\n  🎯 FINAL RESULTS:`);
    console.log(`  Total buys executed: ${buyCount}`);
    console.log(`  Tokens sold: ${formatTokens(tokensSoldTotal)} (${finalPercentSold.toFixed(2)}% of supply)`);
    console.log(`  Tokens remaining: ${formatTokens(finalTokensLeft)}`);
    console.log(`  Final price: ${parseFloat(formatEther(finalPrice)).toFixed(15)} ETH per token`);
    console.log(`  Price increase: ${finalPriceMultiplier.toFixed(2)}x from initial`);
    console.log(`  Final price (USD): $${ethToUsd(finalPrice, ethToUsdRate).toFixed(8)} per token`);

    // Show milestone progression table
    if (milestoneData.length > 0) {
      console.log(`\n  --- DEPLETION PROGRESSION MILESTONES ---`);
      console.table(milestoneData.map(m => ({
        "Buy #": m.buyNumber,
        "% Sold": `${m.percentSold.toFixed(1)}%`,
        "Tokens Sold": m.tokensSold.toLocaleString(),
        "Buy Amount (ETH)": m.buyAmount.toFixed(3),
        "Tokens Received": m.tokensReceived.toLocaleString(),
        "Price (ETH)": m.price.toFixed(15),
        "Price Multiplier": `${m.priceMultiplier.toFixed(2)}x`,
        "Tokens Left": m.tokensLeft.toLocaleString()
      })));
    }

    console.log("  -------------------------------------------------------------------------------------------------------------------");

    // Assertions
    expect(tokensSoldTotal).to.be.gt(0);
    expect(finalPrice).to.be.gt(initialPrice);
    expect(finalPriceMultiplier).to.be.greaterThan(1);
  });
}); 
