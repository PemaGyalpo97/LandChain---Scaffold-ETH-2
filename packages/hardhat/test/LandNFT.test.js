const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LandNFT", function () {
  let LandNFT, landNFT, LandRegistry, landRegistry, owner, addr1, addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    // Deploy a mock LandRegistry contract
    const LandRegistry = await ethers.getContractFactory("LandRegistry");
    landRegistry = await LandRegistry.deploy();
    await landRegistry.deployed();

    // Deploy LandNFT contract
    LandNFT = await ethers.getContractFactory("LandNFT");
    landNFT = await LandNFT.deploy(landRegistry.address);
    await landNFT.deployed();

    // Mock LandRegistry functions (simplified for testing)
    await landRegistry.addPlot(
      "THRAM123",
      "PLOT456",
      "Location",
      [addr1.address],
      ["did:eth:1"],
      10,
      50,
      10,
      50,
      true
    );
  });

  it("should mint a Thram token and emit LandTokenized event", async function () {
    const thramNumber = "THRAM123";
    const owners = [addr1.address, addr2.address];
    const userDids = ["did:eth:1", "did:eth:2"];
    const percentages = [50, 50];

    await expect(landNFT.mintThramToken(thramNumber, owners, userDids, percentages))
      .to.emit(landNFT, "LandTokenized")
      .withArgs(1, 0, thramNumber, "", 0, 0, owners, percentages);

    const token = await landNFT.getToken(1);
    expect(token[0]).to.equal(1); // tokenId
    expect(token[1]).to.equal(0); // TokenType.THRAM
    expect(token[2]).to.equal(thramNumber);
    expect(token[6]).to.deep.equal(owners);
    expect(token[7]).to.deep.equal(userDids);
    expect(token[8]).to.deep.equal(percentages);
  });

  it("should mint a Plot token and emit LandTokenized event", async function () {
    const plotNumber = "PLOT456";
    const owners = [addr1.address, addr2.address];
    const userDids = ["did:eth:1", "did:eth:2"];
    const percentages = [50, 50];

    await expect(landNFT.mintPlotToken(plotNumber, owners, userDids, percentages))
      .to.emit(landNFT, "LandTokenized")
      .withArgs(1, 1, "THRAM123", plotNumber, 10, 50, owners, percentages);

    const token = await landNFT.getToken(1);
    expect(token[0]).to.equal(1); // tokenId
    expect(token[1]).to.equal(1); // TokenType.PLOT
    expect(token[3]).to.equal(plotNumber);
    expect(token[6]).to.deep.equal(owners);
    expect(token[7]).to.deep.equal(userDids);
    expect(token[8]).to.deep.equal(percentages);
  });

  it("should revert if burning is attempted", async function () {
    await expect(landNFT._burn(1)).to.be.revertedWith("Burning is disabled for audit trail purposes");
  });

  it("should revert if percentages do not sum to 100", async function () {
    const thramNumber = "THRAM123";
    const owners = [addr1.address];
    const userDids = ["did:eth:1"];
    const percentages = [90];

    await expect(landNFT.mintThramToken(thramNumber, owners, userDids, percentages))
      .to.be.revertedWith("Ownership percentages must sum to 100");
  });

  it("should set token URI", async function () {
    const thramNumber = "THRAM123";
    const owners = [addr1.address];
    const userDids = ["did:eth:1"];
    const percentages = [100];

    await landNFT.mintThramToken(thramNumber, owners, userDids, percentages);
    await landNFT.setTokenURI(1, "ipfs://metadata");
    expect(await landNFT.tokenURI(1)).to.equal("ipfs://metadata");
  });
});