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

  // Use ALL wallets exactly as returned – no filtering. We will handle potential
  // send failures *after* withdrawing the ETH to the owner, so a failed send to
  // one address never blocks the others.
  const wallets = rawWallets;
  const balances = rawBalances;

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

  // === Strategy change ===
  // 1. Withdraw *all* ETH from the pool to the owner in a single-recipient
  //    pullLiquidity call. This cannot fail because `owner` is EOA & payable.
  // 2. Off-chain, redistribute ETH to every wallet individually. If a single
  //    transaction reverts (e.g. wallet is a non-payable contract), we catch
  //    the error and keep moving so the rest still receive their share.

  // --- Step 1: withdraw to owner ---
  try {
    await pool.pullLiquidity.staticCall([ownerSigner.address], [contractBalance], { gasLimit: 150_000 });
  } catch (staticErr) {
    console.error("[DRY-RUN] pullLiquidity to owner would revert:", staticErr?.reason || staticErr?.errorName || staticErr);
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

  console.log("\nWithdrawing entire pool balance to owner...");
  const withdrawTx = await pool.pullLiquidity([ownerSigner.address], [contractBalance], { gasLimit: 150_000 });
  console.log(`Withdrawal tx: ${withdrawTx.hash}`);
  await withdrawTx.wait();
  console.log("Liquidity pulled to owner ✅");

  // --- Step 2: redistribute ---
  console.log("\nRedistributing ETH to holders (this happens off-chain)...");

  let successes = 0;
  let failures = 0;
  for (let i = 0; i < wallets.length; i++) {
    const wallet = wallets[i];
    const amount = amounts[i];

    // Skip the owner – they already hold the entire balance.
    if (wallet.toLowerCase() === ownerSigner.address.toLowerCase()) {
      continue;
    }

    if (amount === 0n) {
      continue;
    }

    try {
      const tx = await ownerSigner.sendTransaction({
        to: wallet,
        value: amount,
        gasLimit: 21_000,
      });
      console.log(`✓ Sent ${ethers.formatEther(amount)} ETH to ${wallet} (tx: ${tx.hash})`);
      successes++;
    } catch (err) {
      console.error(`✗ Failed to send ${ethers.formatEther(amount)} ETH to ${wallet}:`, err?.reason || err);
      failures++;
    }
  }

  console.log(`\nRedistribution finished. Successes: ${successes}, Failures: ${failures}`);

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