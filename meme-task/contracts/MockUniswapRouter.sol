// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockUniswapRouter {
    address public WETH;
    
    constructor(address _weth) {
        WETH = _weth;
    }
    
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity) {
        // Mock实现 - 简单返回输入值
        return (amountTokenDesired, msg.value, amountTokenDesired);
    }
    
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH) {
        // Mock实现 - 返回流动性值
        return (liquidity, liquidity);
    }
    
    function getWETH() external view returns (address) {
        return WETH;
    }
}