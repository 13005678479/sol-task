// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockPair is ERC20 {
    address public token0;
    address public token1;
    uint112 public reserve0;
    uint112 public reserve1;
    
    constructor() ERC20("LP Token", "LP") {}
    
    function setReserves(uint _reserve0, uint _reserve1) external {
        reserve0 = uint112(_reserve0);
        reserve1 = uint112(_reserve1);
    }
    
    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        return (reserve0, reserve1, uint32(block.timestamp));
    }
    
    function setTokens(address _token0, address _token1) external {
        token0 = _token0;
        token1 = _token1;
    }
}