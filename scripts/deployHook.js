import hre from "hardhat";
import "dotenv/config";

async function main() {
  if (!process.env.PRIVATE_KEY) {
    throw new Error("Please set your PRIVATE_KEY in a .env file");
  }
  const wallet = new hre.ethers.Wallet(
    process.env.PRIVATE_KEY,
    hre.ethers.provider
  );
  console.log("Deploying contracts with the account:", wallet.address);

  // Addresses for Sepolia
  const poolManagerAddress = "0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408";
  const wethAddress = "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9";
  const treasuryAddress = process.env.CONTRACT_ADDRESS; // Taxes will be sent here

  const TaxHook = await hre.ethers.getContractFactory("TaxHook", wallet);
  const taxHook = await TaxHook.deploy(
    poolManagerAddress,
    wethAddress,
    treasuryAddress
  );

  await taxHook.waitForDeployment();

  console.log("TaxHook deployed to:", await taxHook.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
