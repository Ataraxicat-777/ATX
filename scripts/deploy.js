import { ethers, network } from "hardhat";
import fs from "fs/promises";
import type { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import type { ATXIAGovernanceFinal } from "../typechain-types";

async function main() {
  const [deployer]: HardhatEthersSigner[] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  const networkName: string = network.name;
  console.log("Deploying to network:", networkName);

  // Ensure we're on Sepolia
  const { chainId } = await ethers.provider.getNetwork();
  if (networkName === "sepolia" && chainId !== 11155111) {
    throw new Error("Expected Sepolia chain ID 11155111, but got " + chainId);
  }

  // Estimate gas price dynamically
  const feeData = await ethers.provider.getFeeData();
  const gasPrice = feeData.gasPrice ? feeData.gasPrice * BigInt(12) / BigInt(10) : undefined; // Add 20% buffer

  // Deploy the contract
  const ATXIAFactory = await ethers.getContractFactory("ATXIAGovernanceFinal");
  const initialOwner: string = deployer.address;
  console.log("Deploying ATXIAGovernanceFinal with initial owner:", initialOwner);

  const contract: ATXIAGovernanceFinal = await ATXIAFactory.deploy(initialOwner, {
    gasLimit: 3000000,
    gasPrice,
  });

  console.log("Waiting for deployment confirmation...");
  const deploymentReceipt = await contract.deploymentTransaction()?.wait(5); // Wait for 5 confirmations
  if (!deploymentReceipt) {
    throw new Error("Deployment transaction failed to confirm");
  }

  const contractAddress: string = await contract.getAddress();
  const totalSupply = await contract.totalSupply();

  console.log("ATXIAGovernanceFinal deployed to:", contractAddress);
  console.log("Initial owner:", initialOwner);
  console.log("Total supply:", ethers.formatEther(totalSupply), "ATX");
  console.log("Transaction hash:", deploymentReceipt.hash);
  console.log("Constructor arguments:", JSON.stringify([initialOwner]));

  // Prepare verification command
  const verifyCommand = `npx hardhat verify --network ${networkName} ${contractAddress} "${initialOwner}"`;
  console.log("Verification command:", verifyCommand);

  // Wait briefly to avoid Etherscan rate limiting
  console.log("Waiting 30 seconds before verification...");
  await new Promise((resolve) => setTimeout(resolve, 30000));

  // Save deployment artifacts
  const deploymentInfo = {
    address: contractAddress,
    owner: initialOwner,
    chainId,
    transactionHash: deploymentReceipt.hash,
    abi: ATXIAFactory.interface.formatJson(),
    deployedAt: new Date().toISOString(),
  };

  await fs.mkdir("deployments", { recursive: true });
  await fs.writeFile(
    `deployments/${networkName}.json`,
    JSON.stringify(deploymentInfo, null, 2)
  );
  console.log(`Deployment info saved to deployments/${networkName}.json`);
}

main().catch((error: unknown) => {
  console.error("Deployment failed with error:", error);
  process.exitCode = 1;
});