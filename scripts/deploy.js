const hre = require("hardhat");
const { ethers } = require("hardhat");

const parseEther = ethers.parseEther;

// Contract Files
const TokenLaunchpad = 'TokenLaunchpad'

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Deploy the TokenLaunchpad contract
  const contract = await hre.ethers.getContractFactory(TokenLaunchpad);
  const contract_dep = await contract.deploy(deployer.address);

  await contract_dep.waitForDeployment();
  console.log("TokenLaunchpad deployed to:", await contract_dep.getAddress());

  // Deploy token contract, if not requied jus commments out below lines
  // const tokenName = "ETH COIN";
  // const tokenSymbol = "ETC";
  // const initialLotteryPool = parseEther("1.0");

  // console.log("Launching token...");
  // const tx = await contract_dep.launchToken(tokenName, tokenSymbol, initialLotteryPool);
  // const receipt = await tx.wait();

  // console.log("Transaction hash:", receipt.hash);

  // // Find the TokenCreated event to get the new pool's address
  // const event = receipt.logs.find(log => log.eventName === 'TokenCreated');

  // if (event) {
  //   const poolAddress = event.args.tokenAddress;
  //   console.log("Token/Pool deployed to:", poolAddress);

  //   // Optionally attach to the deployed pool contract
  //   // const BondingCurvePool = await hre.ethers.getContractFactory("BondingCurvePool");
  //   // const pool = BondingCurvePool.attach(poolAddress);
  //   // console.log("Pool contract attached successfully");

  //   // You can now interact with the pool contract if needed
  //   // For example, get token details:
  //   // const tokenDetails = await pool.getTokenDetails(); // if such function exists

  // } else {
  //   console.error("TokenCreated event not found in transaction receipt");
  // }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
