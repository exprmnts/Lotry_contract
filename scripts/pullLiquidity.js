const hre = require("hardhat");
require("dotenv").config();

// Usage:
//   npx hardhat run scripts/pullLiquidity.js --network <network> -- <POOL_CONTRACT_ADDRESS>
// OR set CONTRACT_ADDRESS in your .env and omit the CLI argument.

async function main() {
  const { ethers } = hre;

  // Get target contract address either from CLI arg or environment variable
  const args = process.argv.slice(2);
  const CONTRACT_ADDRESS = args[0] || process.env.CONTRACT_ADDRESS;

  if (!CONTRACT_ADDRESS) {
    console.error("ERROR: You must supply the BondingCurvePool contract address as a CLI argument or set CONTRACT_ADDRESS in your .env file.");
    process.exit(1);
  }

  // Load owner wallet from PRIVATE_KEY in .env
  const { PRIVATE_KEY } = process.env;
  if (!PRIVATE_KEY) {
    console.error("ERROR: PRIVATE_KEY not set in .env file.");
    process.exit(1);
  }

  // Use Hardhat's provider for the selected network
  const provider = ethers.provider;
  const ownerSigner = new ethers.Wallet(PRIVATE_KEY, provider);

  console.log(`Using owner address: ${ownerSigner.address}`);
  console.log(`Interacting with BondingCurvePool at: ${CONTRACT_ADDRESS}`);

  // Get contract instance
  const BondingCurvePool = await ethers.getContractFactory("BondingCurvePool");
  const pool = BondingCurvePool.attach(CONTRACT_ADDRESS).connect(ownerSigner);

  // Verify on-chain owner matches signer
  const onChainOwner = await pool.owner();
  console.log(`Pool owner (on-chain): ${onChainOwner}`);
  if (onChainOwner.toLowerCase() !== ownerSigner.address.toLowerCase()) {
    console.error("ERROR: The signer is not the owner of this pool contract. Aborting to prevent revert.");
    process.exit(1);
  }

  // --- Pre-pull Status ---
  console.log("\n--- Status Before pullLiquidity ---");

  // Check liquidity status
  var contractTokenBalance = await pool.balanceOf(CONTRACT_ADDRESS);
  var contractBalance = await provider.getBalance(CONTRACT_ADDRESS);
  var ownerTokenBalance = await pool.balanceOf(ownerSigner.address);
  var ownerEthBalance = await provider.getBalance(ownerSigner.address);

  console.log(`Contract Token Balance: ${ethers.formatUnits(contractTokenBalance, 18)} tokens`);
  console.log(`Contract ETH balance: ${ethers.formatEther(contractBalance)} ETH`);
  console.log(`Owner Token Balance: ${ethers.formatUnits(ownerTokenBalance, 18)} tokens`);
  console.log(`Owner ETH balance: ${ethers.formatEther(ownerEthBalance)} ETH`);

  if (contractBalance === 0n) {
    console.error("\nNo liquidity to pull. Contract ETH balance is 0. Exiting.");
    return;
  }

  // Call pullLiquidity
  console.log("\nCalling pullLiquidity ...");
  const tx = await pool.pullLiquidity();
  console.log(`Transaction submitted: ${tx.hash}`);

  await tx.wait();
  console.log("pullLiquidity executed successfully ✅");

  // --- Post-pull Status ---
  console.log("\n--- Status After pullLiquidity ---");
  var contractBalanceAfter = await provider.getBalance(CONTRACT_ADDRESS);
  var ownerTokenBalanceAfter = await pool.balanceOf(ownerSigner.address);
  var contractTokenBalanceAfter = await pool.balanceOf(CONTRACT_ADDRESS);
  var ownerEthBalanceAfter = await provider.getBalance(ownerSigner.address);

  console.log(`Contract Token Balance: ${ethers.formatUnits(contractTokenBalanceAfter, 18)} tokens`);
  console.log(`Contract ETH balance: ${ethers.formatEther(contractBalanceAfter)} ETH`);
  console.log(`Owner Token Balance: ${ethers.formatUnits(ownerTokenBalanceAfter, 18)} tokens`);
  console.log(`Owner ETH balance: ${ethers.formatEther(ownerEthBalanceAfter)} ETH`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 