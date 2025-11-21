# 修复总结

## 问题描述
测试运行时出现错误：`TypeError: tokenA.deployed is not a function`

## 根本原因
项目使用了ethers.js v6，但代码还在使用v5的API语法。

## 修复内容

### 1. ethers.js API 更新

#### 移除 `.deployed()` 调用
- **位置**: `test/SimpleUniswap.test.js`, `scripts/deploy.js`
- **原因**: ethers.js v6 中，合约部署后会自动等待完成，不再需要 `.deployed()` 调用

#### 替换 `ethers.utils` 调用
- **旧语法**: `ethers.utils.parseUnits()`, `ethers.utils.formatUnits()`, `ethers.constants.AddressZero`
- **新语法**: `ethers.parseUnits()`, `ethers.formatUnits()`, `ethers.ZeroAddress`

#### 更新合约地址获取方式
- **旧语法**: `contract.address`
- **新语法**: `await contract.getAddress()`
- **影响文件**: 所有使用合约地址的地方都需要添加 `await` 关键字

### 2. Solidity 版本升级
- 从 `0.8.19` 升级到 `0.8.20` 以兼容 OpenZeppelin 5.x

### 3. OpenZeppelin 5.x 兼容性
- 更新 `Ownable` 构造函数调用：`Ownable(msg.sender)`
- 修复 `getPairs` 函数：从 `pure` 改为 `view`

## 文件修改清单

### 核心文件
1. **hardhat.config.js** - 升级 Solidity 版本，添加测试网配置
2. **contracts/ERC20Token.sol** - 修复 Solidity 版本和 Ownable 构造函数
3. **contracts/LiquidityPool.sol** - 修复 Solidity 版本、Ownable 构造函数、getPairs 函数
4. **test/SimpleUniswap.test.js** - 更新所有 ethers.js API 调用
5. **scripts/deploy.js** - 更新所有 ethers.js API 调用

### 配置文件
1. **package.json** - 添加新依赖和部署脚本
2. **constant.env** - 环境变量配置
3. **DEPLOY.md** - 部署说明文档

## 验证结果
- ✅ 所有测试通过 (`npm run test`)
- ✅ 合约编译成功 (`npm run compile`)
- ✅ 本地节点启动正常 (`npm run node`)
- ✅ 测试网配置完成

## 使用说明

### 本地测试
```bash
npm run test          # 运行测试
npm run compile       # 编译合约
```

### 部署
```bash
# 本地部署
npm run node         # 启动本地节点
npm run deploy       # 部署到本地网络

# Sepolia 测试网部署
# 1. 配置 constant.env 中的 PRIVATE_KEY
npm run deploy:sepolia
```

## 技术栈更新
- **Hardhat**: 保持最新版本
- **Ethers.js**: v5 → v6 API 适配
- **OpenZeppelin**: 兼容 5.x 版本
- **Solidity**: 0.8.19 → 0.8.20

所有修复已完成，项目现在完全兼容最新的技术栈版本。