import "@nomiclabs/hardhat-ethers";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-gas-reporter";
require("dotenv").config();

const PRIVATE_KEY = process.env.PRIVATE_KEY;
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL;
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY;
const CMC_API_KEY = process.env.CMC_API_KEY;

export const solidity={
version: "0.8.26",
settings: {
optimizer: {
enabled: true,
runs: 2000
}
}
};
export const defaultNetwork="hardhat";
export const networks={
hardhat: {
// Optional future-proof fork block setup
forking: {
url: SEPOLIA_RPC_URL||"",
enabled: false
}
},
localhost: {},
sepolia: {
url: SEPOLIA_RPC_URL,
accounts: PRIVATE_KEY? [PRIVATE_KEY]:[]
}
};
export const gasReporter={
enabled: true,
currency: "USD",
coinmarketcap: CMC_API_KEY,
token: "ETH",
excludeContracts: ["mocks/","test/"]
};
export const etherscan={
apiKey: ETHERSCAN_API_KEY
};
export const mocha={
timeout: 120000 // allows deep simulation or fuzzing rounds
};
export const paths={
sources: "./contracts",
tests: "./test",
cache: "./cache",
artifacts: "./artifacts"
};