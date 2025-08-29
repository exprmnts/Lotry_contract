const { ethers } = require("hardhat");

// Base Sepolia VRF Coordinator address
const BASE_VRF_COORDINATOR = process.env.VRF_COORDINATOR_BASE;
// Base Sepolia VRF KeyHash (This is often for a specific gas price, e.g., 500 Gwei on the vrf.chain.link UI for Base Sepolia)
const BASE_KEY_HASH = process.env.KEY_HASH_BASE;

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying RandomWalletPicker contract to Base Sepolia...");
  console.log(`Deploying with account: ${deployer.address} (this will be the owner)`);
  console.log("Ensure your hardhat.config.js is set up for Base Sepolia (RPC URL, private key).");

  // You need to create a subscription ID through the Chainlink VRF UI for Base Sepolia
  // and add your contract as a consumer AFTER deployment.
  // Go to: https://vrf.chain.link/ 
  const subscriptionId = process.env.SUBSCRIPTION_ID_BASE;

  if (subscriptionId === undefined) {
    console.error("ERROR: You MUST set your actual VRF subscription ID for Base Sepolia.");
    console.error("Create a subscription at https://vrf.chain.link/ (select Base Sepolia) and set BASE_SUBSCRIPTION_ID environment variable or update the script.");
    process.exit(1);
  }

  console.log(`Using Subscription ID for Base Sepolia: ${subscriptionId}`);

  // Deploy the RandomWalletPicker contract
  const RandomWalletPicker = await ethers.getContractFactory("RandomWalletPicker");
  console.log("Deploying contract with:");
  console.log(`  VRF Coordinator (Base Sepolia): ${BASE_VRF_COORDINATOR}`);
  console.log(`  Subscription ID: ${subscriptionId}`);
  console.log(`  Key Hash (Base Sepolia): ${BASE_KEY_HASH}`);

  const randomWalletPicker = await RandomWalletPicker.deploy(
    BASE_VRF_COORDINATOR,
    subscriptionId,
    BASE_KEY_HASH
  );

  await randomWalletPicker.waitForDeployment();

  const address = await randomWalletPicker.getAddress();
  console.log(`\nRandomWalletPicker deployed to Base Sepolia at: ${address}`);
  console.log("\nIMPORTANT: After deployment, you MUST add this contract address as a consumer to your VRF subscription on Base Sepolia.");
  console.log("Go to: https://vrf.chain.link/ (select Base Sepolia network), find your subscription, and add consumer.");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  }); 