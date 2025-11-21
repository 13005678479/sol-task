# 部署说明

## 本地部署

### 1. 启动本地Hardhat节点
```bash
npm run node
```

### 2. 在新的终端窗口中部署合约
```bash
npm run deploy
```

## Sepolia测试网部署

### 1. 配置环境变量
编辑 `constant.env` 文件，填入以下信息：
- `PRIVATE_KEY`: 你的Sepolia测试网私钥
- `ETHERSCAN_API_KEY`: Etherscan API密钥（用于合约验证）

### 2. 部署到Sepolia测试网
```bash
npm run deploy:sepolia
```

## 配置说明

### 网络配置
- **localhost**: 本地开发网络 (chainId: 31337)
- **sepolia**: Sepolia测试网络 (chainId: 11155111)

### 依赖包
- `hardhat-deploy`: 高级部署插件
- `dotenv`: 环境变量管理
- `@openzeppelin/contracts`: 安全合约库

### 已更新的配置
1. Solidity版本升级到 0.8.20
2. 添加了测试网网络配置
3. 更新了OpenZeppelin 5.x兼容性
4. 配置了环境变量管理
5. 添加了Gas报告和合约验证支持

## 验证部署

### 检查合约地址
部署完成后会显示：
- TokenA地址
- TokenB地址  
- 流动性池地址
- 部署账户地址

### 验证合约
在Etherscan上验证合约：
```bash
npx hardhat verify --network sepolia <CONTRACT_ADDRESS> <CONSTRUCTOR_ARGS>
```

## 注意事项
- 确保Sepolia测试网账户有足够的ETH
- 私钥请勿在生产环境中使用测试私钥
- 部署前请检查环境变量配置