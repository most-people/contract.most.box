import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("AppVersionContract", function () {
  let appVersionContract: any;
  let owner: SignerWithAddress;
  let manager: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;

  beforeEach(async function () {
    [owner, manager, addr1, addr2] = await ethers.getSigners();

    const AppVersionContract = await ethers.getContractFactory(
      "AppVersionContract"
    );
    appVersionContract = await AppVersionContract.deploy();
  });

  it("初始应用信息应为空字符串", async function () {
    const [version, downloadLink, updateContent] =
      await appVersionContract.getAppInfo();
    expect(version).to.equal("");
    expect(downloadLink).to.equal("");
    expect(updateContent).to.equal("");
  });

  it("应该可以更新和获取应用信息", async function () {
    const versionNumber = "1.0.0";
    const downloadLink = "https://example.com/app/download";
    const updateContent = "修复了一些bug，优化了性能";

    await appVersionContract.updateAppInfo(
      versionNumber,
      downloadLink,
      updateContent
    );

    const [version, link, content] = await appVersionContract.getAppInfo();
    expect(version).to.equal(versionNumber);
    expect(link).to.equal(downloadLink);
    expect(content).to.equal(updateContent);
  });

  it("非拥有者不能更新应用信息", async function () {
    await expect(
      appVersionContract
        .connect(addr1)
        .updateAppInfo("1.0.0", "https://example.com", "更新内容")
    ).to.be.revertedWith("Only owner can call this function");
  });

  it("可以添加和移除节点管理员", async function () {
    // 初始状态下，合约拥有者是管理员
    expect(await appVersionContract.isNodeManager(owner.address)).to.equal(
      true
    );
    expect(await appVersionContract.isNodeManager(manager.address)).to.equal(
      false
    );

    // 添加管理员
    await appVersionContract.addNodeManager(manager.address);
    expect(await appVersionContract.isNodeManager(manager.address)).to.equal(
      true
    );

    // 移除管理员
    await appVersionContract.removeNodeManager(manager.address);
    expect(await appVersionContract.isNodeManager(manager.address)).to.equal(
      false
    );
  });

  it("非拥有者不能添加或移除管理员", async function () {
    await expect(
      appVersionContract.connect(addr1).addNodeManager(addr2.address)
    ).to.be.revertedWith("Only owner can call this function");

    await appVersionContract.addNodeManager(manager.address);

    await expect(
      appVersionContract.connect(addr1).removeNodeManager(manager.address)
    ).to.be.revertedWith("Only owner can call this function");
  });

  it("不能移除合约拥有者的管理员权限", async function () {
    await expect(
      appVersionContract.removeNodeManager(owner.address)
    ).to.be.revertedWith("Cannot remove owner from node managers");
  });

  it("管理员添加的节点自动批准", async function () {
    // 拥有者添加节点
    await appVersionContract.addNodeUrl("https://node1.example.com");

    // 检查节点状态
    const isApproved1 = await appVersionContract.getNodeInfo(
      "https://node1.example.com"
    );
    expect(isApproved1).to.equal(true);

    // 添加管理员并让管理员添加节点
    await appVersionContract.addNodeManager(manager.address);
    await appVersionContract
      .connect(manager)
      .addNodeUrl("https://node2.example.com");

    // 检查管理员添加的节点状态
    const isApproved2 = await appVersionContract.getNodeInfo(
      "https://node2.example.com"
    );
    expect(isApproved2).to.equal(true);

    // 检查已批准节点列表
    const approvedNodes = await appVersionContract.getApprovedNodeUrls();
    expect(approvedNodes.length).to.equal(2);
    expect(approvedNodes).to.include("https://node1.example.com");
    expect(approvedNodes).to.include("https://node2.example.com");
  });

  it("非管理员添加的节点进入待审核状态", async function () {
    // 普通用户添加节点
    await appVersionContract
      .connect(addr1)
      .addNodeUrl("https://node3.example.com");

    // 检查节点状态
    const isApproved = await appVersionContract.getNodeInfo(
      "https://node3.example.com"
    );
    expect(isApproved).to.equal(false);

    // 检查待审核节点列表
    const pendingNodes = await appVersionContract.getPendingNodeUrls();
    expect(pendingNodes.length).to.equal(1);
    expect(pendingNodes[0]).to.equal("https://node3.example.com");
  });

  it("管理员可以批准待审核节点", async function () {
    // 普通用户添加节点
    await appVersionContract
      .connect(addr1)
      .addNodeUrl("https://node.example.com");

    // 管理员批准节点
    await appVersionContract.approveNode("https://node.example.com");

    // 检查节点状态
    const isApproved = await appVersionContract.getNodeInfo(
      "https://node.example.com"
    );
    expect(isApproved).to.equal(true);

    // 检查节点列表
    const approvedNodes = await appVersionContract.getApprovedNodeUrls();
    expect(approvedNodes).to.include("https://node.example.com");

    const pendingNodes = await appVersionContract.getPendingNodeUrls();
    expect(pendingNodes).to.not.include("https://node.example.com");
  });

  it("非管理员不能批准节点", async function () {
    // 普通用户添加节点
    await appVersionContract
      .connect(addr1)
      .addNodeUrl("https://node.example.com");

    // 普通用户尝试批准节点
    await expect(
      appVersionContract.connect(addr1).approveNode("https://node.example.com")
    ).to.be.revertedWith("Only node manager can call this function");
  });

  it("管理员可以批量批准节点", async function () {
    // 普通用户添加多个节点
    await appVersionContract
      .connect(addr1)
      .addNodeUrl("https://node1.example.com");
    await appVersionContract
      .connect(addr1)
      .addNodeUrl("https://node2.example.com");
    await appVersionContract
      .connect(addr1)
      .addNodeUrl("https://node3.example.com");

    // 批量批准节点
    await appVersionContract.approveNodes([
      "https://node1.example.com",
      "https://node2.example.com",
      "https://node3.example.com",
    ]);

    // 检查所有节点状态
    const isApproved1 = await appVersionContract.getNodeInfo(
      "https://node1.example.com"
    );
    const isApproved2 = await appVersionContract.getNodeInfo(
      "https://node2.example.com"
    );
    const isApproved3 = await appVersionContract.getNodeInfo(
      "https://node3.example.com"
    );

    expect(isApproved1).to.equal(true);
    expect(isApproved2).to.equal(true);
    expect(isApproved3).to.equal(true);

    // 检查节点列表
    const approvedNodes = await appVersionContract.getApprovedNodeUrls();
    expect(approvedNodes.length).to.equal(3);
    expect(approvedNodes).to.include("https://node1.example.com");
    expect(approvedNodes).to.include("https://node2.example.com");
    expect(approvedNodes).to.include("https://node3.example.com");

    const pendingNodes = await appVersionContract.getPendingNodeUrls();
    expect(pendingNodes.length).to.equal(0);
  });

  it("不允许添加重复的节点网址", async function () {
    await appVersionContract.addNodeUrl("https://node.example.com");

    // 尝试添加相同的节点网址
    await expect(
      appVersionContract.addNodeUrl("https://node.example.com")
    ).to.be.revertedWith("Node URL already exists");
  });

  it("不允许添加空的节点网址", async function () {
    await expect(appVersionContract.addNodeUrl("")).to.be.revertedWith(
      "Node URL cannot be empty"
    );
  });

  it("管理员可以删除节点", async function () {
    // 添加节点
    await appVersionContract.addNodeUrl("https://node1.example.com");
    await appVersionContract
      .connect(addr1)
      .addNodeUrl("https://node2.example.com");

    // 删除已批准节点
    await appVersionContract.removeNodeUrl("https://node1.example.com");

    // 删除待审核节点
    await appVersionContract.removeNodeUrl("https://node2.example.com");

    // 检查节点是否被删除
    await expect(
      appVersionContract.getNodeInfo("https://node1.example.com")
    ).to.be.revertedWith("Node URL does not exist");

    await expect(
      appVersionContract.getNodeInfo("https://node2.example.com")
    ).to.be.revertedWith("Node URL does not exist");

    // 检查节点列表
    const approvedNodes = await appVersionContract.getApprovedNodeUrls();
    expect(approvedNodes.length).to.equal(0);

    const pendingNodes = await appVersionContract.getPendingNodeUrls();
    expect(pendingNodes.length).to.equal(0);
  });

  it("非管理员不能删除节点", async function () {
    // 添加节点
    await appVersionContract.addNodeUrl("https://node.example.com");

    // 普通用户尝试删除节点
    await expect(
      appVersionContract
        .connect(addr1)
        .removeNodeUrl("https://node.example.com")
    ).to.be.revertedWith("Only node manager can call this function");
  });

  it("管理员可以批量删除节点", async function () {
    // 添加多个节点
    await appVersionContract.addNodeUrl("https://node1.example.com");
    await appVersionContract.addNodeUrl("https://node2.example.com");
    await appVersionContract
      .connect(addr1)
      .addNodeUrl("https://node3.example.com");

    // 批量删除节点
    await appVersionContract.removeNodeUrls([
      "https://node1.example.com",
      "https://node2.example.com",
      "https://node3.example.com",
    ]);

    // 检查节点列表
    const approvedNodes = await appVersionContract.getApprovedNodeUrls();
    expect(approvedNodes.length).to.equal(0);

    const pendingNodes = await appVersionContract.getPendingNodeUrls();
    expect(pendingNodes.length).to.equal(0);
  });

  it("可以获取节点信息", async function () {
    // 添加节点
    await appVersionContract.addNodeUrl("https://node.example.com");

    // 获取节点信息
    const isApproved = await appVersionContract.getNodeInfo(
      "https://node.example.com"
    );

    expect(isApproved).to.equal(true);
  });

  it("可以获取节点数量", async function () {
    expect(await appVersionContract.getApprovedNodeCount()).to.equal(0);
    expect(await appVersionContract.getPendingNodeCount()).to.equal(0);

    // 添加节点
    await appVersionContract.addNodeUrl("https://node1.example.com");
    await appVersionContract
      .connect(addr1)
      .addNodeUrl("https://node2.example.com");

    expect(await appVersionContract.getApprovedNodeCount()).to.equal(1);
    expect(await appVersionContract.getPendingNodeCount()).to.equal(1);
  });

  it("拥有者可以转让所有权", async function () {
    // 转让所有权
    await appVersionContract.transferOwnership(addr1.address);
    expect(await appVersionContract.getOwner()).to.equal(addr1.address);

    // 原拥有者不能再更新应用信息
    await expect(
      appVersionContract.updateAppInfo(
        "1.0.0",
        "https://example.com",
        "更新内容"
      )
    ).to.be.revertedWith("Only owner can call this function");

    // 新拥有者可以更新应用信息
    await appVersionContract
      .connect(addr1)
      .updateAppInfo("1.0.0", "https://example.com", "更新内容");

    const [version, link, content] = await appVersionContract.getAppInfo();
    expect(version).to.equal("1.0.0");
    expect(link).to.equal("https://example.com");
    expect(content).to.equal("更新内容");
  });

  it("不能将所有权转让给零地址", async function () {
    await expect(
      appVersionContract.transferOwnership(
        "0x0000000000000000000000000000000000000000"
      )
    ).to.be.revertedWith("New owner cannot be zero address");
  });
});
