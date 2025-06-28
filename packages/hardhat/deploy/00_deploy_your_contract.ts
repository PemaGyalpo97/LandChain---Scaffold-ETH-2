import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const deployLandContracts: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  // Deploy LandRegistry first
  const landRegistry = await deploy("LandRegistry", {
    from: deployer,
    args: [deployer], // deployer is initial owner
    log: true,
    autoMine: true,
  });

  console.log("✅ LandRegistry deployed to:", landRegistry.address);

  // Deploy LandNFT with LandRegistry address
  const landNFT = await deploy("LandNFT", {
    from: deployer,
    args: [landRegistry.address],
    log: true,
    autoMine: true,
  });

  console.log("✅ LandNFT deployed to:", landNFT.address);

  // Optional: Verify contracts (requires ETHERSCAN_API_KEY in .env)
  if (process.env.ETHERSCAN_API_KEY) {
    await hre.run("verify:verify", {
      address: landRegistry.address,
      constructorArguments: [deployer],
    });
    await hre.run("verify:verify", {
      address: landNFT.address,
      constructorArguments: [landRegistry.address],
    });
  }
};

export default deployLandContracts;

deployLandContracts.tags = ["LandContracts"];
deployLandContracts.dependencies = [];
