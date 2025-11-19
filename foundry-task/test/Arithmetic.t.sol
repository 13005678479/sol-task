// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// 导入Foundry测试框架
import "forge-std/Test.sol";
// 导入要测试的合约
import "../src/Arithmetic.sol";
import "../src/ArithmeticOptimized.sol";

/**
 * @title ArithmeticTest
 * @dev 算术合约的综合测试套件
 * @notice 包含功能测试、Gas消耗分析、错误处理和事件测试
 * @author Foundry Task
 */
contract ArithmeticTest is Test {
    
    // ========================= 测试合约实例 =========================
    // 基础版本的算术合约实例
    Arithmetic public arithmetic;
    
    // 优化版本的算术合约实例
    ArithmeticOptimized public arithmeticOptimized;
    
    // ========================= Gas消耗追踪变量 =========================
    // 记录基础合约的Gas消耗
    uint256 public gasUsedBasic;
    
    // 记录优化合约的Gas消耗
    uint256 public gasUsedOptimized;
    
    // ========================= 事件声明 =========================
    // 为测试事件监听而声明的事件定义
    // 基础合约的事件
    event AdditionPerformed(uint256 a, uint256 b, uint256 result);
    event SubtractionPerformed(uint256 a, uint256 b, uint256 result);
    event MultiplicationPerformed(uint256 a, uint256 b, uint256 result);
    event DivisionPerformed(uint256 a, uint256 b, uint256 result);
    
    // ========================= 测试环境设置 =========================
    /**
     * @dev 测试前的初始化函数
     * @notice 在每个测试函数执行前自动调用
     * 
     * 设置内容：
     * 1. 部署两个版本的合约
     * 2. 初始化测试环境
     */
    function setUp() public {
        // 部署基础版本的算术合约
        arithmetic = new Arithmetic();
        
        // 部署优化版本的算术合约
        arithmeticOptimized = new ArithmeticOptimized();
    }
    
    // ========================= 基础功能测试 =========================
    
    /**
     * @dev 测试基础版本合约的所有算术操作
     * @notice 验证加法、减法、乘法、除法的正确性
     * 
     * 测试覆盖：
     * - 四种基本算术操作的数学正确性
     * - 状态变量lastResult的更新
     * - 操作的正确执行顺序
     */
    function testBasicArithmetic() public {
        // 测试加法操作：10 + 20 = 30
        assertEq(arithmetic.add(10, 20), 30, "Addition should work");
        assertEq(arithmetic.getLastResult(), 30, "Last result should be 30");
        
        // 测试减法操作：30 - 15 = 15
        assertEq(arithmetic.subtract(30, 15), 15, "Subtraction should work");
        assertEq(arithmetic.getLastResult(), 15, "Last result should be 15");
        
        // 测试乘法操作：5 * 6 = 30
        assertEq(arithmetic.multiply(5, 6), 30, "Multiplication should work");
        assertEq(arithmetic.getLastResult(), 30, "Last result should be 30");
        
        // 测试除法操作：30 / 5 = 6
        assertEq(arithmetic.divide(30, 5), 6, "Division should work");
        assertEq(arithmetic.getLastResult(), 6, "Last result should be 6");
    }
    
    /**
     * @dev 测试优化版本合约的所有算术操作
     * @notice 验证优化合约的功能正确性和状态管理
     * 
     * 测试重点：
     * - 优化操作的数学正确性
     * - 紧凑数据结构的正确性
     * - 操作计数的准确性
     */
    function testOptimizedArithmetic() public {
        // 测试加法操作
        assertEq(arithmeticOptimized.add(10, 20), 30, "Optimized addition should work");
        (uint256 lastResult, uint256 opCount) = arithmeticOptimized.getCompactData();
        assertEq(lastResult, 30, "Optimized last result should be 30");
        assertEq(opCount, 1, "Operation count should be 1");
        
        // 测试减法操作
        assertEq(arithmeticOptimized.subtract(30, 15), 15, "Optimized subtraction should work");
        (lastResult, opCount) = arithmeticOptimized.getCompactData();
        assertEq(lastResult, 15, "Optimized last result should be 15");
        assertEq(opCount, 2, "Operation count should be 2");
        
        // 测试乘法操作
        assertEq(arithmeticOptimized.multiply(5, 6), 30, "Optimized multiplication should work");
        
        // 测试除法操作
        assertEq(arithmeticOptimized.divide(30, 5), 6, "Optimized division should work");
    }
    
    // ========================= Gas消耗分析测试 =========================
    
    /**
     * @dev 测试加法操作的Gas消耗对比
     * @notice 比较基础版本和优化版本在加法操作上的Gas消耗
     * 
     * 测试方法：
     * 1. 使用gasleft()测量基础版本的Gas消耗
     * 2. 使用gasleft()测量优化版本的Gas消耗
     * 3. 计算并输出节省的Gas数量
     * 4. 验证优化版本确实更节省Gas
     */
    function testGasConsumption_Addition() public {
        // 测试基础版本加法的Gas消耗
        uint256 startGas = gasleft();
        arithmetic.add(100, 200);
        gasUsedBasic = startGas - gasleft();
        
        // 测试优化版本加法的Gas消耗
        startGas = gasleft();
        arithmeticOptimized.add(100, 200);
        gasUsedOptimized = startGas - gasleft();
        
        // 输出Gas消耗对比结果
        console.log("Gas used for basic addition:", gasUsedBasic);
        console.log("Gas used for optimized addition:", gasUsedOptimized);
        console.log("Gas savings:", gasUsedBasic - gasUsedOptimized);
        
        // 验证优化版本确实节省了Gas
        assertTrue(gasUsedOptimized < gasUsedBasic, "Optimized should use less gas");
    }
    
    /**
     * @dev 测试减法操作的Gas消耗对比
     * @notice 验证优化技术在减法操作上的效果
     */
    function testGasConsumption_Subtraction() public {
        // 测试基础版本减法的Gas消耗
        uint256 startGas = gasleft();
        arithmetic.subtract(300, 150);
        gasUsedBasic = startGas - gasleft();
        
        // 测试优化版本减法的Gas消耗
        startGas = gasleft();
        arithmeticOptimized.subtract(300, 150);
        gasUsedOptimized = startGas - gasleft();
        
        // 输出详细的Gas消耗分析
        console.log("Gas used for basic subtraction:", gasUsedBasic);
        console.log("Gas used for optimized subtraction:", gasUsedOptimized);
        console.log("Gas savings:", gasUsedBasic - gasUsedOptimized);
        
        // 验证优化效果
        assertTrue(gasUsedOptimized < gasUsedBasic, "Optimized should use less gas");
    }
    
    /**
     * @dev 测试乘法操作的Gas消耗对比
     * @notice 分析乘法操作中汇编优化的效果
     */
    function testGasConsumption_Multiplication() public {
        // 测试基础版本乘法的Gas消耗
        uint256 startGas = gasleft();
        arithmetic.multiply(25, 4);
        gasUsedBasic = startGas - gasleft();
        
        // 测试优化版本乘法的Gas消耗
        startGas = gasleft();
        arithmeticOptimized.multiply(25, 4);
        gasUsedOptimized = startGas - gasleft();
        
        // 输出乘法操作的Gas对比数据
        console.log("Gas used for basic multiplication:", gasUsedBasic);
        console.log("Gas used for optimized multiplication:", gasUsedOptimized);
        console.log("Gas savings:", gasUsedBasic - gasUsedOptimized);
        
        // 验证汇编优化的效果
        assertTrue(gasUsedOptimized < gasUsedBasic, "Optimized should use less gas");
    }
    
    /**
     * @dev 测试除法操作的Gas消耗对比
     * @notice 验证除法操作中安全检查和汇编优化的平衡
     */
    function testGasConsumption_Division() public {
        // 测试基础版本除法的Gas消耗
        uint256 startGas = gasleft();
        arithmetic.divide(100, 25);
        gasUsedBasic = startGas - gasleft();
        
        // 测试优化版本除法的Gas消耗
        startGas = gasleft();
        arithmeticOptimized.divide(100, 25);
        gasUsedOptimized = startGas - gasleft();
        
        // 输出除法操作的Gas分析
        console.log("Gas used for basic division:", gasUsedBasic);
        console.log("Gas used for optimized division:", gasUsedOptimized);
        console.log("Gas savings:", gasUsedBasic - gasUsedOptimized);
        
        // 验证优化效果
        assertTrue(gasUsedOptimized < gasUsedBasic, "Optimized should use less gas");
    }
    
    /**
     * @dev 测试批量操作的Gas消耗对比
     * @notice 验证批量操作中多种优化技术的综合效果
     * 
     * 测试场景：
     * - 执行包含四种操作类型的批量测试
     * - 对比基础批量操作和优化批量操作的Gas消耗
     * - 分析calldata、汇编、unchecked等技术的优化效果
     */
    function testBatchOperationsGas() public {
        // 准备批量操作数据
        uint8[] memory operations = new uint8[](4);
        operations[0] = 1; // 加法操作
        operations[1] = 2; // 减法操作
        operations[2] = 3; // 乘法操作
        operations[3] = 4; // 除法操作
        
        uint256[2][] memory values = new uint256[2][](4);
        values[0] = [uint256(10), uint256(20)];  // 10 + 20 = 30
        values[1] = [uint256(50), uint256(25)];  // 50 - 25 = 25
        values[2] = [uint256(5), uint256(6)];    // 5 * 6 = 30
        values[3] = [uint256(30), uint256(5)];   // 30 / 5 = 6
        
        // 测试基础版本批量操作的Gas消耗
        uint256 startGas = gasleft();
        arithmetic.batchOperations(operations, values);
        gasUsedBasic = startGas - gasleft();
        
        // 测试优化版本批量操作的Gas消耗
        startGas = gasleft();
        arithmeticOptimized.batchOperationsOptimized(operations, values);
        gasUsedOptimized = startGas - gasleft();
        
        // 输出批量操作的详细Gas对比
        console.log("Gas used for basic batch operations:", gasUsedBasic);
        console.log("Gas used for optimized batch operations:", gasUsedOptimized);
        console.log("Batch operations gas savings:", gasUsedBasic - gasUsedOptimized);
        
        // 验证批量操作的优化效果
        assertTrue(gasUsedOptimized < gasUsedBasic, "Optimized batch should use less gas");
    }
    
    // ========================= 错误处理测试 =========================
    
    /**
     * @dev 测试错误处理机制
     * @notice 验证两个版本合约的错误处理和回滚行为
     * 
     * 测试场景：
     * - 除零错误：验证DivisionByZero自定义错误的触发
     * - 下溢错误：验证Underflow自定义错误的触发
     * - 错误消息的一致性
     */
    function testErrorHandling() public {
        // 测试除零错误 - 基础版本
        vm.expectRevert(Arithmetic.DivisionByZero.selector);
        arithmetic.divide(100, 0);
        
        // 测试除零错误 - 优化版本
        vm.expectRevert(ArithmeticOptimized.DivisionByZero.selector);
        arithmeticOptimized.divide(100, 0);
        
        // 测试下溢错误 - 基础版本（10 - 20）
        vm.expectRevert(Arithmetic.Underflow.selector);
        arithmetic.subtract(10, 20);
        
        // 测试下溢错误 - 优化版本（10 - 20）
        vm.expectRevert(ArithmeticOptimized.Underflow.selector);
        arithmeticOptimized.subtract(10, 20);
    }
    
    // ========================= 事件测试 =========================
    
    /**
     * @dev 测试事件发射机制
     * @notice 验证基础合约的事件正确发射和参数传递
     * 
     * 测试方法：
     * - 使用vm.expectEmit设置事件预期
     * - 验证事件的参数正确性
     * - 确保每个操作都正确发射对应事件
     */
    function testEventEmission() public {
        // 测试加法事件发射
        vm.expectEmit(true, true, true, true);
        emit AdditionPerformed(10, 20, 30);
        arithmetic.add(10, 20);
        
        // 测试减法事件发射
        vm.expectEmit(true, true, true, true);
        emit SubtractionPerformed(30, 15, 15);
        arithmetic.subtract(30, 15);
        
        // 测试乘法事件发射
        vm.expectEmit(true, true, true, true);
        emit MultiplicationPerformed(5, 6, 30);
        arithmetic.multiply(5, 6);
        
        // 测试除法事件发射
        vm.expectEmit(true, true, true, true);
        emit DivisionPerformed(30, 5, 6);
        arithmetic.divide(30, 5);
    }
    
    // ========================= 状态管理测试 =========================
    
    /**
     * @dev 测试操作计数和状态管理
     * @notice 验证操作计数的准确性和重置功能
     * 
     * 测试内容：
     * - 初始状态验证
     * - 操作计数的递增
     * - 重置功能的正确性
     * - 状态变量的持久性
     */
    function testOperationCount() public {
        // 验证初始操作计数为0
        assertEq(arithmetic.getOperationCount(), 0, "Initial count should be 0");
        
        // 执行第一个操作，验证计数变为1
        arithmetic.add(1, 2);
        assertEq(arithmetic.getOperationCount(), 1, "Count should be 1 after 1 operation");
        
        // 执行第二个操作，验证计数变为2
        arithmetic.subtract(5, 3);
        assertEq(arithmetic.getOperationCount(), 2, "Count should be 2 after 2 operations");
        
        // 执行第三个操作，验证计数变为3
        arithmetic.multiply(2, 3);
        assertEq(arithmetic.getOperationCount(), 3, "Count should be 3 after 3 operations");
        
        // 执行第四个操作，验证计数变为4
        arithmetic.divide(6, 2);
        assertEq(arithmetic.getOperationCount(), 4, "Count should be 4 after 4 operations");
        
        // 测试重置功能
        arithmetic.reset();
        assertEq(arithmetic.getOperationCount(), 0, "Count should be 0 after reset");
        assertEq(arithmetic.getLastResult(), 0, "Last result should be 0 after reset");
    }
}