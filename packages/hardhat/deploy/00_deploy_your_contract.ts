import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "ethers";

const deployLandContracts: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy, get, log } = hre.deployments;

  const network = hre.network.name;
  log(`Deploying contracts on network: ${network}`);

  const gasSettings = {
    gasLimit: 8000000,
    ...(network === "mainnet" && {
      maxPriorityFeePerGas: ethers.utils.parseUnits("2", "gwei"),
      maxFeePerGas: ethers.utils.parseUnits("50", "gwei"),
    }),
  };

  // Deploy LandRegistry if not already deployed
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

  // Deploy LandNFT with LandRegistry address if not already deployed
  let landNFT;
  try {
    landNFT = await get("LandNFT");
    log(`✅ LandNFT already deployed at: ${landNFT.address}`);
  } catch (error) {
    log(`LandNFT not found, deploying new instance: ${error instanceof Error ? error.message : String(error)}`);
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
  }

  // Verify contracts on Etherscan
  if (process.env.ETHERSCAN_API_KEY && !["hardhat", "localhost"].includes(network)) {
    log("Verifying contracts on Etherscan...");

    const verifyWithRetry = async (address: string, constructorArguments: any[], retries = 3, delay = 5000) => {
      for (let attempt = 1; attempt <= retries; attempt++) {
        try {
          await hre.run("verify:verify", { address, constructorArguments });
          log(`✅ Verified contract at: ${address}`);
          return;
        } catch (error) {
          log(`Attempt ${attempt}/${retries} failed: ${error instanceof Error ? error.message : String(error)}`);
          if (attempt < retries) {
            await new Promise(resolve => setTimeout(resolve, delay));
          }
        }
      }
      log(`⚠️ Failed to verify contract at: ${address}`);
    };

    try {
      await verifyWithRetry(landRegistry.address, [deployer]);
      await verifyWithRetry(landNFT.address, [landRegistry.address]);
    } catch (error) {
      log(`⚠️ Verification process error: ${error instanceof Error ? error.message : String(error)}`);
    }
  } else {
    log("Skipping Etherscan verification");
  }
};

deployLandContracts.tags = ["LandContracts"];
deployLandContracts.dependencies = [];

export default deployLandContracts;
