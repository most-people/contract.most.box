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

  it("初始版本号和下载链接应为空字符串", async function () {
    expect(await appVersionContract.getCurrentVersion()).to.equal("");
    expect(await appVersionContract.getDownloadLink()).to.equal("");
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

  it("应该可以更新和获取下载链接", async function () {
    const downloadLink = "https://example.com/app/download";

    await appVersionContract.updateDownloadLink(downloadLink);
    expect(await appVersionContract.getDownloadLink()).to.equal(downloadLink);

    // 再次更新下载链接
    const newDownloadLink = "https://example.com/app/download/v2";
    await appVersionContract.updateDownloadLink(newDownloadLink);
    expect(await appVersionContract.getDownloadLink()).to.equal(
      newDownloadLink
    );
  });

  it("应该可以一次性获取版本号和下载链接", async function () {
    const versionNumber = "1.5.0";
    const downloadLink = "https://example.com/app/v1.5.0";

    await appVersionContract.updateVersion(versionNumber);
    await appVersionContract.updateDownloadLink(downloadLink);

    const appInfo = await appVersionContract.getAppInfo();
    expect(appInfo[0]).to.equal(versionNumber);
    expect(appInfo[1]).to.equal(downloadLink);

    // 也可以使用解构赋值测试
    const [version, link] = await appVersionContract.getAppInfo();
    expect(version).to.equal(versionNumber);
    expect(link).to.equal(downloadLink);
  });

  it("非拥有者不能更新版本号和下载链接", async function () {
    await expect(
      appVersionContract.connect(addr1).updateVersion("1.0.0")
    ).to.be.revertedWith("Only owner can call this function");

    await expect(
      appVersionContract
        .connect(addr1)
        .updateDownloadLink("https://example.com/app/download")
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
