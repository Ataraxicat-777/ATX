const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AtaxiaToken", function () {
  let token, owner, addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("AtaxiaToken");
    token = await Token.deploy();
    await token.waitForDeployment();
  });

  it("should deploy with the correct name and symbol", async function () {
    expect(await token.name()).to.equal("ATXIA");
    expect(await token.symbol()).to.equal("ATX");
  });

  it("should mint initial supply to deployer", async function () {
    const supply = await token.totalSupply();
    expect(await token.balanceOf(owner.address)).to.equal(supply);
  });

  it("should mint claimable tokens", async function () {
    await token.claimInitialTokens(addr1.address);
    expect(await token.balanceOf(addr1.address)).to.equal(ethers.parseUnits("1000", 18));
  });
});
