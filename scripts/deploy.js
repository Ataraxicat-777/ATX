const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Replace with the actual ATX token address on Sepolia
  const atxTokenAddress = "0xYourATXTokenAddressHere"; // Update this

  // Deploy ATXIAGameEngine
  const ATXIAGameEngine = await ethers.getContractFactory("ATXIAGameEngine");
  const gameEngine = await ATXIAGameEngine.deploy(atxTokenAddress);
  await gameEngine.deploymentTransaction().wait();
  console.log("ATXIAGameEngine deployed to:", gameEngine.target);

  // Verify on Etherscan
  if (hre.network.name === "sepolia") {
    console.log("Verifying contract on Etherscan...");
    await hre.run("verify:verify", {
      address: gameEngine.target,
      constructorArguments: [atxTokenAddress],
    });
  }

  // Fund the game engine with ATX tokens (assuming deployer owns tokens)
  const atxToken = await ethers.getContractAt("IERC20", atxTokenAddress);
  const amountToFund = ethers.parseEther("10000"); // Fund with 10,000 ATX
  await atxToken.transfer(gameEngine.target, amountToFund);
  console.log(`Funded game engine with ${ethers.formatEther(amountToFund)} ATX`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });