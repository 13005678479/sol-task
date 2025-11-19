// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ArithmeticOptimized
 * @dev Gas-optimized version of arithmetic operations
 * @author Foundry Task
 */
contract ArithmeticOptimized {
    
    // Packed storage to reduce gas costs
    struct CompactData {
        uint128 lastResult;      // 128 bits
        uint128 operationCount;   // 128 bits
    }
    
    CompactData private data;
    
    // Using uint8 for operation codes to save gas
    uint8 private constant ADD = 1;
    uint8 private constant SUBTRACT = 2;
    uint8 private constant MULTIPLY = 3;
    uint8 private constant DIVIDE = 4;
    
    // Custom errors (cheaper than revert strings)
    error DivisionByZero();
    error Underflow();
    error InvalidOperation();
    
    // Optimized events with indexed parameters
    event OperationPerformed(
        uint8 indexed operationType,
        uint256 indexed a,
        uint256 indexed b,
        uint256 result
    );
    
    /**
     * @dev Optimized add function
     * @param a First number
     * @param b Second number
     * @return sum The result
     */
    function add(uint256 a, uint256 b) external returns (uint256 sum) {
        assembly {
            sum := add(a, b)
        }
        data.lastResult = uint128(sum);
        unchecked {
            data.operationCount++;
        }
        emit OperationPerformed(ADD, a, b, sum);
    }
    
    /**
     * @dev Optimized subtract function
     * @param a Minuend
     * @param b Subtrahend
     * @return difference The result
     */
    function subtract(uint256 a, uint256 b) external returns (uint256 difference) {
        if (b > a) revert Underflow();
        assembly {
            difference := sub(a, b)
        }
        data.lastResult = uint128(difference);
        unchecked {
            data.operationCount++;
        }
        emit OperationPerformed(SUBTRACT, a, b, difference);
    }
    
    /**
     * @dev Optimized multiply function
     * @param a First number
     * @param b Second number
     * @return product The result
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
     * @dev Optimized divide function
     * @param a Dividend
     * @param b Divisor
     * @return quotient The result
     */
    function divide(uint256 a, uint256 b) external returns (uint256 quotient) {
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
    
    /**
     * @dev Ultra-optimized batch operations using assembly
     * @param operations Array of operation codes
     * @param values Array of value pairs
     * @return results Array of results
     */
    function batchOperationsOptimized(
        uint8[] calldata operations, 
        uint256[2][] calldata values
    ) external returns (uint256[] memory results) {
        uint256 length = operations.length;
        results = new uint256[](length);
        
        for (uint256 i = 0; i < length;) {
            uint8 op = operations[i];
            uint256 a = values[i][0];
            uint256 b = values[i][1];
            uint256 result;
            
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
            unchecked { ++i; }
        }
        
        data.lastResult = uint128(results[length - 1]);
        unchecked { data.operationCount += uint128(length); }
    }
    
    /**
     * @dev Get compact data in single call
     * @return lastResult_ The last result
     * @return operationCount_ The operation count
     */
    function getCompactData() external view returns (uint256 lastResult_, uint256 operationCount_) {
        lastResult_ = data.lastResult;
        operationCount_ = data.operationCount;
    }
    
    /**
     * @dev Reset all data efficiently
     */
    function reset() external {
        data.lastResult = 0;
        data.operationCount = 0;
    }
}