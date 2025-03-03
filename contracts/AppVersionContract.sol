// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract AppVersionContract {
    // 存储APP当前版本号
    string private currentVersion;

    // 存储APP下载链接
    string private downloadLink;

    // 合约拥有者地址
    address private owner;

    // 事件：更新版本时触发
    event VersionUpdated(string versionNumber);

    // 事件：更新下载链接时触发
    event DownloadLinkUpdated(string newLink);

    // 构造函数：设置合约拥有者
    constructor() {
        owner = msg.sender;
    }

    // 修饰符：只有合约拥有者才能调用
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    // 更新版本号
    function updateVersion(string calldata versionNumber) external onlyOwner {
        currentVersion = versionNumber;
        emit VersionUpdated(versionNumber);
    }

    // 获取当前版本号
    function getCurrentVersion() external view returns (string memory) {
        return currentVersion;
    }

    // 更新下载链接
    function updateDownloadLink(string calldata newLink) external onlyOwner {
        downloadLink = newLink;
        emit DownloadLinkUpdated(newLink);
    }

    // 获取当前下载链接
    function getDownloadLink() external view returns (string memory) {
        return downloadLink;
    }

    // 转让合约所有权
    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    // 获取合约拥有者
    function getOwner() external view returns (address) {
        return owner;
    }
}
