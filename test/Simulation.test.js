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
    const ethToUsdRate = 4601.08;

    console.log("\n  Deploying contracts to create a new token with a 1 ETH lottery pool...");
    // Deploy Launchpad
    const TokenLaunchpad = await ethers.getContractFactory("TokenLaunchpad");
    const launchpad = await TokenLaunchpad.deploy(owner.address);
    await launchpad.waitForDeployment();

    // Launch a new Pool using the Launchpad
    const tx = await launchpad.launchToken(tokenName, tokenSymbol);
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


    while (tokensSoldTotal < targetTokensSold && iteration < 50) {
      const balanceBefore = await pool.balanceOf(buyer.address);
      await pool.connect(buyer).buy({ value: buyAmountWei });
      const balanceAfter = await pool.balanceOf(buyer.address);
      const tokensReceived = balanceAfter - balanceBefore;

      tokensSoldTotal += tokensReceived;

      const tokensLeft = await pool.balanceOf(pool.target);
      const ethRaised = await pool.ethRaised();
      const currentPrice = await pool.calculateCurrentPrice();
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

    console.log(`  Deploying contracts for price increase analysis...`);
    // Deploy Launchpad
    const TokenLaunchpad = await ethers.getContractFactory("TokenLaunchpad");
    const launchpad = await TokenLaunchpad.deploy(owner.address);
    await launchpad.waitForDeployment();

    // Launch a new Pool
    const tx = await launchpad.launchToken(tokenName, tokenSymbol);
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
      const buyTaxRate = 20; // Tax is always 20%
      
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
    const feeAfterSells = await pool.accumulatedPoolFee();
    expect(feeAfterSells).to.be.gt(0);
    expect(finalPrice).to.be.gt(initialPrice);
  });

  it("should calculate ETH required to deplete ~1B tokens with aggressive doubling buys", async function() {
    this.timeout(240000); // 4 minutes timeout, as this can be intensive

    // --- Config ---
    const ethToUsdRate = 4601.08;

    // --- Setup ---
    console.log(`\n\n===================================================================================================================`);
    console.log(`  TOKEN DEPLETION SIMULATION: Calculating ETH required to buy ~1B tokens`);
    console.log(`===================================================================================================================\n`);

    const [owner, buyer] = await ethers.getSigners();
    
    const tokenName = "Depletion Test Token";
    const tokenSymbol = "DTT";

    console.log(`  Deploying contracts for depletion test...`);
    // Deploy Launchpad
    const TokenLaunchpad = await ethers.getContractFactory("TokenLaunchpad");
    const launchpad = await TokenLaunchpad.deploy(owner.address);
    await launchpad.waitForDeployment();

    // Launch a new Pool
    const tx = await launchpad.launchToken(tokenName, tokenSymbol);
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
    
    console.log(`  Initial token supply: ${formatTokens(INITIAL_SUPPLY)} tokens`);
    console.log(`  Initial price: ${parseFloat(formatEther(initialPrice)).toFixed(15)} ETH per token`);
    console.log(`  Target: Deplete ~1B tokens (${formatTokens(INITIAL_SUPPLY)})`);
    console.log("  -------------------------------------------------------------------------------------------------------------------");

    // Aggressive buying strategy
    let tokensSoldTotal = 0n;
    const targetTokens = (INITIAL_SUPPLY * 999n) / 1000n; // Target 99.9% of supply
    let buyAmount = ethers.parseEther("1.0"); // Start with 1 ETH
    let totalEthSpent = 0n;
    let buyCount = 0;
    const depletionTableData = [];

    console.log(`\n  🚀 Starting aggressive buying to reach ${formatTokens(targetTokens)} tokens sold...`);

    while (tokensSoldTotal < targetTokens && buyCount < 100) {
      const tokensLeftBefore = await pool.balanceOf(pool.target);
      if (tokensLeftBefore === 0n) {
        console.log("\n  ✅ All tokens depleted.");
        break;
      }

      try {
        const balanceBefore = await pool.balanceOf(buyer.address);
        await pool.connect(buyer).buy({ value: buyAmount });
        const balanceAfter = await pool.balanceOf(buyer.address);
        const tokensReceived = balanceAfter - balanceBefore;
        
        tokensSoldTotal += tokensReceived;
        totalEthSpent += buyAmount;
        buyCount++;

        const currentPrice = await pool.calculateCurrentPrice();
        const priceMultiplier = Number(currentPrice * 1000000n / initialPrice) / 1000000;
        const tokensLeftAfter = await pool.balanceOf(pool.target);

        depletionTableData.push({
          "Buy #": buyCount,
          "ETH Spent": parseFloat(formatEther(buyAmount)).toFixed(4),
          "Tokens Received": formatTokens(tokensReceived),
          "Total Tokens Sold": formatTokens(tokensSoldTotal),
          "Tokens Left": formatTokens(tokensLeftAfter),
          "Current Price (ETH)": parseFloat(formatEther(currentPrice)).toFixed(12),
          "Price Multiplier": `${priceMultiplier.toFixed(2)}x`
        });

        // Double the buy amount for the next iteration
        buyAmount *= 2n;

      } catch (error) {
        console.log(`\n  ❌ Buy #${buyCount + 1} failed: ${error.message}`);
        console.log(`     - Attempted buy amount: ${formatEther(buyAmount)} ETH`);
        console.log(`     - Tokens left: ${formatTokens(tokensLeftBefore)}`);
        break;
      }
    }

    console.log("\n  --- Depletion Simulation Results ---");
    console.table(depletionTableData);
    console.log("  -------------------------------------------------------------------------------------------------------------------");

    // Final state
    const finalPrice = await pool.calculateCurrentPrice();
    const finalPriceMultiplier = Number(finalPrice * 1000000n / initialPrice) / 1000000;
    const finalTokensLeft = await pool.balanceOf(pool.target);
    const finalPercentSold = Number(tokensSoldTotal * 100n / INITIAL_SUPPLY);

    console.log(`\n  🎯 FINAL RESULTS:`);
    console.log(`  Total ETH required: ${formatEther(totalEthSpent)} ETH`);
    console.log(`  Total ETH required (USD): ${formatUsd(ethToUsd(totalEthSpent, ethToUsdRate))}`);
    console.log(`  Total buys executed: ${buyCount}`);
    console.log(`  Tokens sold: ${formatTokens(tokensSoldTotal)} (${finalPercentSold.toFixed(2)}% of supply)`);
    console.log(`  Tokens remaining: ${formatTokens(finalTokensLeft)}`);
    console.log(`  Final price: ${parseFloat(formatEther(finalPrice)).toFixed(15)} ETH per token`);
    console.log(`  Price increase: ${finalPriceMultiplier.toFixed(2)}x from initial`);

    // Assertions
    expect(totalEthSpent).to.be.gt(0);
    expect(tokensSoldTotal).to.be.gt(0);
  });
}); 
