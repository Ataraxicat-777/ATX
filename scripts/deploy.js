import { ethers,run,network } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  const atxTokenAddress = "0xYourATXTokenAddressHere"; // Replace with actual token address

  const ATXIAGameEngine = await ethers.getContractFactory("ATXIAGameEngine");
  const gameEngine = await ATXIAGameEngine.deploy(atxTokenAddress);
  await gameEngine.deployTransaction.wait();

  console.log("ATXIAGameEngine deployed to:", gameEngine.address);

  // Optional Etherscan verification
  if (network.name === "sepolia") {
    console.log("Verifying contract...");
    await run("verify:verify", {
      address: gameEngine.address,
      constructorArguments: [atxTokenAddress],
    });
  }

  // Optional funding logic
  const atxToken = await ethers.getContractAt("IERC20", atxTokenAddress);
  const amountToFund = ethers.parseEther("10000");
  await atxToken.transfer(gameEngine.address, amountToFund);

  console.log(`Funded game engine with ${ethers.formatEther(amountToFund)} ATX`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});