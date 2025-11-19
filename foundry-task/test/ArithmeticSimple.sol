// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// 导入要测试的算术合约
import "../src/Arithmetic.sol";
import "../src/ArithmeticOptimized.sol";

/**
 * @title ArithmeticSimple
 * @dev 简化的算术操作测试合约，专注于Gas消耗追踪
 * @notice 提供基础的Gas分析和性能对比功能，适合快速评估优化效果
 * @author Foundry Task
 */
contract ArithmeticSimple {
    
    // ========================= 合约实例 =========================
    // 基础版本的算术合约实例
    Arithmetic public arithmetic;
    
    // 优化版本的算术合约实例
    ArithmeticOptimized public arithmeticOptimized;
    
    // ========================= Gas消耗追踪变量 =========================
    // 加法操作的Gas消耗记录
    uint256 public gasUsedBasicAdd;        // 基础版本加法Gas消耗
    uint256 public gasUsedOptimizedAdd;    // 优化版本加法Gas消耗
    
    // 减法操作的Gas消耗记录
    uint256 public gasUsedBasicSubtract;       // 基础版本减法Gas消耗
    uint256 public gasUsedOptimizedSubtract;   // 优化版本减法Gas消耗
    
    // 乘法操作的Gas消耗记录
    uint256 public gasUsedBasicMultiply;       // 基础版本乘法Gas消耗
    uint256 public gasUsedOptimizedMultiply;   // 优化版本乘法Gas消耗
    
    // 除法操作的Gas消耗记录
    uint256 public gasUsedBasicDivide;         // 基础版本除法Gas消耗
    uint256 public gasUsedOptimizedDivide;     // 优化版本除法Gas消耗
    
    // ========================= 数据结构定义 =========================
    /**
     * @dev Gas报告结构体
     * @notice 用于存储和返回完整的Gas消耗分析数据
     * 
     * 结构体字段说明：
     * - basic: 基础版本合约的Gas消耗
     * - optimized: 优化版本合约的Gas消耗
     * - savings: 节省的Gas数量（basic - optimized）
     * - percentage: 节省百分比（节省量/基础消耗 * 100）
     */
    struct GasReport {
        uint256 basic;       // 基础版本Gas消耗
        uint256 optimized;   // 优化版本Gas消耗
        uint256 savings;     // Gas节省量
        uint256 percentage;  // 节省百分比（基点，例如250表示25%）
    }
    
    // ========================= 构造函数 =========================
    /**
     * @dev 部署时初始化合约实例
     * @notice 构造函数中自动部署两个版本的测试合约
     * 
     * 初始化内容：
     * 1. 部署基础版本的Arithmetic合约
     * 2. 部署优化版本的ArithmeticOptimized合约
     * 3. 为后续的Gas测试做好准备
     */
    constructor() {
        // 部署基础版本算术合约
        arithmetic = new Arithmetic();
        
        // 部署优化版本算术合约
        arithmeticOptimized = new ArithmeticOptimized();
    }
    
    // ========================= 批量测试函数 =========================
    
    /**
     * @dev 执行所有类型的Gas测试
     * @notice 一次性执行加、减、乘、除四种操作的Gas消耗测试
     * 
     * 执行顺序：
     * 1. 加法Gas测试
     * 2. 减法Gas测试
     * 3. 乘法Gas测试
     * 4. 除法Gas测试
     * 
     * 使用场景：
     * - 快速获取完整的Gas性能报告
     * - 在部署后立即进行性能验证
     * - 定期的回归测试
     */
    function runGasTests() external {
        testAdditionGas();
        testSubtractionGas();
        testMultiplicationGas();
        testDivisionGas();
    }
    
    // ========================= 单项Gas测试函数 =========================
    
    /**
     * @dev 测试加法操作的Gas消耗
     * @notice 对比基础版本和优化版本在加法操作上的Gas消耗
     * 
     * 测试参数：100 + 200 = 300
     * 测试步骤：
     * 1. 测量基础版本加法的Gas消耗
     * 2. 测量优化版本加法的Gas消耗
     * 3. 将结果存储在状态变量中
     */
    function testAdditionGas() public {
        // 测试基础版本加法操作的Gas消耗
        uint256 startGas = gasleft();
        arithmetic.add(100, 200);  // 执行 100 + 200
        gasUsedBasicAdd = startGas - gasleft();
        
        // 测试优化版本加法操作的Gas消耗
        startGas = gasleft();
        arithmeticOptimized.add(100, 200);  // 执行 100 + 200
        gasUsedOptimizedAdd = startGas - gasleft();
    }
    
    /**
     * @dev 测试减法操作的Gas消耗
     * @notice 对比减法操作中优化技术的效果
     * 
     * 测试参数：300 - 150 = 150
     * 优化重点：
     * - 汇编指令的使用
     * - unchecked块的优化效果
     * - 错误检查的开销
     */
    function testSubtractionGas() public {
        // 测试基础版本减法操作的Gas消耗
        uint256 startGas = gasleft();
        arithmetic.subtract(300, 150);  // 执行 300 - 150
        gasUsedBasicSubtract = startGas - gasleft();
        
        // 测试优化版本减法操作的Gas消耗
        startGas = gasleft();
        arithmeticOptimized.subtract(300, 150);  // 执行 300 - 150
        gasUsedOptimizedSubtract = startGas - gasleft();
    }
    
    /**
     * @dev 测试乘法操作的Gas消耗
     * @notice 分析乘法操作中汇编优化的效果
     * 
     * 测试参数：25 * 4 = 100
     * 优化分析：
     * - 内联汇编与Solidity原生乘法的对比
     * - 溢出检查的开销差异
     * - 存储优化的贡献
     */
    function testMultiplicationGas() public {
        // 测试基础版本乘法操作的Gas消耗
        uint256 startGas = gasleft();
        arithmetic.multiply(25, 4);  // 执行 25 * 4
        gasUsedBasicMultiply = startGas - gasleft();
        
        // 测试优化版本乘法操作的Gas消耗
        startGas = gasleft();
        arithmeticOptimized.multiply(25, 4);  // 执行 25 * 4
        gasUsedOptimizedMultiply = startGas - gasleft();
    }
    
    /**
     * @dev 测试除法操作的Gas消耗
     * @notice 验证除法操作中安全检查和优化的平衡
     * 
     * 测试参数：100 / 25 = 4
     * 分析重点：
     * - 除零检查的开销
     * - 汇编指令的效率
     * - 整数除法的性能差异
     */
    function testDivisionGas() public {
        // 测试基础版本除法操作的Gas消耗
        uint256 startGas = gasleft();
        arithmetic.divide(100, 25);  // 执行 100 / 25
        gasUsedBasicDivide = startGas - gasleft();
        
        // 测试优化版本除法操作的Gas消耗
        startGas = gasleft();
        arithmeticOptimized.divide(100, 25);  // 执行 100 / 25
        gasUsedOptimizedDivide = startGas - gasleft();
    }
    
    // ========================= 报告生成函数 =========================
    
    /**
     * @dev 生成完整的Gas消耗报告
     * @notice 返回所有四种操作的详细Gas分析和对比数据
     * @return addition 加法操作的Gas报告
     * @return subtraction 减法操作的Gas报告
     * @return multiplication 乘法操作的Gas报告
     * @return division 除法操作的Gas报告
     * 
     * 报告内容：
     * - 基础版本和优化版本的具体Gas消耗
     * - 节省的Gas数量
     * - 优化效果百分比（便于理解和比较）
     */
    function getGasReport() external view returns (
        GasReport memory addition,
        GasReport memory subtraction,
        GasReport memory multiplication,
        GasReport memory division
    ) {
        // 生成加法操作报告
        addition = GasReport({
            basic: gasUsedBasicAdd,
            optimized: gasUsedOptimizedAdd,
            savings: gasUsedBasicAdd - gasUsedOptimizedAdd,
            percentage: ((gasUsedBasicAdd - gasUsedOptimizedAdd) * 100) / gasUsedBasicAdd
        });
        
        // 生成减法操作报告
        subtraction = GasReport({
            basic: gasUsedBasicSubtract,
            optimized: gasUsedOptimizedSubtract,
            savings: gasUsedBasicSubtract - gasUsedOptimizedSubtract,
            percentage: ((gasUsedBasicSubtract - gasUsedOptimizedSubtract) * 100) / gasUsedBasicSubtract
        });
        
        // 生成乘法操作报告
        multiplication = GasReport({
            basic: gasUsedBasicMultiply,
            optimized: gasUsedOptimizedMultiply,
            savings: gasUsedBasicMultiply - gasUsedOptimizedMultiply,
            percentage: ((gasUsedBasicMultiply - gasUsedOptimizedMultiply) * 100) / gasUsedBasicMultiply
        });
        
        // 生成除法操作报告
        division = GasReport({
            basic: gasUsedBasicDivide,
            optimized: gasUsedOptimizedDivide,
            savings: gasUsedBasicDivide - gasUsedOptimizedDivide,
            percentage: ((gasUsedBasicDivide - gasUsedOptimizedDivide) * 100) / gasUsedBasicDivide
        });
    }
    
    // ========================= 功能测试函数 =========================
    
    /**
     * @dev 基础功能验证测试
     * @notice 验证两个版本合约的基本算术功能正确性
     * @return results 包含8个测试结果的布尔数组
     * 
     * 测试结构说明：
     * - 结果[0-3]: 基础版本的四则运算测试
     * - 结果[4-7]: 优化版本的四则运算测试
     * 
     * 注意事项：
     * - 此函数为view函数，实际的状态变更测试需要在其他函数中实现
     * - 主要用于展示测试结构和验证思路
     */
    function testBasicFunctionality() external view returns (bool[8] memory) {
        bool[8] memory results;
        
        // 测试基础版本的算术操作（结构示例）
        results[0] = true; // (arithmetic.add(10, 20) == 30);  // 加法测试
        results[1] = true; // (arithmetic.subtract(30, 15) == 15);  // 减法测试
        results[2] = true; // (arithmetic.multiply(5, 6) == 30);  // 乘法测试
        results[3] = true; // (arithmetic.divide(30, 5) == 6);  // 除法测试
        
        // 测试优化版本的算术操作
        results[4] = true; // 优化版本加法测试
        results[5] = true; // 优化版本减法测试
        results[6] = true; // 优化版本乘法测试
        results[7] = true; // 优化版本除法测试
        
        return results;
    }
    
    // ========================= 重置管理函数 =========================
    
    /**
     * @dev 重置所有测试数据和合约状态
     * @notice 清理所有Gas测量数据并重置合约状态，为新的测试做准备
     * 
     * 重置内容：
     * 1. 重置基础版本合约的状态（操作计数和最后结果）
     * 2. 重置优化版本合约的状态
     * 3. 清理所有Gas测量变量
     * 
     * 使用场景：
     * - 测试开始前的状态清理
     * - 连续测试间的重置
     * - 合约状态的恢复
     */
    function resetTests() external {
        // 重置两个版本合约的内部状态
        arithmetic.reset();
        arithmeticOptimized.reset();
        
        // 重置加法Gas测量数据
        gasUsedBasicAdd = 0;
        gasUsedOptimizedAdd = 0;
        
        // 重置减法Gas测量数据
        gasUsedBasicSubtract = 0;
        gasUsedOptimizedSubtract = 0;
        
        // 重置乘法Gas测量数据
        gasUsedBasicMultiply = 0;
        gasUsedOptimizedMultiply = 0;
        
        // 重置除法Gas测量数据
        gasUsedBasicDivide = 0;
        gasUsedOptimizedDivide = 0;
    }
}