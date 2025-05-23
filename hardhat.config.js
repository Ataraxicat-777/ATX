// scripts/deployATXIA.js
const { ethers, run, network } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contract with:", deployer.address);

  const ATXIA = await ethers.getContractFactory("ATXIA");
  const atxia = await ATXIA.deploy(deployer.address);

  await atxia.deployed();

  console.log(`ATXIA deployed at: ${atxia.address}`);

  // Verify the contract if not on local network
  if (network.name !== "hardhat" && process.env.ETHERSCAN_API_KEY) {
    console.log("Waiting for Etherscan to index contract...");
    await atxia.deployTransaction.wait(6); // wait 6 blocks for Etherscan

    try {
      await run("verify:verify", {
        address: atxia.address,
        constructorArguments: [deployer.address],
      });
      console.log("Contract verified!");
    } catch (err) {
      console.error("Verification error:", err);
    }
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});