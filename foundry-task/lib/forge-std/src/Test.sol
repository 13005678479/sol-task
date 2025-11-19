// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Test
 * @dev Simplified Test contract for Foundry-like testing
 */
contract Test {
    uint256 private constant TEST_CHAIN_ID = 31337; // Anvil's default chain id
    
    struct Log {
        address sender;
        uint256 value;
        bytes data;
    }
    
    Log[] private logs;
    
    modifier prank(address caller) {
        vm.prank(caller);
        _;
    }
    
    Vm public constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    
    function assertTrue(bool condition, string memory err) internal {
        if (!condition) {
            revert(err);
        }
    }
    
    function assertEq(uint256 a, uint256 b, string memory err) internal {
        if (a != b) {
            revert(err);
        }
    }
    
    function expectRevert(bytes calldata expectedError) internal {
        vm.expectRevert(expectedError);
    }
    
    function expectEmit(bool check1, bool check2, bool check3, bool check4) internal {
        vm.expectEmit(check1, check2, check3, check4);
    }
    
    function gasleft() internal view returns (uint256) {
        return gasleft();
    }
}

/**
 * @title Vm
 * @dev Simplified Vm contract for testing
 */
contract Vm {
    function prank(address) external {}
    function expectRevert(bytes calldata) external {}
    function expectEmit(bool, bool, bool, bool) external {}
}