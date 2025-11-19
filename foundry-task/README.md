# Foundry 算术合约项目

基于Foundry框架的Solidity算术操作和Gas优化演示项目。

## 项目特性

- **基础算术操作**：加法、减法、乘法、除法
- **Gas优化版本**：多种优化技术的实现
- **全面测试覆盖**：包含Gas消耗分析和性能对比
- **详细中文注释**：便于学习和理解

## 合约说明

### Arithmetic.sol
基础版本的算术合约，包含：
- 四种基本算术操作
- 操作结果和计数的状态管理
- 事件记录和错误处理
- 批量操作功能

### ArithmeticOptimized.sol
Gas优化版本，应用了：
- 内联汇编优化
- 存储打包技术
- unchecked块优化
- calldata参数优化
- 统一事件定义

## 快速开始

### 安装Foundry
```bash
# Windows
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 或从GitHub下载
# https://github.com/foundry-rs/foundry/releases
```

### 项目设置
```bash
# 安装依赖
forge install

# 编译合约
forge build

# 运行测试
forge test

# Gas消耗报告
forge test --gas-report
```

## 测试说明

### 基础功能测试
```bash
forge test --match-test testBasicArithmetic -vvv
```

### Gas消耗分析
```bash
forge test --match-test testGasConsumption -vvv
```

### 批量操作测试
```bash
forge test --match-test testBatchOperationsGas -vvv
```

### 错误处理测试
```bash
forge test --match-test testErrorHandling -vvv
```

## Gas优化分析

项目实现了多种Gas优化技术：

1. **汇编优化**：直接使用EVM指令
2. **存储优化**：将多个变量打包到单个存储槽
3. ** unchecked优化**：跳过不必要的溢出检查
4. **事件优化**：使用indexed参数和统一事件

## 部署

### 本地网络
```bash
anvil  # 启动本地网络
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

### 测试网
```bash
# Sepolia
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast
```

## 许可证
MIT License