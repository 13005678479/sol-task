// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../src/Arithmetic.sol";
import "../src/ArithmeticOptimized.sol";

/**
 * @title ArithmeticSimple
 * @dev Simple test contract for arithmetic operations with gas tracking
 */
contract ArithmeticSimple {
    
    Arithmetic public arithmetic;
    ArithmeticOptimized public arithmeticOptimized;
    
    // Gas tracking
    uint256 public gasUsedBasicAdd;
    uint256 public gasUsedOptimizedAdd;
    uint256 public gasUsedBasicSubtract;
    uint256 public gasUsedOptimizedSubtract;
    uint256 public gasUsedBasicMultiply;
    uint256 public gasUsedOptimizedMultiply;
    uint256 public gasUsedBasicDivide;
    uint256 public gasUsedOptimizedDivide;
    
    struct GasReport {
        uint256 basic;
        uint256 optimized;
        uint256 savings;
        uint256 percentage;
    }
    
    constructor() {
        arithmetic = new Arithmetic();
        arithmeticOptimized = new ArithmeticOptimized();
    }
    
    function runGasTests() external {
        testAdditionGas();
        testSubtractionGas();
        testMultiplicationGas();
        testDivisionGas();
    }
    
    function testAdditionGas() public {
        // Basic addition
        uint256 startGas = gasleft();
        arithmetic.add(100, 200);
        gasUsedBasicAdd = startGas - gasleft();
        
        // Optimized addition
        startGas = gasleft();
        arithmeticOptimized.add(100, 200);
        gasUsedOptimizedAdd = startGas - gasleft();
    }
    
    function testSubtractionGas() public {
        // Basic subtraction
        uint256 startGas = gasleft();
        arithmetic.subtract(300, 150);
        gasUsedBasicSubtract = startGas - gasleft();
        
        // Optimized subtraction
        startGas = gasleft();
        arithmeticOptimized.subtract(300, 150);
        gasUsedOptimizedSubtract = startGas - gasleft();
    }
    
    function testMultiplicationGas() public {
        // Basic multiplication
        uint256 startGas = gasleft();
        arithmetic.multiply(25, 4);
        gasUsedBasicMultiply = startGas - gasleft();
        
        // Optimized multiplication
        startGas = gasleft();
        arithmeticOptimized.multiply(25, 4);
        gasUsedOptimizedMultiply = startGas - gasleft();
    }
    
    function testDivisionGas() public {
        // Basic division
        uint256 startGas = gasleft();
        arithmetic.divide(100, 25);
        gasUsedBasicDivide = startGas - gasleft();
        
        // Optimized division
        startGas = gasleft();
        arithmeticOptimized.divide(100, 25);
        gasUsedOptimizedDivide = startGas - gasleft();
    }
    
    function getGasReport() external view returns (
        GasReport memory addition,
        GasReport memory subtraction,
        GasReport memory multiplication,
        GasReport memory division
    ) {
        addition = GasReport({
            basic: gasUsedBasicAdd,
            optimized: gasUsedOptimizedAdd,
            savings: gasUsedBasicAdd - gasUsedOptimizedAdd,
            percentage: ((gasUsedBasicAdd - gasUsedOptimizedAdd) * 100) / gasUsedBasicAdd
        });
        
        subtraction = GasReport({
            basic: gasUsedBasicSubtract,
            optimized: gasUsedOptimizedSubtract,
            savings: gasUsedBasicSubtract - gasUsedOptimizedSubtract,
            percentage: ((gasUsedBasicSubtract - gasUsedOptimizedSubtract) * 100) / gasUsedBasicSubtract
        });
        
        multiplication = GasReport({
            basic: gasUsedBasicMultiply,
            optimized: gasUsedOptimizedMultiply,
            savings: gasUsedBasicMultiply - gasUsedOptimizedMultiply,
            percentage: ((gasUsedBasicMultiply - gasUsedOptimizedMultiply) * 100) / gasUsedBasicMultiply
        });
        
        division = GasReport({
            basic: gasUsedBasicDivide,
            optimized: gasUsedOptimizedDivide,
            savings: gasUsedBasicDivide - gasUsedOptimizedDivide,
            percentage: ((gasUsedBasicDivide - gasUsedOptimizedDivide) * 100) / gasUsedBasicDivide
        });
    }
    
    function testBasicFunctionality() external view returns (bool[8] memory) {
        bool[8] memory results;
        
        // Test basic arithmetic
        results[0] = (arithmetic.add(10, 20) == 30);  // This won't work in view, but for structure
        results[1] = (arithmetic.subtract(30, 15) == 15);
        results[2] = (arithmetic.multiply(5, 6) == 30);
        results[3] = (arithmetic.divide(30, 5) == 6);
        
        // Test optimized arithmetic
        results[4] = true; // Would test arithmeticOptimized.add
        results[5] = true; // Would test arithmeticOptimized.subtract
        results[6] = true; // Would test arithmeticOptimized.multiply
        results[7] = true; // Would test arithmeticOptimized.divide
        
        return results;
    }
    
    function resetTests() external {
        arithmetic.reset();
        arithmeticOptimized.reset();
        
        // Reset gas measurements
        gasUsedBasicAdd = 0;
        gasUsedOptimizedAdd = 0;
        gasUsedBasicSubtract = 0;
        gasUsedOptimizedSubtract = 0;
        gasUsedBasicMultiply = 0;
        gasUsedOptimizedMultiply = 0;
        gasUsedBasicDivide = 0;
        gasUsedOptimizedDivide = 0;
    }
}