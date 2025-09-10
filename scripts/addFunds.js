const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    console.error("Please provide a PRIVATE_KEY in your .env file.");
    process.exit(1);
  }
  const deployer = new ethers.Wallet(privateKey, ethers.provider);
  console.log("Adding funds with the account:", deployer.address);

  const poolAddress = "";
  const ethAmount = "";

  if (!ethers.isAddress(poolAddress)) {
    console.error("Invalid pool address provided.");
    process.exit(1);
  }

  const parsedEthAmount = ethers.parseEther(ethAmount);

  console.log(`Attaching to pool at address: ${poolAddress}`);
  const BondingCurvePool = await ethers.getContractFactory("BondingCurvePool", deployer);
  const pool = BondingCurvePool.attach(poolAddress);

  console.log(`Adding ${ethAmount} ETH to the lottery pot...`);

  const tx = await pool.addFundsToLotteryPot({ value: parsedEthAmount });
  await tx.wait();

  console.log("Funds added successfully!");
  console.log("Transaction hash:", tx.hash);

  const accumulatedPoolFee = await pool.accumulatedPoolFee();
  const potRaised = await pool.potRaised();

  console.log(`New accumulated pool fee: ${ethers.formatEther(accumulatedPoolFee)} ETH`);
  console.log(`Pot raised status: ${potRaised}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
