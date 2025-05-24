import { ethers,network } from "hardhat";

async function main() {
  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with:", deployer.address);

  // Log the network being deployed to
  const networkName = network.name;
  console.log("Deploying to network:", networkName);

  // Get the contract factory
  const ATXIA = await ethers.getContractFactory("ATXIA");

  // Deploy the contract with the deployer's address as the initial owner
  const initialOwner = deployer.address;
  const contract = await ATXIA.deploy(initialOwner, {
    gasLimit: 3000000, // Adjust based on network conditions
  });

  // Wait for deployment to complete
  await contract.waitForDeployment();

  // Get the deployed contract address
  const contractAddress = await contract.getAddress();
  console.log("ATXIA deployed to:", contractAddress);
  console.log("Initial owner:", initialOwner);

  // Log total supply for verification
  const totalSupply = await contract.totalSupply();
  console.log("Total supply:", ethers.formatEther(totalSupply), "ATX");

  // Log constructor arguments for Etherscan verification
  console.log("Constructor arguments for verification:", initialOwner);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });