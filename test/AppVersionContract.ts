import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("AppVersionContract", function () {
  let appVersionContract: any;
  let owner: SignerWithAddress;
  let addr1: SignerWithAddress;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();

    const AppVersionContract = await ethers.getContractFactory(
      "AppVersionContract"
    );
    appVersionContract = await AppVersionContract.deploy();
  });

  it("初始版本号应为空字符串", async function () {
    expect(await appVersionContract.getCurrentVersion()).to.equal("");
  });

  it("应该可以更新和获取版本号", async function () {
    const versionNumber = "1.0.0";

    await appVersionContract.updateVersion(versionNumber);
    expect(await appVersionContract.getCurrentVersion()).to.equal(
      versionNumber
    );

    // 再次更新版本号
    const newVersionNumber = "1.1.0";
    await appVersionContract.updateVersion(newVersionNumber);
    expect(await appVersionContract.getCurrentVersion()).to.equal(
      newVersionNumber
    );
  });

  it("非拥有者不能更新版本号", async function () {
    await expect(
      appVersionContract.connect(addr1).updateVersion("1.0.0")
    ).to.be.revertedWith("Only owner can call this function");
  });

  it("拥有者可以转让所有权，包括转让给零地址", async function () {
    // 转让给普通地址
    await appVersionContract.transferOwnership(addr1.address);
    expect(await appVersionContract.getOwner()).to.equal(addr1.address);

    // 原拥有者不能再更新版本号
    await expect(appVersionContract.updateVersion("1.0.0")).to.be.revertedWith(
      "Only owner can call this function"
    );

    // 新拥有者可以更新版本号
    await appVersionContract.connect(addr1).updateVersion("1.0.0");
    expect(await appVersionContract.getCurrentVersion()).to.equal("1.0.0");

    // 转让给零地址
    const zeroAddress = "0x0000000000000000000000000000000000000000";
    await appVersionContract.connect(addr1).transferOwnership(zeroAddress);
    expect(await appVersionContract.getOwner()).to.equal(zeroAddress);
  });
});
