// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title LiquidityManager
 * @dev 流动性池管理合约，用于管理Meme代币的流动性添加和移除
 * @author Your Name
 */
contract LiquidityManager is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // ========== 状态变量 ==========
    
    // Uniswap V2 Router地址
    address public constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    
    // WETH地址 (Sepolia测试网)
    address public constant WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    
    // 代币地址
    IERC20 public memeToken;
    IERC20 public weth;
    
    // 流动性池配对地址
    address public liquidityPair;
    
    // 最小流动性添加数量
    uint256 public minimumLiquidity;
    
    // 流动性提供者信息
    mapping(address => uint256) public liquidityProvided;
    
    // 自动添加流动性开关
    bool public autoAddLiquidity = true;
    
    // 税收用于自动添加流动性的比例
    uint256 public autoLiquifyShare = 5000; // 50%
    
    // 事件声明
    event LiquidityAdded(address indexed provider, uint256 tokenAmount, uint256 ethAmount, uint256 lpTokens);
    event LiquidityRemoved(address indexed provider, uint256 lpTokens, uint256 tokenAmount, uint256 ethAmount);
    event AutoLiquidityToggled(bool enabled);
    event MinimumLiquidityUpdated(uint256 newMinimum);
    event AutoLiquidityShareUpdated(uint256 newShare);
    
    // 修饰符
    modifier validPair() {
        require(liquidityPair != address(0), "Liquidity pair not set");
        _;
    }
    
    // ========== 构造函数 ==========
    
    constructor(address _memeToken) Ownable(msg.sender) {
        memeToken = IERC20(_memeToken);
        weth = IERC20(WETH);
        minimumLiquidity = 1000 * 10**18; // 1000 tokens minimum
    }
    
    // ========== 核心功能函数 ==========
    
    /**
     * @dev 设置流动性配对地址
     */
    function setLiquidityPair(address _pair) external onlyOwner {
        liquidityPair = _pair;
    }
    
    /**
     * @dev 手动添加流动性
     * @param tokenAmount 代币数量
     * @param ethAmount ETH数量
     * @param minTokenAmount 最小代币数量（滑点保护）
     * @param minEthAmount 最小ETH数量（滑点保护）
     */
    function addLiquidity(
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 minTokenAmount,
        uint256 minEthAmount
    ) external payable nonReentrant validPair {
        require(tokenAmount > 0 && ethAmount > 0, "Amounts must be greater than zero");
        require(msg.value == ethAmount, "ETH amount mismatch");
        require(tokenAmount >= minimumLiquidity, "Token amount below minimum");
        
        // 将代币转移到本合约
        memeToken.safeTransferFrom(msg.sender, address(this), tokenAmount);
        
        // 授权Router使用代币和ETH
        memeToken.approve(UNISWAP_V2_ROUTER, tokenAmount);
        weth.approve(UNISWAP_V2_ROUTER, ethAmount);
        
        // 添加流动性到Uniswap
        (uint amountToken, uint amountETH, uint liquidity) = IUniswapV2Router(UNISWAP_V2_ROUTER)
            .addLiquidityETH{value: ethAmount}(
                address(memeToken),
                tokenAmount,
                minTokenAmount,
                minEthAmount,
                msg.sender,
                block.timestamp + 300 // 5分钟超时
            );
        
        // 更新流动性提供者信息
        liquidityProvided[msg.sender] += liquidity;
        
        emit LiquidityAdded(msg.sender, amountToken, amountETH, liquidity);
        
        // 退还多余的ETH
        if (msg.value > ethAmount) {
            payable(msg.sender).transfer(msg.value - ethAmount);
        }
    }
    
    /**
     * @dev 移除流动性
     * @param liquidity LP代币数量
     * @param minTokenAmount 最小代币数量（滑点保护）
     * @param minEthAmount 最小ETH数量（滑点保护）
     */
    function removeLiquidity(
        uint256 liquidity,
        uint256 minTokenAmount,
        uint256 minEthAmount
    ) external nonReentrant validPair {
        require(liquidity > 0, "Liquidity must be greater than zero");
        require(liquidityProvided[msg.sender] >= liquidity, "Insufficient liquidity");
        
        // 将LP代币转移到本合约
        IERC20(liquidityPair).safeTransferFrom(msg.sender, address(this), liquidity);
        
        // 授权Router移除流动性
        IERC20(liquidityPair).approve(UNISWAP_V2_ROUTER, liquidity);
        
        // 移除流动性
        (uint amountToken, uint amountETH) = IUniswapV2Router(UNISWAP_V2_ROUTER)
            .removeLiquidityETH(
                address(memeToken),
                liquidity,
                minTokenAmount,
                minEthAmount,
                msg.sender,
                block.timestamp + 300 // 5分钟超时
            );
        
        // 更新流动性提供者信息
        liquidityProvided[msg.sender] -= liquidity;
        
        emit LiquidityRemoved(msg.sender, liquidity, amountToken, amountETH);
    }
    
    /**
     * @dev 自动添加流动性（使用税收）
     * @param tokenAmount 代币数量
     * @param ethAmount ETH数量
     */
    function autoAddLiquidityFromTax(
        uint256 tokenAmount,
        uint256 ethAmount
    ) external onlyOwner nonReentrant validPair {
        require(tokenAmount > 0 && ethAmount > 0, "Amounts must be greater than zero");
        require(autoAddLiquidity, "Auto liquidity is disabled");
        
        // 检查合约余额
        require(memeToken.balanceOf(address(this)) >= tokenAmount, "Insufficient token balance");
        require(address(this).balance >= ethAmount, "Insufficient ETH balance");
        
        // 授权Router
        memeToken.approve(UNISWAP_V2_ROUTER, tokenAmount);
        
        // 添加流动性，LP代币发送给合约所有者
        IUniswapV2Router(UNISWAP_V2_ROUTER)
            .addLiquidityETH{value: ethAmount}(
                address(memeToken),
                tokenAmount,
                0, // 不设置最小值，因为是自动添加
                0,
                owner(),
                block.timestamp + 300
            );
        
        emit LiquidityAdded(owner(), tokenAmount, ethAmount, 0);
    }
    
    /**
     * @dev 紧急移除所有流动性（仅限所有者）
     */
    function emergencyRemoveAllLiquidity() external onlyOwner nonReentrant validPair {
        uint256 liquidityBalance = IERC20(liquidityPair).balanceOf(address(this));
        
        if (liquidityBalance > 0) {
            // 授权Router
            IERC20(liquidityPair).approve(UNISWAP_V2_ROUTER, liquidityBalance);
            
            // 移除所有流动性
            (uint amountToken, uint amountETH) = IUniswapV2Router(UNISWAP_V2_ROUTER)
                .removeLiquidityETH(
                    address(memeToken),
                    liquidityBalance,
                    0, // 紧急情况不设置最小值
                    0,
                    owner(),
                    block.timestamp + 300
                );
            
            emit LiquidityRemoved(owner(), liquidityBalance, amountToken, amountETH);
        }
    }
    
    /**
     * @dev 获取流动性池的代币储备量
     */
    function getReserves() external view validPair returns (uint256 tokenReserve, uint256 ethReserve) {
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(liquidityPair).getReserves();
        address token0 = IUniswapV2Pair(liquidityPair).token0();
        
        if (token0 == address(memeToken)) {
            return (reserve0, reserve1);
        } else {
            return (reserve1, reserve0);
        }
    }
    
    /**
     * @dev 计算添加流动性需要的代币数量
     */
    function calculateTokenAmountForLiquidity(uint256 ethAmount) external view validPair returns (uint256) {
        (uint tokenReserve, uint ethReserve) = this.getReserves();
        
        if (ethReserve == 0) {
            return ethAmount; // 如果池为空，按1:1比例
        }
        
        return (ethAmount * tokenReserve) / ethReserve;
    }
    
    /**
     * @dev 计算移除流动性可获得的代币数量
     */
    function calculateTokenAmountFromLiquidity(uint256 liquidityAmount) external view validPair returns (uint256 tokenAmount, uint256 ethAmount) {
        uint256 totalSupply = IERC20(liquidityPair).totalSupply();
        (uint tokenReserve, uint ethReserve) = this.getReserves();
        
        if (totalSupply == 0) {
            return (0, 0);
        }
        
        tokenAmount = (liquidityAmount * tokenReserve) / totalSupply;
        ethAmount = (liquidityAmount * ethReserve) / totalSupply;
    }
    
    /**
     * @dev 获取用户的LP代币余额
     */
    function getUserLiquidityBalance(address user) external view validPair returns (uint256) {
        return IERC20(liquidityPair).balanceOf(user);
    }
    
    /**
     * @dev 获取流动性池的总供应量
     */
    function getTotalLiquiditySupply() external view validPair returns (uint256) {
        return IERC20(liquidityPair).totalSupply();
    }
    
    // ========== 管理员功能 ==========
    
    /**
     * @dev 切换自动添加流动性功能
     */
    function toggleAutoLiquidity() external onlyOwner {
        autoAddLiquidity = !autoAddLiquidity;
        emit AutoLiquidityToggled(autoAddLiquidity);
    }
    
    /**
     * @dev 更新最小流动性数量
     */
    function updateMinimumLiquidity(uint256 _minimumLiquidity) external onlyOwner {
        minimumLiquidity = _minimumLiquidity;
        emit MinimumLiquidityUpdated(_minimumLiquidity);
    }
    
    /**
     * @dev 更新自动流动性的税收份额
     */
    function updateAutoLiquidityShare(uint256 _share) external onlyOwner {
        require(_share <= 10000, "Share cannot exceed 100%");
        autoLiquifyShare = _share;
        emit AutoLiquidityShareUpdated(_share);
    }
    
    /**
     * @dev 紧急提取代币
     */
    function emergencyWithdrawToken(address _tokenAddress, uint256 amount) external onlyOwner {
        if (_tokenAddress == address(memeToken)) {
            uint256 balance = memeToken.balanceOf(address(this));
            require(amount <= balance, "Amount exceeds balance");
            memeToken.safeTransfer(owner(), amount);
        } else {
            IERC20 token = IERC20(_tokenAddress);
            uint256 balance = token.balanceOf(address(this));
            require(amount <= balance, "Amount exceeds balance");
            token.safeTransfer(owner(), amount);
        }
    }
    
    /**
     * @dev 紧急提取ETH
     */
    function emergencyWithdrawETH(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Amount exceeds balance");
        payable(owner()).transfer(amount);
    }
    
    // ========== 接收以太币功能 ==========
    
    receive() external payable {}
    
    fallback() external payable {}
}

// ========== 接口定义 =========

interface IUniswapV2Router {
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    
    function WETH() external pure returns (address);
}

interface IUniswapV2Pair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
}