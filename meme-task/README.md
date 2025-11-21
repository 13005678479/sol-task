# MemeToken项目操作指南

## 项目概述

本项目是一个基于SHIB风格的Meme代币智能合约系统，实现了以下核心功能：

- **代币税机制**: 支持买入和卖出时的税收，税收可分配给营销、流动性和开发钱包
- **交易限制**: 包括单笔交易限额、钱包余额限制、每日卖出量和买入次数限制
- **流动性池集成**: 与Uniswap V2集成，支持自动添加流动性
- **紧急控制**: 支持紧急停止交易和流动性提取

## 项目结构

```
meme-task/
├── contracts/              # 智能合约源码
│   ├── MemeToken.sol       # 主要的Meme代币合约
│   └── LiquidityManager.sol # 流动性管理合约
├── scripts/               # 部署脚本
│   ├── deploy-all.js       # 完整部署脚本
│   ├── deploy-meme-token.js # MemeToken部署脚本
│   └── deploy-liquidity-manager.js # LiquidityManager部署脚本
├── test/                  # 测试用例
│   ├── MemeToken.test.js   # MemeToken测试
│   ├── LiquidityManager.test.js # LiquidityManager测试
│   └── Integration.test.js # 集成测试
├── hardhat.config.js      # Hardhat配置文件
├── package.json           # 项目依赖配置
├── constant.env           # 环境变量模板
└── README.md             # 本文档
```

## 环境要求

- Node.js >= 16.0.0
- npm 或 yarn
- Git

## 快速开始

### 1. 安装依赖

```bash
npm install
```

### 2. 配置环境变量

复制环境变量模板并填入实际值：

```bash
cp constant.env.example constant.env
```

编辑 `constant.env` 文件：

```env
# 私钥配置（测试网私钥）
PRIVATE_KEY=your_private_key_here

# Infura项目ID
INFURA_PROJECT_ID=your_infura_project_id_here

# Etherscan API密钥
ETHERSCAN_API_KEY=your_etherscan_api_key_here

# Gas报告开关
REPORT_GAS=false
```

### 3. 编译合约

```bash
npm run compile
```

### 4. 运行测试

```bash
npm run test
```

### 5. 启动本地节点（用于本地测试）

```bash
npm run node
```

在新的终端窗口中部署合约：

```bash
npm run deploy
```

## 部署指南

### 本地部署

1. 启动本地节点：
```bash
npm run node
```

2. 部署合约：
```bash
npm run deploy
```

### Sepolia测试网部署

1. 确保已配置环境变量中的私钥和API密钥

2. 部署到Sepolia测试网：
```bash
npm run deploy:sepolia
```

### 单独部署合约

#### 部署MemeToken合约

```bash
npx hardhat run scripts/deploy-meme-token.js --network sepolia
```

#### 部署LiquidityManager合约

```bash
# 先部署MemeToken获取地址
npx hardhat run scripts/deploy-liquidity-manager.js --network sepolia <meme_token_address>
```

## 合约功能详解

### MemeToken合约

#### 核心功能

1. **代币基本信息**
   - 名称: MemeShiba
   - 符号: MEMESHI
   - 总供应量: 10亿代币

2. **税收机制**
   - 买入税率: 默认2%
   - 卖出税率: 默认2%
   - 税收分配: 营销40%, 流动性30%, 开发30%

3. **交易限制**
   - 单笔交易最大量: 总供应量的1%
   - 钱包最大持有量: 总供应量的2%
   - 每日最大卖出量: 总供应量的1%
   - 每日最大买入次数: 10次

#### 主要函数

```solidity
// 交易控制
function enableTrading() external onlyOwner
function emergencyStop() external onlyOwner

// 税收管理
function updateTaxRates(uint256 _buyTaxRate, uint256 _sellTaxRate) external onlyOwner
function updateTaxWallets(address _marketingWallet, address _liquidityWallet, address _devWallet) external onlyOwner

// 限制管理
function updateTransactionLimits(uint256 _maxTx, uint256 _maxWallet, uint256 _maxDailySell, uint256 _maxDailyBuys) external onlyOwner

// 税收分配
function manualDistributeTaxes() external onlyOwner
```

### LiquidityManager合约

#### 核心功能

1. **流动性添加/移除**
   - 支持手动添加流动性
   - 支持移除流动性
   - 自动添加税收流动性

2. **流动性计算**
   - 计算添加流动性需要的代币数量
   - 计算移除流动性可获得的代币数量

3. **紧急功能**
   - 紧急移除所有流动性
   - 紧急提取代币和ETH

#### 主要函数

```solidity
// 流动性操作
function addLiquidity(uint256 tokenAmount, uint256 ethAmount, uint256 minTokenAmount, uint256 minEthAmount) external payable
function removeLiquidity(uint256 liquidity, uint256 minTokenAmount, uint256 minEthAmount) external

// 自动流动性
function autoAddLiquidityFromTax(uint256 tokenAmount, uint256 ethAmount) external onlyOwner

// 查询功能
function getReserves() external view returns (uint256 tokenReserve, uint256 ethReserve)
function calculateTokenAmountForLiquidity(uint256 ethAmount) external view returns (uint256)
```

## 使用流程

### 1. 初始化设置

1. 部署MemeToken合约
2. 部署LiquidityManager合约
3. 设置Uniswap V2配对地址
4. 开启交易功能

### 2. 添加初始流动性

1. 向LiquidityManager合约发送代币和ETH
2. 调用`addLiquidity`函数添加流动性
3. 验证流动性池创建成功

### 3. 配置交易参数

1. 设置适当的税率（建议不超过10%）
2. 配置交易限制
3. 设置税收钱包地址

### 4. 测试交易功能

1. 在Uniswap上测试买入/卖出
2. 验证税收正确分配
3. 检查交易限制是否生效

### 5. 监控和管理

1. 监控交易量和税收分配
2. 必要时调整参数
3. 处理紧急情况

## 测试指南

### 运行所有测试

```bash
npm run test
```

### 运行特定测试

```bash
# 测试MemeToken合约
npx hardhat test test/MemeToken.test.js

# 测试LiquidityManager合约
npx hardhat test test/LiquidityManager.test.js

# 运行集成测试
npx hardhat test test/Integration.test.js
```

### 测试覆盖率

```bash
npm run coverage
```

## 安全注意事项

### 1. 私钥安全

- 永远不要在代码中硬编码私钥
- 使用环境变量存储敏感信息
- 定期轮换私钥

### 2. 合约安全

- 在主网部署前进行充分的测试
- 考虑进行第三方安全审计
- 使用经过验证的OpenZeppelin合约

### 3. 权限管理

- 限制管理员权限
- 使用多重签名钱包
- 定期审查权限设置

### 4. 参数设置

- 合理设置税率（建议不超过10%）
- 设置适当的交易限制
- 定期评估和调整参数

## 故障排除

### 常见问题

1. **编译错误**
   - 检查Solidity版本兼容性
   - 确保所有依赖已正确安装
   - 检查import路径

2. **部署失败**
   - 检查网络配置
   - 验证账户余额
   - 检查Gas费用

3. **交易失败**
   - 检查交易限制
   - 验证账户权限
   - 检查合约状态

4. **测试失败**
   - 检查测试环境配置
   - 验证Mock合约设置
   - 检查测试数据

### 调试技巧

1. 使用Hardhat的console.log进行调试
2. 检查交易事件日志
3. 使用Remix IDE进行交互式调试
4. 查看合约状态和变量

## 部署验证

### Etherscan验证

```bash
npx hardhat verify --network sepolia <contract_address> <constructor_arguments>
```

### 示例验证命令

```bash
# 验证MemeToken合约
npx hardhat verify --network sepolia 0x1234... "MemeShiba" "MEMESHI" 1000000000 0x... 0x... 0x...

# 验证LiquidityManager合约
npx hardhat verify --network sepolia 0x5678... 0x1234...
```

## 维护和升级

### 监控指标

1. **交易量监控**
   - 日交易量
   - 活跃用户数
   - 税收收入

2. **流动性监控**
   - 流动性池大小
   - LP代币价格
   - 无常损失

3. **技术监控**
   - Gas使用情况
   - 合约调用频率
   - 错误率