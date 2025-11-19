// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Arithmetic
 * @dev 基础算术操作合约，用于Gas消耗分析
 * @notice 提供基本的加减乘除运算功能，并包含Gas使用分析和事件记录
 * @author Foundry Task
 */
contract Arithmetic {
    
    // ========================= 状态变量 =========================
    // 存储最后一次运算的结果，用于Gas分析时的状态追踪
    uint256 public lastResult;
    
    // 记录执行的操作总次数，用于统计Gas消耗
    uint256 public operationCount;
    
    // ========================= 事件定义 =========================
    // 加法操作事件，记录操作数和结果，便于链下监听和分析
    event AdditionPerformed(uint256 a, uint256 b, uint256 result);
    
    // 减法操作事件，记录被减数、减数和差值
    event SubtractionPerformed(uint256 a, uint256 b, uint256 result);
    
    // 乘法操作事件，记录两个乘数和乘积
    event MultiplicationPerformed(uint256 a, uint256 b, uint256 result);
    
    // 除法操作事件，记录被除数、除数和商
    event DivisionPerformed(uint256 a, uint256 b, uint256 result);
    
    // ========================= 自定义错误 =========================
    // 除零错误，比使用require字符串更节省Gas
    error DivisionByZero();
    
    // 下溢错误，当减数大于被减数时触发
    error Underflow();
    
    // ========================= 基础算术函数 =========================
    
    /**
     * @dev 执行两个无符号整数的加法运算
     * @notice 计算a + b的结果，更新状态并发出事件
     * @param a 第一个加数
     * @param b 第二个加数
     * @return sum 加法运算的结果
     * 
     * 功能说明：
     * 1. 执行加法运算
     * 2. 将结果存储到lastResult状态变量
     * 3. 递增操作计数器
     * 4. 发出AdditionPerformed事件记录操作
     */
    function add(uint256 a, uint256 b) public returns (uint256 sum) {
        // 执行加法运算，Solidity内置溢出检查
        sum = a + b;
        
        // 更新最后一次操作结果状态
        lastResult = sum;
        
        // 递增操作计数器
        operationCount++;
        
        // 发出事件记录此次加法操作
        emit AdditionPerformed(a, b, sum);
    }
    
    /**
     * @dev 执行两个无符号整数的减法运算
     * @notice 计算a - b的结果，包含下溢检查
     * @param a 被减数
     * @param b 减数
     * @return difference 减法运算的结果（差值）
     * 
     * 安全特性：
     * - 检查下溢情况，确保b <= a
     * - 使用自定义错误节省Gas
     */
    function subtract(uint256 a, uint256 b) public returns (uint256 difference) {
        // 安全检查：防止减法下溢
        if (b > a) revert Underflow();
        
        // 执行减法运算
        difference = a - b;
        
        // 更新状态变量
        lastResult = difference;
        operationCount++;
        
        // 发出事件记录此次减法操作
        emit SubtractionPerformed(a, b, difference);
    }
    
    /**
     * @dev 执行两个无符号整数的乘法运算
     * @notice 计算a * b的结果，Solidity自动处理溢出
     * @param a 第一个乘数
     * @param b 第二个乘数
     * @return product 乘法运算的结果（乘积）
     * 
     * 注意事项：
     * - 乘法可能导致溢出，Solidity ^0.8.0会自动检查并回滚
     * - 对于大数乘法，建议使用SafeMath库或进行预检查
     */
    function multiply(uint256 a, uint256 b) public returns (uint256 product) {
        // 执行乘法运算，Solidity内置溢出保护
        product = a * b;
        
        // 更新状态
        lastResult = product;
        operationCount++;
        
        // 发出事件记录此次乘法操作
        emit MultiplicationPerformed(a, b, product);
    }
    
    /**
     * @dev 执行两个无符号整数的除法运算
     * @notice 计算a / b的结果，包含除零检查
     * @param a 被除数
     * @param b 除数
     * @return quotient 除法运算的结果（商）
     * 
     * 安全特性：
     * - 严格检查除数不能为零
     * - 返回整数除法结果，小数部分被截断
     */
    function divide(uint256 a, uint256 b) public returns (uint256 quotient) {
        // 安全检查：防止除零操作
        if (b == 0) revert DivisionByZero();
        
        // 执行整数除法运算
        quotient = a / b;
        
        // 更新状态
        lastResult = quotient;
        operationCount++;
        
        // 发出事件记录此次除法操作
        emit DivisionPerformed(a, b, quotient);
    }
    
    // ========================= 查询函数 =========================
    
    /**
     * @dev 获取最后一次操作的结果
     * @notice 返回最近一次算术操作的计算结果
     * @return 最后一次计算的结果值
     * 
     * 用途：
     * - 在不需要重新计算的情况下获取上次结果
     * - 用于验证操作是否正确执行
     */
    function getLastResult() public view returns (uint256) {
        return lastResult;
    }
    
    /**
     * @dev 获取已执行操作的总次数
     * @notice 返回合约部署以来执行的所有算术操作的总数
     * @return 操作计数器的当前值
     * 
     * 应用场景：
     * - 统计合约使用频率
     * - 计算平均Gas消耗
     * - 监控合约活跃度
     */
    function getOperationCount() public view returns (uint256) {
        return operationCount;
    }
    
    // ========================= 批量操作函数 =========================
    
    /**
     * @dev 批量执行算术操作，用于Gas效率分析
     * @notice 一次性执行多个不同类型的算术操作
     * @param operations 操作类型数组 (1=加法, 2=减法, 3=乘法, 4=除法)
     * @param values 操作数对数组，每个元素包含两个操作数
     * @return results 对应每个操作的结果数组
     * 
     * 使用示例：
     * operations = [1, 2, 3, 4]
     * values = [[10, 20], [30, 15], [5, 6], [30, 5]]
     * results = [30, 15, 30, 6]
     * 
     * Gas优化特点：
     * - 单次交易执行多个操作，减少交易开销
     * - 复用状态更新逻辑
     * - 便于对比单个操作vs批量操作的Gas消耗
     */
    function batchOperations(uint8[] memory operations, uint256[2][] memory values) 
        public 
        returns (uint256[] memory results) 
    {
        // 初始化结果数组，大小与操作数组相同
        results = new uint256[](operations.length);
        
        // 遍历所有操作，依次执行
        for (uint256 i = 0; i < operations.length; i++) {
            // 根据操作类型执行对应的算术运算
            if (operations[i] == 1) {
                // 加法操作
                results[i] = add(values[i][0], values[i][1]);
            } else if (operations[i] == 2) {
                // 减法操作
                results[i] = subtract(values[i][0], values[i][1]);
            } else if (operations[i] == 3) {
                // 乘法操作
                results[i] = multiply(values[i][0], values[i][1]);
            } else if (operations[i] == 4) {
                // 除法操作
                results[i] = divide(values[i][0], values[i][1]);
            }
        }
        
        // 返回所有操作的结果数组
        return results;
    }
    
    // ========================= 管理函数 =========================
    
    /**
     * @dev 重置合约状态，用于新的测试场景
     * @notice 将lastResult和operationCount重置为零
     * 
     * 使用场景：
     * - 在测试前清理状态
     * - 重置Gas计数器开始新的基准测试
     * - 清理统计数据
     * 
     * 注意事项：
     * - 此操作不可逆，会丢失所有历史数据
     * - 建议仅在测试或需要重置时调用
     */
    function reset() public {
        // 重置最后一次操作结果
        lastResult = 0;
        
        // 重置操作计数器
        operationCount = 0;
    }
}