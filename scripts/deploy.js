const hre = require("hardhat");

// Contract Files
const TokenLaunchpad = "TokenLaunchpad";

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Deploy the TokenLaunchpad contract
  const contract = await hre.ethers.getContractFactory(TokenLaunchpad);
  const contract_dep = await contract.deploy(deployer.address);

  await contract_dep.waitForDeployment();
  console.log("TokenLaunchpad deployed to:", await contract_dep.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
