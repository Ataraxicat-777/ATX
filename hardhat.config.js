import "dotenv/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-verify";
import "@nomiclabs/hardhat-ethers";

const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY;

export const solidity = {
  version: "0.8.20",
  settings: {
    optimizer: {
      enabled: true,
      runs: 1000, // Matches compiler_config.json for gas efficiency
    },
    evmVersion: "london", // Matches compiler_config.json
  },
};

export const defaultNetwork = "sepolia";

export const networks = {
  sepolia: {
    url: SEPOLIA_RPC_URL || "https://sepolia.infura.io/v3/YOUR_INFURA_PROJECT_ID",
    accounts: [PRIVATE_KEY],
    chainId: 11155111, // Sepolia chain ID
  },
  hardhat: {
    chainId: 31337, // Default Hardhat chain ID
  },
  localhost: {
    url: "http://127.0.0.1:8545",
    chainId: 31337,
  },
  // Goerli remains commented out as it is deprecated
  /*
  goerli: {
    url: process.env.GOERLI_RPC_URL || "https://goerli.infura.io/v3/YOUR_INFURA_PROJECT_ID",
    accounts: [process.env.PRIVATE_KEY],
    chainId: 5,
  },
  */
};

export const etherscan = {
  apiKey: {
    sepolia: ETHERSCAN_API_KEY,
  },
};