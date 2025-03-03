import { ethers } from "hardhat";

async function main() {
  // 获取合约工厂
  const AppVersionContract = await ethers.getContractFactory(
    "AppVersionContract"
  );

  // 部署合约并等待部署完成
  const appVersionContract = await AppVersionContract.deploy();

  // 获取合约地址
  // @ts-ignore
  const address = await appVersionContract.getAddress();

  // 输出合约地址
  console.log("AppVersionContract deployed to:", address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
