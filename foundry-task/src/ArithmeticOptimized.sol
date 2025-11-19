// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ArithmeticOptimized
 * @dev Gas优化版本的算术操作合约
 * @notice 通过多种优化技术大幅降低Gas消耗，包括汇编优化、存储打包、unchecked等
 * @author Foundry Task
 */
contract ArithmeticOptimized {
    
    // ========================= 存储优化结构体 =========================
    /**
     * @dev 紧凑数据结构，将两个状态变量打包到单个存储槽中
     * @notice 使用uint128而非uint256，每个变量占用128位，两个变量共256位
     * 优化效果：将两个存储槽合并为一个，节省SSTORE和SLOAD的Gas消耗
     * 
     * 存储布局：
     * - 位0-127: lastResult (最后一次操作结果)
     * - 位128-255: operationCount (操作计数)
     */
    struct CompactData {
        uint128 lastResult;      // 最后一次操作结果，限制为128位
        uint128 operationCount;   // 操作计数，限制为128位
    }
    
    // 将紧凑数据结构存储在私有变量中，防止外部直接访问
    CompactData private data;
    
    // ========================= 操作常量定义 =========================
    // 使用uint8常量而非字符串，节省存储和计算开销
    uint8 private constant ADD = 1;        // 加法操作码
    uint8 private constant SUBTRACT = 2;   // 减法操作码
    uint8 private constant MULTIPLY = 3;   // 乘法操作码
    uint8 private constant DIVIDE = 4;     // 除法操作码
    
    // ========================= 自定义错误定义 =========================
    // 自定义错误比require字符串节省约50%的Gas
    error DivisionByZero();     // 除零错误
    error Underflow();          // 下溢错误
    error InvalidOperation();   // 无效操作错误
    
    // ========================= 优化事件定义 =========================
    /**
     * @dev 统一的操作事件，使用indexed参数优化过滤和Gas消耗
     * @notice 将四种操作合并为一个事件，减少事件定义开销
     * 
     * 优化特性：
     * - operationType使用indexed，便于事件过滤
     * - a和b参数也使用indexed，提高查询效率
     * - 单一事件减少合约部署成本
     */
    event OperationPerformed(
        uint8 indexed operationType,
        uint256 indexed a,
        uint256 indexed b,
        uint256 result
    );
    
    // ========================= 优化算术函数 =========================
    
    /**
     * @dev 优化的加法函数
     * @notice 使用内联汇编和unchecked块实现最小Gas消耗
     * @param a 第一个加数
     * @param b 第二个加数
     * @return sum 加法运算的结果
     * 
     * 优化技术：
     * 1. 内联汇编：避免Solidity的额外检查和包装
     * 2. unchecked块：跳过溢出检查（在^0.8.0中默认开启）
     * 3. uint128转换：确保数据适配打包存储结构
     * 4. external函数：比public函数更节省Gas
     */
    function add(uint256 a, uint256 b) external returns (uint256 sum) {
        // 使用内联汇编执行加法，避免Solidity的额外检查
        assembly {
            sum := add(a, b)
        }
        
        // 将结果转换为uint128以适应紧凑存储
        data.lastResult = uint128(sum);
        
        // unchecked块内递增计数器，跳过溢出检查
        unchecked {
            data.operationCount++;
        }
        
        // 发出统一事件
        emit OperationPerformed(ADD, a, b, sum);
    }
    
    /**
     * @dev 优化的减法函数
     * @notice 包含必要的安全检查，同时最大化Gas效率
     * @param a 被减数
     * @param b 减数
     * @return difference 减法运算的结果
     * 
     * 安全与优化的平衡：
     * - 保留下溢检查：这是必要的安全措施
     * - 使用汇编执行实际减法操作
     * - 使用unchecked块递增计数器
     */
    function subtract(uint256 a, uint256 b) external returns (uint256 difference) {
        // 必要的安全检查：防止下溢
        if (b > a) revert Underflow();
        
        // 使用内联汇编执行减法
        assembly {
            difference := sub(a, b)
        }
        
        // 更新状态
        data.lastResult = uint128(difference);
        unchecked {
            data.operationCount++;
        }
        
        emit OperationPerformed(SUBTRACT, a, b, difference);
    }
    
    /**
     * @dev 优化的乘法函数
     * @notice 使用汇编执行乘法，适用于可信任的输入范围
     * @param a 第一个乘数
     * @param b 第二个乘数
     * @return product 乘法运算的结果
     * 
     * 注意事项：
     * - 汇编中的mul不进行溢出检查，调用者需确保结果在uint128范围内
     * - 这种优化适用于已知输入范围的场景
     */
    function multiply(uint256 a, uint256 b) external returns (uint256 product) {
        assembly {
            product := mul(a, b)
        }
        
        data.lastResult = uint128(product);
        unchecked {
            data.operationCount++;
        }
        
        emit OperationPerformed(MULTIPLY, a, b, product);
    }
    
    /**
     * @dev 优化的除法函数
     * @notice 结合汇编优化和必要的安全检查
     * @param a 被除数
     * @param b 除数
     * @return quotient 除法运算的结果
     * 
     * 优化特点：
     * - 保留除零检查：这是不可妥协的安全措施
     * - 汇编执行除法：避免Solidity的额外包装
     */
    function divide(uint256 a, uint256 b) external returns (uint256 quotient) {
        // 必要的安全检查：防止除零
        if (b == 0) revert DivisionByZero();
        
        assembly {
            quotient := div(a, b)
        }
        
        data.lastResult = uint128(quotient);
        unchecked {
            data.operationCount++;
        }
        
        emit OperationPerformed(DIVIDE, a, b, quotient);
    }
    
    // ========================= 超优化批量操作 =========================
    
    /**
     * @dev 超优化的批量操作函数
     * @notice 结合多种优化技术，实现批量操作的极致Gas效率
     * @param operations 操作代码数组，使用calldata节省内存
     * @param values 操作数对数组，使用calldata避免复制
     * @return results 对应每个操作的结果数组
     * 
     * 优化技术应用：
     * 1. calldata参数：避免内存复制，降低Gas消耗
     * 2. 汇编操作：每个算术运算都使用汇编
     * 3. unchecked递增：跳过不必要的溢出检查
     * 4. 优化的循环：使用++i的前缀递增形式
     * 5. 批量更新：一次性更新所有状态，减少存储操作
     */
    function batchOperationsOptimized(
        uint8[] calldata operations, 
        uint256[2][] calldata values
    ) external returns (uint256[] memory results) {
        uint256 length = operations.length;
        results = new uint256[](length);
        
        // 优化的循环：使用前缀递增和unchecked块
        for (uint256 i = 0; i < length;) {
            uint8 op = operations[i];
            uint256 a = values[i][0];
            uint256 b = values[i][1];
            uint256 result;
            
            // 根据操作类型执行相应的汇编运算
            if (op == ADD) {
                assembly { result := add(a, b) }
            } else if (op == SUBTRACT) {
                if (b > a) revert Underflow();
                assembly { result := sub(a, b) }
            } else if (op == MULTIPLY) {
                assembly { result := mul(a, b) }
            } else if (op == DIVIDE) {
                if (b == 0) revert DivisionByZero();
                assembly { result := div(a, b) }
            } else {
                revert InvalidOperation();
            }
            
            results[i] = result;
            unchecked { ++i; }  // 优化的递增方式
        }
        
        // 批量更新状态：一次性设置最后结果和操作计数
        data.lastResult = uint128(results[length - 1]);
        unchecked { 
            data.operationCount += uint128(length); 
        }
    }
    
    // ========================= 查询函数 =========================
    
    /**
     * @dev 一次性获取紧凑数据
     * @notice 单次调用返回所有状态数据，避免多次调用的Gas开销
     * @return lastResult_ 最后一次操作结果
     * @return operationCount_ 操作总计数
     * 
     * 优化效果：
     * - 避免多次SLOAD操作
     * - 减少函数调用开销
     * - 适合前端批量获取状态
     */
    function getCompactData() external view returns (uint256 lastResult_, uint256 operationCount_) {
        lastResult_ = data.lastResult;
        operationCount_ = data.operationCount;
    }
    
    /**
     * @dev 高效重置所有数据
     * @notice 将紧凑数据结构重置为初始状态
     * 
     * 优化特性：
     * - 单次存储操作重置整个结构体
     * - 比分别重置两个字段更节省Gas
     */
    function reset() external {
        data.lastResult = 0;
        data.operationCount = 0;
    }
}