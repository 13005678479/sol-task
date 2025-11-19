// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Arithmetic.sol";
import "../src/ArithmeticOptimized.sol";

contract ArithmeticTest is Test {
    
    Arithmetic public arithmetic;
    ArithmeticOptimized public arithmeticOptimized;
    
    // Gas tracking variables
    uint256 public gasUsedBasic;
    uint256 public gasUsedOptimized;
    
    event AdditionPerformed(uint256 a, uint256 b, uint256 result);
    event SubtractionPerformed(uint256 a, uint256 b, uint256 result);
    event MultiplicationPerformed(uint256 a, uint256 b, uint256 result);
    event DivisionPerformed(uint256 a, uint256 b, uint256 result);
    
    function setUp() public {
        arithmetic = new Arithmetic();
        arithmeticOptimized = new ArithmeticOptimized();
    }
    
    function testBasicArithmetic() public {
        // Test addition
        assertEq(arithmetic.add(10, 20), 30, "Addition should work");
        assertEq(arithmetic.getLastResult(), 30, "Last result should be 30");
        
        // Test subtraction
        assertEq(arithmetic.subtract(30, 15), 15, "Subtraction should work");
        assertEq(arithmetic.getLastResult(), 15, "Last result should be 15");
        
        // Test multiplication
        assertEq(arithmetic.multiply(5, 6), 30, "Multiplication should work");
        assertEq(arithmetic.getLastResult(), 30, "Last result should be 30");
        
        // Test division
        assertEq(arithmetic.divide(30, 5), 6, "Division should work");
        assertEq(arithmetic.getLastResult(), 6, "Last result should be 6");
    }
    
    function testOptimizedArithmetic() public {
        // Test addition
        assertEq(arithmeticOptimized.add(10, 20), 30, "Optimized addition should work");
        (uint256 lastResult, uint256 opCount) = arithmeticOptimized.getCompactData();
        assertEq(lastResult, 30, "Optimized last result should be 30");
        assertEq(opCount, 1, "Operation count should be 1");
        
        // Test subtraction
        assertEq(arithmeticOptimized.subtract(30, 15), 15, "Optimized subtraction should work");
        (lastResult, opCount) = arithmeticOptimized.getCompactData();
        assertEq(lastResult, 15, "Optimized last result should be 15");
        assertEq(opCount, 2, "Operation count should be 2");
        
        // Test multiplication
        assertEq(arithmeticOptimized.multiply(5, 6), 30, "Optimized multiplication should work");
        
        // Test division
        assertEq(arithmeticOptimized.divide(30, 5), 6, "Optimized division should work");
    }
    
    function testGasConsumption_Addition() public {
        // Test basic addition gas consumption
        uint256 startGas = gasleft();
        arithmetic.add(100, 200);
        gasUsedBasic = startGas - gasleft();
        
        // Test optimized addition gas consumption
        startGas = gasleft();
        arithmeticOptimized.add(100, 200);
        gasUsedOptimized = startGas - gasleft();
        
        console.log("Gas used for basic addition:", gasUsedBasic);
        console.log("Gas used for optimized addition:", gasUsedOptimized);
        console.log("Gas savings:", gasUsedBasic - gasUsedOptimized);
        
        assertTrue(gasUsedOptimized < gasUsedBasic, "Optimized should use less gas");
    }
    
    function testGasConsumption_Subtraction() public {
        // Test basic subtraction gas consumption
        uint256 startGas = gasleft();
        arithmetic.subtract(300, 150);
        gasUsedBasic = startGas - gasleft();
        
        // Test optimized subtraction gas consumption
        startGas = gasleft();
        arithmeticOptimized.subtract(300, 150);
        gasUsedOptimized = startGas - gasleft();
        
        console.log("Gas used for basic subtraction:", gasUsedBasic);
        console.log("Gas used for optimized subtraction:", gasUsedOptimized);
        console.log("Gas savings:", gasUsedBasic - gasUsedOptimized);
        
        assertTrue(gasUsedOptimized < gasUsedBasic, "Optimized should use less gas");
    }
    
    function testGasConsumption_Multiplication() public {
        // Test basic multiplication gas consumption
        uint256 startGas = gasleft();
        arithmetic.multiply(25, 4);
        gasUsedBasic = startGas - gasleft();
        
        // Test optimized multiplication gas consumption
        startGas = gasleft();
        arithmeticOptimized.multiply(25, 4);
        gasUsedOptimized = startGas - gasleft();
        
        console.log("Gas used for basic multiplication:", gasUsedBasic);
        console.log("Gas used for optimized multiplication:", gasUsedOptimized);
        console.log("Gas savings:", gasUsedBasic - gasUsedOptimized);
        
        assertTrue(gasUsedOptimized < gasUsedBasic, "Optimized should use less gas");
    }
    
    function testGasConsumption_Division() public {
        // Test basic division gas consumption
        uint256 startGas = gasleft();
        arithmetic.divide(100, 25);
        gasUsedBasic = startGas - gasleft();
        
        // Test optimized division gas consumption
        startGas = gasleft();
        arithmeticOptimized.divide(100, 25);
        gasUsedOptimized = startGas - gasleft();
        
        console.log("Gas used for basic division:", gasUsedBasic);
        console.log("Gas used for optimized division:", gasUsedOptimized);
        console.log("Gas savings:", gasUsedBasic - gasUsedOptimized);
        
        assertTrue(gasUsedOptimized < gasUsedBasic, "Optimized should use less gas");
    }
    
    function testBatchOperationsGas() public {
        // Prepare batch operations
        uint8[] memory operations = new uint8[](4);
        operations[0] = 1; // add
        operations[1] = 2; // subtract
        operations[2] = 3; // multiply
        operations[3] = 4; // divide
        
        uint256[2][] memory values = new uint256[2][](4);
        values[0] = [uint256(10), uint256(20)];
        values[1] = [uint256(50), uint256(25)];
        values[2] = [uint256(5), uint256(6)];
        values[3] = [uint256(30), uint256(5)];
        
        // Test basic batch operations
        uint256 startGas = gasleft();
        arithmetic.batchOperations(operations, values);
        gasUsedBasic = startGas - gasleft();
        
        // Test optimized batch operations
        startGas = gasleft();
        arithmeticOptimized.batchOperationsOptimized(operations, values);
        gasUsedOptimized = startGas - gasleft();
        
        console.log("Gas used for basic batch operations:", gasUsedBasic);
        console.log("Gas used for optimized batch operations:", gasUsedOptimized);
        console.log("Batch operations gas savings:", gasUsedBasic - gasUsedOptimized);
        
        assertTrue(gasUsedOptimized < gasUsedBasic, "Optimized batch should use less gas");
    }
    
    function testErrorHandling() public {
        // Test division by zero
        vm.expectRevert(Arithmetic.DivisionByZero.selector);
        arithmetic.divide(100, 0);
        
        vm.expectRevert(ArithmeticOptimized.DivisionByZero.selector);
        arithmeticOptimized.divide(100, 0);
        
        // Test underflow
        vm.expectRevert(Arithmetic.Underflow.selector);
        arithmetic.subtract(10, 20);
        
        vm.expectRevert(ArithmeticOptimized.Underflow.selector);
        arithmeticOptimized.subtract(10, 20);
    }
    
    function testEventEmission() public {
        // Test event emission for basic contract
        vm.expectEmit(true, true, true, true);
        emit AdditionPerformed(10, 20, 30);
        arithmetic.add(10, 20);
        
        vm.expectEmit(true, true, true, true);
        emit SubtractionPerformed(30, 15, 15);
        arithmetic.subtract(30, 15);
        
        vm.expectEmit(true, true, true, true);
        emit MultiplicationPerformed(5, 6, 30);
        arithmetic.multiply(5, 6);
        
        vm.expectEmit(true, true, true, true);
        emit DivisionPerformed(30, 5, 6);
        arithmetic.divide(30, 5);
    }
    
    function testOperationCount() public {
        assertEq(arithmetic.getOperationCount(), 0, "Initial count should be 0");
        
        arithmetic.add(1, 2);
        assertEq(arithmetic.getOperationCount(), 1, "Count should be 1 after 1 operation");
        
        arithmetic.subtract(5, 3);
        assertEq(arithmetic.getOperationCount(), 2, "Count should be 2 after 2 operations");
        
        arithmetic.multiply(2, 3);
        assertEq(arithmetic.getOperationCount(), 3, "Count should be 3 after 3 operations");
        
        arithmetic.divide(6, 2);
        assertEq(arithmetic.getOperationCount(), 4, "Count should be 4 after 4 operations");
        
        // Reset and verify
        arithmetic.reset();
        assertEq(arithmetic.getOperationCount(), 0, "Count should be 0 after reset");
        assertEq(arithmetic.getLastResult(), 0, "Last result should be 0 after reset");
    }
}