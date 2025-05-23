// scripts/deploy.js
const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with:", deployer.address);

  // Get contract factory and deploy contract
  const ATXIA = await hre.ethers.getContractFactory("ATXIA");
  const contract = await ATXIA.deploy(deployer.address); // passing the deployer's address as the initial owner

  await contract.deployed();

  console.log("ATXIA deployed to:", contract.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});