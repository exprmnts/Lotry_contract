const hre = require("hardhat");
require("dotenv").config();
const Moralis = require("moralis").default;


// --- Moralis Integration ---

// Addresses to exclude from token owner results
const EXCLUDED_ADDRESSES = new Set([
  "0x9dbbBfBb5e2b1b2C5754becECa4E1e473b852a65".toLowerCase(), // mainnet admin address
  "0x3513C0F1420b7D4793158Ae5eb5985BBf34d5911".toLowerCase(), // sepolia admin address
  // "".toLowerCase(), // Winner address
]);

const getTokenOwnersAndBalances = async (tokenAddress, moralisChain) => {

  try {
    if (!Moralis.Core.isStarted) {
      await Moralis.start({
        apiKey: process.env.MORALIS_API_KEY,
      });
    }

    const response = await Moralis.EvmApi.token.getTokenOwners({
      chain: moralisChain,
      tokenAddress: tokenAddress,
    });

    const owners = response?.result || [];

    // Filter out the token address from owners and map to wallets and balances
    const filteredOwners = owners.filter((owner) => {
      const addr = owner.ownerAddress.toLowerCase();
      return addr !== tokenAddress.toLowerCase() && !EXCLUDED_ADDRESSES.has(addr);
    });
    const wallets = filteredOwners.map((owner) => owner.ownerAddress);
    const balances = filteredOwners.map((owner) =>
      BigInt(owner.balance)
    );

    console.log(wallets, balances);

    return { wallets, balances };
  } catch (e) {
    console.error(`Error fetching token owners for ${tokenAddress}:`, e.message);
    return { wallets: [], balances: [] };
  }
};


// --- Script ---
//
// Add utility to filter out contract addresses that cannot receive plain ETH
async function filterPayableAddresses(provider, wallets, balances) {
  const payableWallets = [];
  const payableBalances = [];

  // Fetch code for all addresses in parallel
  const codes = await Promise.all(wallets.map((w) => provider.getCode(w)));

  for (let i = 0; i < wallets.length; i++) {
    const isContract = codes[i] && codes[i] !== "0x";
    if (isContract) {
      console.warn(`⏭️  Skipping ${wallets[i]} – detected contract address (cannot receive simple ETH transfers)`);
      continue;
    }
    payableWallets.push(wallets[i]);
    payableBalances.push(balances[i]);
  }

  return { wallets: payableWallets, balances: payableBalances };
}

// Usage:
//   npx hardhat run scripts/pullLiquidity.js --network <network> -- <POOL_CONTRACT_ADDRESS>
// OR set CONTRACT_ADDRESS in your .env and omit the CLI argument.

async function main() {
  const { ethers, config } = hre;
  const networkName = hre.network.name;

  const MORALIS_CHAIN = config.moralisChains?.[networkName];

  if (!MORALIS_CHAIN) {
    console.error(`Moralis chain not configured for network "${networkName}" in hardhat.config.js`);
    process.exit(1);
  }
  console.log(`Using Moralis chain for ${networkName}: ${MORALIS_CHAIN}`);


  // Get target contract address either from CLI arg or environment variable
  const args = process.argv.slice(2);
  const CONTRACT_ADDRESS = args[0] || process.env.CONTRACT_ADDRESS;

  if (!CONTRACT_ADDRESS) {
    console.error("Usage: npx hardhat run scripts/pullLiquidity.js --network <network> -- <POOL_CONTRACT_ADDRESS>");
    console.error("Alternatively, set the CONTRACT_ADDRESS in your .env file.");
    process.exit(1);
  }

  // --- Get Token Holders and Balances from Moralis ---
  console.log("Fetching token holders from Moralis...");
  const { wallets: rawWallets, balances: rawBalances } = await getTokenOwnersAndBalances(CONTRACT_ADDRESS, MORALIS_CHAIN);

  // Filter out contract addresses that would revert on direct ETH transfers
  const filtered = await filterPayableAddresses(hre.ethers.provider, rawWallets, rawBalances);
  const wallets = filtered.wallets;
  const balances = filtered.balances;

  if (wallets.length === 0) {
    console.error("No token holders found. Exiting.");
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

  // --- Calculate ETH Distribution ---
  const contractBalance = await provider.getBalance(CONTRACT_ADDRESS);
  if (contractBalance === 0n) {
    console.error("\nNo liquidity to pull. Contract ETH balance is 0. Exiting.");
    return;
  }

  // ---- Recompute distribution after filtering ----
  const contractBalanceFiltered = contractBalance; // remains the same
  const totalTokenSupplyFiltered = balances.reduce((acc, val) => acc + val, 0n);
  const amounts = [];
  let totalAmountDistributedFiltered = 0n;

  for (let i = 0; i < balances.length - 1; i++) {
    const amount = (balances[i] * contractBalanceFiltered) / totalTokenSupplyFiltered;
    amounts.push(amount);
    totalAmountDistributedFiltered += amount;
  }

  const remainingBalance = contractBalanceFiltered - totalAmountDistributedFiltered;
  amounts.push(remainingBalance);

  // After computing amounts
  console.log(`Prepared ${wallets.length} recipient(s).`);
  if (wallets.length !== amounts.length) {
    console.error(`Mismatch: wallets (${wallets.length}) vs amounts (${amounts.length}). Aborting to avoid revert.`);
    process.exit(1);
  }

  // Try a static call to detect reverts and log reason before spending gas
  try {
    // Ethers v6: use .staticCall on the function fragment
    await pool.pullLiquidity.staticCall(wallets, amounts, { gasLimit: 500000 });
  } catch (staticErr) {
    console.error("[DRY-RUN] pullLiquidity would revert:", staticErr?.reason || staticErr?.errorName || staticErr);
    process.exit(1);
  }

  // --- Pre-pull Status ---
  console.log("\n--- Status Before pullLiquidity ---");

  // Check liquidity status
  var contractTokenBalance = await pool.balanceOf(CONTRACT_ADDRESS);
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
  console.log("\nCalling pullLiquidity with the following distributions:");
  for (let i = 0; i < wallets.length; i++) {
    console.log(`  - Wallet: ${wallets[i]}, Amount: ${ethers.formatEther(amounts[i])} ETH`);
  }

  const tx = await pool.pullLiquidity(wallets, amounts, { gasLimit: 500000 });
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