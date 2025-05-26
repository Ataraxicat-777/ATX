// SPDX-License-Identifier: Apache-2.0
import "dotenv/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-verify";
import "@nomiclabs/hardhat-ethers";
import "hardhat-gas-reporter";
import "@openzeppelin/hardhat-upgrades";
import "@openzeppelin/hardhat-defender";
import "hardhat-deploy";
import "@typechain/hardhat";

const { SEPOLIA_RPC_URL, PRIVATE_KEY, ETHERSCAN_API_KEY, CMC_API_KEY, ARBITRUM_SEPOLIA_RPC_URL, DAO_PRIVATE_KEY_1, DAO_PRIVATE_KEY_2 } = process.env;

if (!SEPOLIA_RPC_URL || !PRIVATE_KEY || !ETHERSCAN_API_KEY || !CMC_API_KEY) {
  throw new Error("Missing required environment variables in .env");
}

export default {
  solidity: {
    version: "0.8.26",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000
      },
      evmVersion: "paris" // Updated to latest EVM version for gas efficiency
    }
  },
  defaultNetwork: "hardhat",
  networks: {
    sepolia: {
      url: SEPOLIA_RPC_URL,
      accounts: [PRIVATE_KEY, DAO_PRIVATE_KEY_1, DAO_PRIVATE_KEY_2].filter(Boolean), // Multiple accounts for DAO testing
      chainId: 11155111
    },
    arbitrumSepolia: {
      url: ARBITRUM_SEPOLIA_RPC_URL || "https://sepolia-rollup.arbitrum.io/rpc",
      accounts: [PRIVATE_KEY, DAO_PRIVATE_KEY_1, DAO_PRIVATE_KEY_2].filter(Boolean),
      chainId: 421614
    },
    hardhat: {
      chainId: 31337,
      accounts: {
        count: 5 // For DAO multisig simulation
      },
      forking: {
        url: SEPOLIA_RPC_URL, // Optional: Fork Sepolia for testing
        enabled: false
      }
    },
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337
    }
  },
  etherscan: {
    apiKey: {
      sepolia: ETHERSCAN_API_KEY,
      arbitrumSepolia: ETHERSCAN_API_KEY // Adjust if a different API key is needed
    },
    customChains: [
      {
        network: "arbitrumSepolia",
        chainId: 421614,
        urls: {
          apiURL: "https://api-sepolia.arbiscan.io/api",
          browserURL: "https://sepolia.arbiscan.io"
        }
      }
    ]
  },
  gasReporter: {
    enabled: true,
    currency: "USD",
    coinmarketcap: CMC_API_KEY,
    outputFile: "gas-report.txt", // For DAO audit transparency
    noColors: true // Easier to parse in reports
  },
  defender: {
    apiKey: process.env.DEFENDER_API_KEY,
    apiSecret: process.env.DEFENDER_API_SECRET // For DAO proposal management
  },
  typechain: {
    outDir: "typechain-types",
    target: "ethers-v6" // Type-safe contract interactions for DApps and DAOs
  },
  mocha: {
    timeout: 60000 // Increased timeout for DAO voting tests
  },
  namedAccounts: {
    deployer: {
      default: 0 // First account as deployer
    },
    daoMember1: {
      default: 1 // For DAO multisig testing
    },
    daoMember2: {
      default: 2
    }
  }
};