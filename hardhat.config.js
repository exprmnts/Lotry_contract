require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.20",
      },
      {
        version: "0.8.24",
      },
    ],
  },
  networks: {
    hardhat: {
      // Default Hardhat network settings (if any specific needed)
      accounts: {
        accountsBalance: "10000000000000000000000000", // 10,000,000 ETH
      },
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
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL,
      accounts:[process.env.PRIVATE_KEY],
      chainId: 11155111,
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
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  moralisChains: {
    base_sepolia: "0x14a34", // Base Sepolia chainId
    base: "0x2105", // Base mainnet chainId
    sepolia: "0xaa36a7"
  }
};
