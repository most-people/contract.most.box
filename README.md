# AppVersionContract

一个简单的以太坊智能合约，用于管理应用版本号和下载链接。

## 功能

- 存储应用版本号
- 存储应用下载链接
- 权限控制

## 安装

```bash
npm install
```

## 配置

创建`.env`文件，添加：

```
PRIVATE_KEY=你的钱包私钥
```

## 测试

```bash
npm run test
```

## 部署

```bash
npm run deploy
```

## 调用示例

```javascript
// 使用ethers.js调用合约
const { ethers } = require("ethers");
const abi =
  require("./artifacts\\contracts\\AppVersionContract.sol\\AppVersionContract.json").abi;

// 连接合约
const provider = new ethers.providers.JsonRpcProvider("YOUR_RPC_URL");
const signer = new ethers.Wallet("YOUR_PRIVATE_KEY", provider);
const contract = new ethers.Contract("CONTRACT_ADDRESS", abi, signer);

// 获取版本
async function getVersion() {
  const version = await contract.getCurrentVersion();
  console.log("版本号:", version);
}

// 获取下载链接
async function getLink() {
  const link = await contract.getDownloadLink();
  console.log("下载链接:", link);
}

// 一次性获取版本号和下载链接
async function getAppInfo() {
  const [version, link] = await contract.getAppInfo();
  console.log("版本号:", version);
  console.log("下载链接:", link);
}

// 更新版本号 (仅合约拥有者)
async function updateVersion() {
  await contract.updateVersion("1.2.0");
}

// 更新下载链接 (仅合约拥有者)
async function updateLink() {
  await contract.updateDownloadLink("https://example.com/app/download");
}
```

## 许可证

MIT
