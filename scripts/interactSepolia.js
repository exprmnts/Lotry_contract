const { ethers } = require("hardhat");
const { expect } = require("chai");

async function main() {
  // Replace with your deployed contract address
  const CONTRACT_ADDRESS = "0x38eade322F5dE73DC5bc553528bC51ae15FAee1D";

  console.log("Interacting with Counter contract on Sepolia...");
  console.log("Contract Address:", CONTRACT_ADDRESS);

  // Get the signer
  const [signer] = await ethers.getSigners();
  console.log("Using account:", signer.address);

  // Get contract instance
  const Launchpad = await ethers.getContractFactory("TokenLaunchpad");
  const launchpad = Launchpad.attach(CONTRACT_ADDRESS);

  const tokenName = "DOGE COIN";
  const tokenSymbol = "DOGE";
  const initialLotteryPool = ethers.parseEther("0.1");
  const buyAmount = ethers.parseEther("0.001");

  try {
    console.log("----LauchToken----");

    // Launch a new Pool using the Launchpad
    let tx = await launchpad.launchToken(tokenName, tokenSymbol, initialLotteryPool, signer.address);
    const receipt = await tx.wait();

    // Method 1: Parse events from transaction receipt
    console.log("\n=== Parsing Events from Receipt ===");

    // Parse all events from the receipt
    const parsedEvents = receipt.logs.map(log => {
      try {
        // Try to parse with launchpad interface first
        return launchpad.interface.parseLog(log);
      } catch (error) {
        // If that fails, it might be from another contract
        return null;
      }
    }).filter(event => event !== null);

    // Print all parsed events
    parsedEvents.forEach((event, index) => {
      console.log(`Event ${index + 1}: ${event.name}`);
      console.log('Arguments:', event.args);

      // Print individual arguments
      for (let i = 0; i < event.args.length; i++) {
        console.log(`  Arg ${i} (${event.fragment.inputs[i].name}):`, event.args[i].toString());
      }
      console.log('---');
    });

    // Find the TokenCreated event specifically
    const tokenCreatedEvent = parsedEvents.find(event => event.name === 'TokenCreated');
    if (tokenCreatedEvent) {
      console.log("TokenCreated Event Details:");
      console.log("  Token Address:", tokenCreatedEvent.args.tokenAddress);
      console.log("  Creator:", tokenCreatedEvent.args.creator);
      console.log("  Token Name:", tokenCreatedEvent.args.name);
      console.log("  Token Symbol:", tokenCreatedEvent.args.symbol);

      const poolAddress = tokenCreatedEvent.args.tokenAddress;

      console.log("\n----BUY----");

      // Attach to the deployed pool contract
      const BondingCurvePool = await ethers.getContractFactory("BondingCurvePool");
      const pool = BondingCurvePool.attach(poolAddress);

      // Execute buy transaction
      const buyTx = await pool.connect(signer).buy({ value: buyAmount });
      const buyReceipt = await buyTx.wait();

      // Parse buy events
      console.log("\n=== Buy Transaction Events ===");
      const buyEvents = buyReceipt.logs.map(log => {
        try {
          return pool.interface.parseLog(log);
        } catch (error) {
          return null;
        }
      }).filter(event => event !== null);

      buyEvents.forEach((event, index) => {
        console.log(`Buy Event ${index + 1}: ${event.name}`);
        console.log('Arguments:', event.args);

        // Print individual arguments with names
        for (let i = 0; i < event.args.length; i++) {
          const argName = event.fragment.inputs[i].name;
          const argValue = event.args[i];
          console.log(`  ${argName}:`, argValue.toString());
        }
        console.log('---');
      });

      // Check token balance after buy
      const tokenBalance = await pool.balanceOf(signer.address);
      console.log("Token balance after buy:", ethers.formatEther(tokenBalance));

      // Get ETH balance before sell
      const ethBalanceBeforeSell = await ethers.provider.getBalance(signer.address);
      console.log("ETH balance before sell:", ethers.formatEther(ethBalanceBeforeSell));

      console.log("\n----SELL----");

      // Get the amount of tokens to sell (all tokens owned by user)
      const tokensToSell = await pool.balanceOf(signer.address);
      console.log("Tokens to sell:", ethers.formatEther(tokensToSell));

      if (tokensToSell > 0n) {
        // Execute sell transaction
        const sellTx = await pool.connect(signer).sell(tokensToSell);
        const sellReceipt = await sellTx.wait();

        // Parse sell events
        console.log("\n=== Sell Transaction Events ===");
        const sellEvents = sellReceipt.logs.map(log => {
          try {
            return pool.interface.parseLog(log);
          } catch (error) {
            return null;
          }
        }).filter(event => event !== null);

        sellEvents.forEach((event, index) => {
          console.log(`Sell Event ${index + 1}: ${event.name}`);
          console.log('Arguments:', event.args);

          // Print individual arguments with names
          for (let i = 0; i < event.args.length; i++) {
            const argName = event.fragment.inputs[i].name;
            const argValue = event.args[i];

            // Format different types appropriately
            if (argName.includes('Amount') || argName.includes('amount')) {
              console.log(`  ${argName}:`, ethers.formatEther(argValue), 'ETH/Tokens');
            } else if (argName.includes('address') || argName.includes('Address')) {
              console.log(`  ${argName}:`, argValue);
            } else {
              console.log(`  ${argName}:`, argValue.toString());
            }
          }
          console.log('---');
        });

        // Check balances after sell
        const finalTokenBalance = await pool.balanceOf(signer.address);
        const ethBalanceAfterSell = await ethers.provider.getBalance(signer.address);

        console.log("\n=== Post-Sell Balances ===");
        console.log("Final token balance:", ethers.formatEther(finalTokenBalance));
        console.log("ETH balance after sell:", ethers.formatEther(ethBalanceAfterSell));
        console.log("ETH gained from sell:", ethers.formatEther(ethBalanceAfterSell - ethBalanceBeforeSell));

        // Verify the sell was successful
        if (finalTokenBalance === 0n) {
          console.log("✅ All tokens successfully sold!");
        } else {
          console.log("⚠️ Some tokens remain unsold");
        }

      } else {
        console.log("No tokens to sell!");
      }

      // Method 2: Using event filters (for historical events)
      console.log("\n=== Using Event Filters ===");

      // Get TokenCreated events from the last few blocks
      const currentBlock = await ethers.provider.getBlockNumber();
      const tokenCreatedFilter = launchpad.filters.TokenCreated();
      const historicalEvents = await launchpad.queryFilter(tokenCreatedFilter, currentBlock - 10, currentBlock);

      console.log(`Found ${historicalEvents.length} TokenCreated events in last 10 blocks:`);
      historicalEvents.forEach((event, index) => {
        console.log(`Historical Event ${index + 1}:`);
        console.log('  Block:', event.blockNumber);
        console.log('  Transaction:', event.transactionHash);
        console.log('  Token Address:', event.args.tokenAddress);
        console.log('  Creator:', event.args.creator);
        console.log('  Name:', event.args.name);
        console.log('  Symbol:', event.args.symbol);
      });

    } else {
      console.log("TokenCreated event not found in transaction receipt");
    }

    // Method 3: Real-time event listening (for future events)
    console.log("\n=== Setting up Real-time Event Listeners ===");

    // Set up event listeners for future events
    launchpad.on("TokenCreated", (tokenAddress, creator, name, symbol, event) => {
      console.log("\n🎉 New TokenCreated Event Received:");
      console.log("  Token Address:", tokenAddress);
      console.log("  Creator:", creator);
      console.log("  Name:", name);
      console.log("  Symbol:", symbol);
      console.log("  Block Number:", event.log.blockNumber);
      console.log("  Transaction Hash:", event.log.transactionHash);
    });

    // Note: BuyEvent and SellEvent are likely on the pool contract, not launchpad
    // Set up listeners on the pool contract for buy/sell events:
    if (tokenCreatedEvent) {
      const poolAddress = tokenCreatedEvent.args.tokenAddress;
      const BondingCurvePool = await ethers.getContractFactory("BondingCurvePool");
      const pool = BondingCurvePool.attach(poolAddress);

      pool.on("BuyEvent", (buyer, ethAmount, tokenAmount, event) => {
        console.log("\n💰 New BuyEvent:");
        console.log("  Buyer:", buyer);
        console.log("  ETH Amount:", ethers.formatEther(ethAmount));
        console.log("  Token Amount:", ethers.formatEther(tokenAmount));
        console.log("  Block:", event.log.blockNumber);
      });

      pool.on("SellEvent", (seller, tokenAmount, ethAmount, event) => {
        console.log("\n💸 New SellEvent:");
        console.log("  Seller:", seller);
        console.log("  Token Amount:", ethers.formatEther(tokenAmount));
        console.log("  ETH Amount:", ethers.formatEther(ethAmount));
        console.log("  Block:", event.log.blockNumber);
      });
    }

    console.log("Event listeners set up. Waiting for new events...");

    // Keep the script running to listen for events
    // In a real application, you might want to handle this differently
    setTimeout(() => {
      console.log("Stopping event listeners...");
      launchpad.removeAllListeners();
      process.exit(0);
    }, 30000); // Listen for 30 seconds

  } catch (error) {
    console.error("Error interacting with contract:", error);

    // Print more detailed error information
    if (error.receipt) {
      console.error("Transaction failed. Receipt:", error.receipt);
    }
    if (error.reason) {
      console.error("Revert reason:", error.reason);
    }
  }
}

main()
  .then(() => {
    console.log("\nInteraction completed!");
  })
  .catch((error) => {
    console.error("Error:", error);
    process.exit(1);
  });
