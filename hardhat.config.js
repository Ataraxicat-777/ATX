import "dotenv/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-verify";
import "@nomiclabs/hardhat-ethers";
import "hardhat-gas-reporter";

const { SEPOLIA_RPC_URL, PRIVATE_KEY, ETHERSCAN_API_KEY, CMC_API_KEY } = process.env;

if (!SEPOLIA_RPC_URL || !PRIVATE_KEY || !ETHERSCAN_API_KEY || !CMC_API_KEY) {
  throw new Error("Missing required environment variables in .env (SEPOLIA_RPC_URL, PRIVATE_KEY, ETHERSCAN_API_KEY, CMC_API_KEY)");
}

export default {
  solidity: {
    version: "0.8.21",
    settings: {
      optimizer: { enabled: true, runs: 1000 },
      evmVersion: "london",
    },
  },
  defaultNetwork: "sepolia",
  networks: {
    sepolia: {
      url: SEPOLIA_RPC_URL,
      accounts: [PRIVATE_KEY],
      chainId: 11155111,
    },
    mainnet: { // Placeholder for future use
      url: process.env.MAINNET_RPC_URL || "",
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
      chainId: 1,
    },
    hardhat: { chainId: 31337 },
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
    },
  },
  etherscan: {
    apiKey: {
      sepolia: ETHERSCAN_API_KEY,
      mainnet: process.env.ETHERSCAN_API_KEY || "", // For future use
    },
  },
  gasReporter: {
    enabled: true,
    currency: "USD",
    coinmarketcap: CMC_API_KEY,
    token: "ETH", // Explicitly set for clarity
    outputFile: "gas-report.txt", // Save report to a file
  },
  mocha: {
    timeout: 40000, // Increased timeout for slower networks
  },
};