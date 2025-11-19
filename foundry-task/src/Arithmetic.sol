// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Arithmetic
 * @dev Basic arithmetic operations contract for gas analysis
 * @author Foundry Task
 */
contract Arithmetic {
    
    // Storage variables for gas analysis
    uint256 public lastResult;
    uint256 public operationCount;
    
    // Events for tracking operations
    event AdditionPerformed(uint256 a, uint256 b, uint256 result);
    event SubtractionPerformed(uint256 a, uint256 b, uint256 result);
    event MultiplicationPerformed(uint256 a, uint256 b, uint256 result);
    event DivisionPerformed(uint256 a, uint256 b, uint256 result);
    
    // Errors for better gas efficiency
    error DivisionByZero();
    error Underflow();
    
    /**
     * @dev Add two numbers
     * @param a First number
     * @param b Second number
     * @return sum The result of addition
     */
    function add(uint256 a, uint256 b) public returns (uint256 sum) {
        sum = a + b;
        lastResult = sum;
        operationCount++;
        emit AdditionPerformed(a, b, sum);
    }
    
    /**
     * @dev Subtract two numbers
     * @param a Minuend
     * @param b Subtrahend
     * @return difference The result of subtraction
     */
    function subtract(uint256 a, uint256 b) public returns (uint256 difference) {
        if (b > a) revert Underflow();
        difference = a - b;
        lastResult = difference;
        operationCount++;
        emit SubtractionPerformed(a, b, difference);
    }
    
    /**
     * @dev Multiply two numbers
     * @param a First number
     * @param b Second number
     * @return product The result of multiplication
     */
    function multiply(uint256 a, uint256 b) public returns (uint256 product) {
        product = a * b;
        lastResult = product;
        operationCount++;
        emit MultiplicationPerformed(a, b, product);
    }
    
    /**
     * @dev Divide two numbers
     * @param a Dividend
     * @param b Divisor
     * @return quotient The result of division
     */
    function divide(uint256 a, uint256 b) public returns (uint256 quotient) {
        if (b == 0) revert DivisionByZero();
        quotient = a / b;
        lastResult = quotient;
        operationCount++;
        emit DivisionPerformed(a, b, quotient);
    }
    
    /**
     * @dev Get last operation result
     * @return The last calculated result
     */
    function getLastResult() public view returns (uint256) {
        return lastResult;
    }
    
    /**
     * @dev Get total operation count
     * @return The number of operations performed
     */
    function getOperationCount() public view returns (uint256) {
        return operationCount;
    }
    
    /**
     * @dev Perform batch operations for gas analysis
     * @param operations Array of operation types (1=add, 2=subtract, 3=multiply, 4=divide)
     * @param values Array of values pairs to operate on
     * @return results Array of results
     */
    function batchOperations(uint8[] memory operations, uint256[2][] memory values) 
        public 
        returns (uint256[] memory results) 
    {
        results = new uint256[](operations.length);
        
        for (uint256 i = 0; i < operations.length; i++) {
            if (operations[i] == 1) {
                results[i] = add(values[i][0], values[i][1]);
            } else if (operations[i] == 2) {
                results[i] = subtract(values[i][0], values[i][1]);
            } else if (operations[i] == 3) {
                results[i] = multiply(values[i][0], values[i][1]);
            } else if (operations[i] == 4) {
                results[i] = divide(values[i][0], values[i][1]);
            }
        }
        
        return results;
    }
    
    /**
     * @dev Reset counters for fresh testing
     */
    function reset() public {
        lastResult = 0;
        operationCount = 0;
    }
}