import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const PrivateKey = "";

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {},
    XLayer: {
      // RPC
      url: "https://testrpc.xlayer.tech",
      // Metis Sepolia
      // url: "https://sepolia.metisdevops.link",
      accounts: [PrivateKey],
    },
  },
};

export default config;
