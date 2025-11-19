// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract LiquidityPool is ERC20, Ownable {
    IERC20 public token0;
    IERC20 public token1;
    
    uint256 public reserve0;
    uint256 public reserve1;
    
    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out
    );
    
    event AddLiquidity(
        address indexed provider,
        uint256 amount0,
        uint256 amount1
    );
    
    event RemoveLiquidity(
        address indexed provider,
        uint256 amount0,
        uint256 amount1
    );
    
    constructor(
        address _token0,
        address _token1
    ) ERC20("Liquidity Pool Token", "LPT") {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }
    
    function addLiquidity(uint256 amount0, uint256 amount1) external {
        require(amount0 > 0 && amount1 > 0, "Insufficient liquidity amount");
        
        if (reserve0 == 0 && reserve1 == 0) {
            _mint(msg.sender, amount0 * amount1 - MINIMUM_LIQUIDITY);
        } else {
            uint256 liquidity = Math.min(
                (amount0 * totalSupply()) / reserve0,
                (amount1 * totalSupply()) / reserve1
            );
            require(liquidity > 0, "Insufficient liquidity minted");
            _mint(msg.sender, liquidity);
        }
        
        token0.transferFrom(msg.sender, address(this), amount0);
        token1.transferFrom(msg.sender, address(this), amount1);
        
        reserve0 += amount0;
        reserve1 += amount1;
        
        emit AddLiquidity(msg.sender, amount0, amount1);
    }
    
    function removeLiquidity(uint256 liquidity) external {
        require(liquidity > 0, "Insufficient liquidity to remove");
        
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));
        
        uint256 amount0 = (liquidity * balance0) / totalSupply();
        uint256 amount1 = (liquidity * balance1) / totalSupply();
        
        require(amount0 > 0 && amount1 > 0, "Insufficient liquidity removed");
        
        _burn(msg.sender, liquidity);
        
        reserve0 = balance0 - amount0;
        reserve1 = balance1 - amount1;
        
        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);
        
        emit RemoveLiquidity(msg.sender, amount0, amount1);
    }
    
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to
    ) external {
        require(path.length >= 2, "Invalid path");
        require(amountIn > 0, "Insufficient input amount");
        
        address[] memory pairs = getPairs(path);
        
        uint256[] memory amounts = getAmountsOut(amountIn, path);
        
        require(amounts[amounts.length - 1] >= amountOutMin, "Insufficient output amount");
        
        _swap(amounts, path, to);
        
        emit Swap(
            msg.sender,
            path[0] == address(token0) ? amounts[0] : 0,
            path[0] == address(token1) ? amounts[0] : 0,
            path[path.length - 1] == address(token0) ? amounts[amounts.length - 1] : 0,
            path[path.length - 1] == address(token1) ? amounts[amounts.length - 1] : 0
        );
    }
    
    function getAmountsOut(uint256 amountIn, address[] memory path) public view returns (uint256[] memory amounts) {
        require(path.length >= 2, "Invalid path");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        
        for (uint256 i; i < path.length - 1; i++) {
            (uint256 reserveIn, uint256 reserveOut) = getReserves(path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }
    
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");
        
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        
        amountOut = numerator / denominator;
    }
    
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0_, ) = sortTokens(input, output);
            uint256 amount0 = amounts[i] * (input == token0_ ? 1 : 0);
            uint256 amount1 = amounts[i] * (input != token0_ ? 1 : 0);
            
            if (input == address(this)) {
                IERC20(token0_).transfer(_to, amount0);
                IERC20(token1_).transfer(_to, amount1);
            } else {
                IERC20(input).transferFrom(msg.sender, address(this), amounts[i]);
            }
        }
    }
    
    function getReserves(address tokenA, address tokenB) public view returns (uint256 reserveA, uint256 reserveB) {
        if (tokenA == address(token0) && tokenB == address(token1)) {
            return (reserve0, reserve1);
        }
        if (tokenA == address(token1) && tokenB == address(token0)) {
            return (reserve1, reserve0);
        }
        revert("Invalid pair");
    }
    
    function getPairs(address[] memory path) internal pure returns (address[] memory) {
        address[] memory pairs = new address[](path.length - 1);
        for (uint256 i = 0; i < path.length - 1; i++) {
            pairs[i] = address(this);
        }
        return pairs;
    }
    
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0_, address token1_) {
        require(tokenA != tokenB, "Identical addresses");
        (token0_, token1_) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0_ != address(0), "Zero address");
    }
    
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) external pure returns (uint256 amountB) {
        require(amountA > 0, "Insufficient amount");
        require(reserveA > 0 && reserveB > 0, "Insufficient liquidity");
        amountB = (amountA * reserveB) / reserveA;
    }
    
    function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }
}