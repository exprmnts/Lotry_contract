const { ethers } = require("hardhat");


async function main() {
    const privateKey = process.env.PRIVATE_KEY;
    const deployer = new ethers.Wallet(privateKey, ethers.provider);
    console.log("Interacting with contracts with the account:", deployer.address);

    const poolAddress = process.env.CONTRACT_ADDRESS; // TODO: replace with your contract address

    if (poolAddress === null || poolAddress === "") {
        console.error("Please replace CONTRACT_ADDRESS with the actual contract address.");
        process.exit(1);
    }


    const pool = await ethers.getContractAt("BondingCurvePool", poolAddress, deployer);

    console.log("Calling pullLiquidity...");
    const tx = await pool.pullLiquidity();
    await tx.wait();

    console.log("Liquidity pulled successfully. Transaction hash:", tx.hash);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
