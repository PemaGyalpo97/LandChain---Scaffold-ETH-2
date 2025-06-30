import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const deployLandContracts: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy, get, log, execute } = hre.deployments;

  const network = hre.network.name;
  log(`Deploying contracts on network: ${network}`);

  const gasSettings = {
    gasLimit: 8000000,
    ...(network === "mainnet" && {
      maxPriorityFeePerGas: hre.ethers.utils.parseUnits("2", "gwei"),
      maxFeePerGas: hre.ethers.utils.parseUnits("50", "gwei"),
    }),
  };

  // 1. First deploy LandRegistry (needed for LandNFT)
  let landRegistry;
  try {
    landRegistry = await get("LandRegistry");
    log(`✅ LandRegistry already deployed at: ${landRegistry.address}`);
  } catch (error) {
    log(`LandRegistry not found, deploying new instance: ${error instanceof Error ? error.message : String(error)}`);
    try {
      landRegistry = await deploy("LandRegistry", {
        from: deployer,
        args: [deployer],
        log: true,
        autoMine: ["hardhat", "localhost"].includes(network),
        ...gasSettings,
      });
      log(`✅ LandRegistry deployed to: ${landRegistry.address}`);
    } catch (deployError) {
      log(
        `❌ Failed to deploy LandRegistry: ${deployError instanceof Error ? deployError.message : String(deployError)}`,
      );
      throw deployError;
    }
  }

  // 2. Deploy VerifiersAndApprovers (needs no dependencies)
  let verifiers;
  try {
    verifiers = await deploy("VerifiersAndApprovers", {
      from: deployer,
      log: true,
      autoMine: true,
      ...gasSettings,
    });
    log(`✅ VerifiersAndApprovers deployed to: ${verifiers.address}`);

    // Verify ownership was set correctly
    const verifiersContract = await hre.ethers.getContractAt("VerifiersAndApprovers", verifiers.address);
    const verifiersOwner = await verifiersContract.owner();
    if (verifiersOwner.toLowerCase() !== deployer.toLowerCase()) {
      log(`⚠️ Ownership issue: VerifiersAndApprovers owner is ${verifiersOwner}, expected ${deployer}`);
    }
  } catch (error) {
    log(`❌ Failed to deploy VerifiersAndApprovers: ${error instanceof Error ? error.message : String(error)}`);
    throw error;
  }

  // 3. Deploy VerifierSetup (depends on VerifiersAndApprovers)
  let verifierSetup;
  try {
    verifierSetup = await deploy("VerifierSetup", {
      from: deployer,
      args: [verifiers.address],
      log: true,
      autoMine: true,
      ...gasSettings,
    });
    log(`✅ VerifierSetup deployed to: ${verifierSetup.address}`);

    // Transfer ownership of VerifiersAndApprovers to VerifierSetup
    if (["hardhat", "localhost"].includes(network)) {
      const setup = await hre.ethers.getContractAt("VerifierSetup", verifierSetup.address);
      const currentOwner = await setup.owner();
      log(`ℹ️ Current owner: ${currentOwner}`);
      log(`ℹ️ Deployer address: ${deployer}`);

      if (currentOwner.toLowerCase() === deployer.toLowerCase()) {
        // First transfer VerifiersAndApprovers ownership to VerifierSetup
        await execute(
          "VerifiersAndApprovers",
          { from: deployer, log: true },
          "transferOwnership",
          verifierSetup.address,
        );
        log(`✅ Transferred VerifiersAndApprovers ownership to VerifierSetup`);

        // Now add verifiers through VerifierSetup
        const verifierAddresses = [
          deployer, // Using deployer as bank verifier
          "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc", // court
          "0x14dC79964da2C08b23698B3D3cc7Ca32193d9955", // tax
        ];
        const verifierTypes = [0, 1, 2]; // BANK=0, COURT=1, TAX=2

        const tx = await setup.batchAddVerifiers(verifierAddresses, verifierTypes);
        await tx.wait();
        log(`✅ Batch added ${verifierAddresses.length} verifiers`);
      } else {
        log(`⚠️ Cannot add verifiers: Deployer is not the owner`);
      }
    }
  } catch (error) {
    log(`❌ Failed to deploy VerifierSetup: ${error instanceof Error ? error.message : String(error)}`);
    throw error;
  }

  // 4. Deploy LandNFT (depends on LandRegistry)
  let landNFT;
  try {
    landNFT = await deploy("LandNFT", {
      from: deployer,
      args: [landRegistry.address],
      log: true,
      autoMine: ["hardhat", "localhost"].includes(network),
      ...gasSettings,
    });
    log(`✅ LandNFT deployed to: ${landNFT.address}`);
  } catch (deployError) {
    log(`❌ Failed to deploy LandNFT: ${deployError instanceof Error ? deployError.message : String(deployError)}`);
    throw deployError;
  }

  // 5. Finally deploy EscrowVerification (depends on both LandNFT and Verifiers)
  let escrow;
  try {
    escrow = await deploy("EscrowVerification", {
      from: deployer,
      args: [landNFT.address, verifiers.address],
      log: true,
      autoMine: true,
      ...gasSettings,
    });
    log(`✅ EscrowVerification deployed to: ${escrow.address}`);
  } catch (error) {
    log(`❌ Failed to deploy EscrowVerification: ${error instanceof Error ? error.message : String(error)}`);
    throw error;
  }

  // Verification (if not local network)
  if (!["hardhat", "localhost"].includes(network) && process.env.ETHERSCAN_API_KEY) {
    log("Verifying contracts...");
    try {
      // Verify in reverse dependency order
      await hre.run("verify:verify", {
        address: escrow.address,
        constructorArguments: [landNFT.address, verifiers.address],
      });
      await hre.run("verify:verify", {
        address: landNFT.address,
        constructorArguments: [landRegistry.address],
      });
      await hre.run("verify:verify", {
        address: verifierSetup.address,
        constructorArguments: [verifiers.address],
      });
      await hre.run("verify:verify", {
        address: verifiers.address,
        constructorArguments: [],
      });
      await hre.run("verify:verify", {
        address: landRegistry.address,
        constructorArguments: [deployer],
      });
      log("✅ All contracts verified");
    } catch (verifyError) {
      log(`⚠️ Verification failed: ${verifyError instanceof Error ? verifyError.message : String(verifyError)}`);
    }
  }
};

deployLandContracts.tags = ["LandContracts"];
export default deployLandContracts;
