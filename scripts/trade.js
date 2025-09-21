const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    console.error("Please set the PRIVATE_KEY environment variable.");
    process.exit(1);
  }

  const deployer = new ethers.Wallet(privateKey, ethers.provider);
  console.log("Interacting with contracts with the account:", deployer.address);

  const poolAddress = process.env.CONTRACT_ADDRESS;
  if (!poolAddress) {
    console.error("Please set the CONTRACT_ADDRESS environment variable.");
    process.exit(1);
  }

  const pool = await ethers.getContractAt(
    "BondingCurvePool",
    poolAddress,
    deployer
  );

  // --- To Buy Tokens ---
  // 1. Uncomment the following block to buy tokens.
  // 2. Set the amount of ETH to spend in `ethToSpend`.

  const ethToSpend = ethers.parseEther("0.001");
  console.log(
    `Attempting to buy tokens with ${ethers.formatEther(
      ethToSpend
    )} ETH...`
  );
  const buyTx = await pool.buy({ value: ethToSpend });
  console.log("Transaction sent, waiting for confirmation...");
  await buyTx.wait();
  console.log("Tokens bought successfully. Transaction hash:", buyTx.hash);

  // --- To Sell Tokens ---
  // 1. Uncomment the following block to sell tokens.
  // 2. Set the amount of tokens to sell in `tokensToSell`.
  /*
    const tokensToSell = ethers.parseEther("1000"); // Example: 1000 tokens
    console.log(`Attempting to sell ${ethers.formatEther(tokensToSell)} tokens...`);
    const sellTx = await pool.sell(tokensToSell);
    console.log("Transaction sent, waiting for confirmation...");
    await sellTx.wait();
    console.log("Tokens sold successfully. Transaction hash:", sellTx.hash);
    */
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
