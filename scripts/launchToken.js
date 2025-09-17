const hre = require("hardhat");
require("dotenv").config();

async function main() {
    // Address of the deployed TokenLaunchpad contract from .env file
    const tokenLaunchpadAddress = process.env.CONTRACT_ADDRESS; 

    // Details for the new token
    // TODO: Replace with your token name and symbol
    const TOKEN_NAME = "My New Token"; 
    const TOKEN_SYMBOL = "MNT"; 

    if (!tokenLaunchpadAddress) {
        console.error("Please set TOKEN_LAUNCHPAD_ADDRESS in your .env file");
        process.exit(1);
    }
    
    if (!process.env.PRIVATE_KEY) {
        console.error("Please set PRIVATE_KEY in your .env file");
        process.exit(1);
    }

    // Use the private key from .env to create a wallet
    const wallet = new hre.ethers.Wallet(process.env.PRIVATE_KEY, hre.ethers.provider);
    console.log("Launching token with the account:", wallet.address);

    // Get the contract instance and connect it to our wallet
    const tokenLaunchpad = await hre.ethers.getContractAt("TokenLaunchpad", tokenLaunchpadAddress, wallet);

    console.log(`Launching token "${TOKEN_NAME}" (${TOKEN_SYMBOL}) from launchpad at ${tokenLaunchpadAddress}`);

    // Call the launchToken function
    const tx = await tokenLaunchpad.launchToken(TOKEN_NAME, TOKEN_SYMBOL);
    
    console.log("Transaction sent. Waiting for confirmation...");
    
    const receipt = await tx.wait();

    if (!receipt) {
        console.error("Transaction failed, receipt is null.");
        return;
    }

    // Find the TokenCreated event in the transaction receipt
    const event = receipt.logs.find(e => e.eventName === 'TokenCreated');
    
    if (event) {
        const { tokenAddress, name, symbol } = event.args;
        console.log(`Token "${name}" (${symbol}) successfully created at address: ${tokenAddress}`);
    } else {
        console.log("TokenCreated event not found in the transaction receipt. The token might not have been created.");
    }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
