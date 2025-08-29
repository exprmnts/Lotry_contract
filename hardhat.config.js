require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.20",
  networks: {
    hardhat: {
      // Default Hardhat network settings (if any specific needed)
    },
    base_sepolia: {
      url: process.env.BASE_SEPOLIA_RPC_URL,
      accounts:[process.env.PRIVATE_KEY],
      chainId: 84532,
    },
    base: {
      url: process.env.BASE_MAINNET_RPC_URL,
      accounts:[process.env.PRIVATE_KEY],
      chainId: 8453,
    },
  },
  etherscan: {
    // Optional: Add API key for contract verification on Basescan
    // apiKey: {
    //   baseSepolia: process.env.BASESCAN_API_KEY 
    // },
    // customChains: [
    //   {
    //     network: "baseSepolia",
    //     chainId: 84532,
    //     urls: {
    //       apiURL: "https://api-sepolia.basescan.org/api",
    //       browserURL: "https://sepolia.basescan.org"
    //     }
    //   }
    // ]
  }
};
