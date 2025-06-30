import { expect } from "chai";
import { ethers } from "hardhat";

describe("VerifierSetup", function () {
  let verifierSetup: any;
  let verifiers: any;
  let addr1: any, addr2: any, addr3: any;

  beforeEach(async function () {
    // Removed owner from destructuring since it's not used in tests
    [, addr1, addr2, addr3] = await ethers.getSigners();

    const Verifiers = await ethers.getContractFactory("VerifiersAndApprovers");
    verifiers = await Verifiers.deploy();

    const Setup = await ethers.getContractFactory("VerifierSetup");
    verifierSetup = await Setup.deploy(verifiers.address);
  });

  it("Should add verifiers in batch", async function () {
    const addresses = [addr1.address, addr2.address, addr3.address];
    const types = [0, 1, 2]; // BANK, COURT, TAX

    await verifierSetup.batchAddVerifiers(addresses, types);

    // Added void operator to explicitly indicate we're intentionally using expressions
    void expect(await verifiers.bankVerifiers(addr1.address)).to.be.true;
    void expect(await verifiers.courtVerifiers(addr2.address)).to.be.true;
    void expect(await verifiers.taxVerifiers(addr3.address)).to.be.true;
  });

  it("Should prevent non-owner from adding verifiers", async function () {
    await expect(verifierSetup.connect(addr1).batchAddVerifiers([addr1.address], [0])).to.be.revertedWith(
      "Only owner can perform this action",
    );
  });
});
