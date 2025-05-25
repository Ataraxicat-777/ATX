import { ethers, network } from "hardhat";
import fs from "fs";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with:", deployer.address);

  const networkName = network.name;
  console.log("Deploying to network:", networkName);

  const ATXIA = await ethers.getContractFactory("ATXIAGovernance");
  const initialOwner = deployer.address;
  const contract = await ATXIA.deploy(initialOwner, {
    gasLimit: 3000000,
  });

  await contract.waitForDeployment();
  const contractAddress = await contract.getAddress();
  const totalSupply = await contract.totalSupply();

  console.log("ATXIA deployed to:", contractAddress);
  console.log("Initial owner:", initialOwner);
  console.log("Total supply:", ethers.formatEther(totalSupply), "ATX");
  console.log("Constructor arguments:", JSON.stringify([initialOwner]));
  console.log(`npx hardhat verify --network ${networkName} ${contractAddress} "${initialOwner}"`);

  const { chainId } = await deployer.provider.getNetwork();
  fs.mkdirSync("deployments", { recursive: true });
  fs.writeFileSync(
    `deployments/${networkName}.json`,
    JSON.stringify(
      {
        address: contractAddress,
        owner: initialOwner,
        chainId,
      },
      null,
      2
    )
  );
}

main().catch((error) => {
  console.error("Deployment failed:", error);
  process.exit(1);
});