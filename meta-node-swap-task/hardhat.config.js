require("@nomicfoundation/hardhat-toolbox");
require("hardhat-deploy");
require("dotenv").config({ path: "constant.env" });

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },

  // 网络配置
  networks: {
    // 本地区块链网络配置
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
      // 使用Hardhat默认账户
    },
    
    // Sepolia测试网络配置
    sepolia: {
      // RPC端点URL - 使用Infura提供的Sepolia节点服务
      url: "https://sepolia.infura.io/v3/ea33fc8cbc4545d9ac08fba394c5046b",
      // 部署账户私钥列表 - 用于签署交易
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 11155111,
    }
  },
  
  // 部署配置
  namedAccounts: {
    deployer: {
      default: 0, // 默认使用第一个账户作为部署者
    },
    owner: {
      default: 1, // 使用第二个账户作为合约所有者
    },
  },

  // Gas报告配置
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },

  // Etherscan验证配置
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },

  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  }
};