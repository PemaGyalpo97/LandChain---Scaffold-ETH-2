import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const deployLandRegistry: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  await deploy("LandRegistry", {
    from: deployer,
    args: [deployer],
    log: true,
    autoMine: true,
  });
};

export default deployLandRegistry;

deployLandRegistry.tags = ["LandRegistry"];
