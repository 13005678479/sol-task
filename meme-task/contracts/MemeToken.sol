// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title MemeToken
 * @dev SHIB风格的Meme代币合约，包含代币税、交易限制和流动性池集成功能
 * @author Your Name
 */
contract MemeToken is ERC20, Ownable {
    using SafeERC20 for IERC20;
    
    // ========== 状态变量 ==========
    
    // 税收相关
    uint256 public constant TAX_DENOMINATOR = 10000; // 税率分母，精度为4位小数
    uint256 public buyTaxRate = 200; // 买入税率 2% (200/10000)
    uint256 public sellTaxRate = 200; // 卖出税率 2% (200/10000)
    
    // 税收接收地址
    address public marketingWallet;
    address public liquidityWallet;
    address public devWallet;
    
    // 税收分配比例
    uint256 public marketingShare = 4000; // 40%
    uint256 public liquidityShare = 3000; // 30%
    uint256 public devShare = 3000;      // 30%
    
    // 交易限制相关
    uint256 public maxTransactionAmount; // 单笔交易最大限制
    uint256 public maxWalletBalance;     // 钱包最大持有量限制
    uint256 public maxDailySellAmount;   // 每日最大卖出量
    uint256 public maxDailyBuys;         // 每日最大买入次数
    
    // 跟踪用户交易数据
    mapping(address => uint256) public dailySellAmount;
    mapping(address => uint256) public dailyBuys;
    mapping(address => uint256) public lastSellResetTime;
    mapping(address => uint256) public lastBuyResetTime;
    
    // 免税地址
    mapping(address => bool) public isExcludedFromTax;
    mapping(address => bool) public isExcludedFromLimit;
    
    // 流动性池相关
    address public uniswapV2Pair;
    address public constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    
    // 交易状态控制
    bool public tradingEnabled = false;
    bool private inSwapAndLiquify;
    
    // 事件声明
    event TaxUpdated(uint256 newBuyTax, uint256 newSellTax);
    event TaxWalletsUpdated(address marketing, address liquidity, address dev);
    event TransactionLimitsUpdated(uint256 maxTx, uint256 maxWallet, uint256 maxDailySell, uint256 maxDailyBuys);
    event TradingStatusChanged(bool enabled);
    event TaxesDistributed(uint256 marketingAmount, uint256 liquidityAmount, uint256 devAmount);
    
    // 修饰符
    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }
    
    // ========== 构造函数 ==========
    
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _totalSupply,
        address _marketingWallet,
        address _liquidityWallet,
        address _devWallet
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        // 铸造总供应量给部署者
        _mint(msg.sender, _totalSupply * 10**decimals());
        
        // 设置钱包地址
        marketingWallet = _marketingWallet;
        liquidityWallet = _liquidityWallet;
        devWallet = _devWallet;
        
        // 设置初始交易限制
        maxTransactionAmount = _totalSupply * 10**decimals() / 100; // 1%
        maxWalletBalance = _totalSupply * 10**decimals() / 50;      // 2%
        maxDailySellAmount = _totalSupply * 10**decimals() / 100;   // 1%
        maxDailyBuys = 10; // 每日最多10次买入
        
        // 设置免税地址
        isExcludedFromTax[msg.sender] = true;
        isExcludedFromTax[address(this)] = true;
        isExcludedFromTax[marketingWallet] = true;
        isExcludedFromTax[liquidityWallet] = true;
        isExcludedFromTax[devWallet] = true;
        
        // 设置免限制地址
        isExcludedFromLimit[msg.sender] = true;
        isExcludedFromLimit[address(this)] = true;
        isExcludedFromLimit[marketingWallet] = true;
        isExcludedFromLimit[liquidityWallet] = true;
        isExcludedFromLimit[devWallet] = true;
        isExcludedFromLimit[UNISWAP_V2_ROUTER] = true;
    }
    
    // ========== 核心功能函数 ==========
    
    /**
     * @dev 开启交易功能
     */
    function enableTrading() external onlyOwner {
        tradingEnabled = true;
        emit TradingStatusChanged(true);
    }
    
    /**
     * @dev 关闭交易功能（紧急情况下使用）
     */
    function emergencyStop() external onlyOwner {
        tradingEnabled = false;
        emit TradingStatusChanged(false);
    }
    
    /**
     * @dev 设置Uniswap V2配对地址
     */
    function setUniswapPair(address _pair) external onlyOwner {
        uniswapV2Pair = _pair;
        isExcludedFromLimit[_pair] = true;
    }
    
    /**
     * @dev 转账函数的重写，包含税收和交易限制逻辑
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        _transferLogic(msg.sender, to, amount);
        return true;
    }
    
    /**
     * @dev 从from地址转账amount数量代币到to地址
     */
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transferLogic(from, to, amount);
        return true;
    }
    
    /**
     * @dev 内部转账函数，实现税收和限制逻辑
     */
    function _transferLogic(address from, address to, uint256 amount) internal {
        // 基本检查
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        
        // 检查交易是否开启
        if (!tradingEnabled && !isExcludedFromTax[from]) {
            require(from == owner() || to == owner(), "Trading is not enabled yet");
        }
        
        // 检查交易限制
        if (!isExcludedFromLimit[from] && !isExcludedFromLimit[to]) {
            _checkTransactionLimits(from, to, amount);
        }
        
        // 检查是否为购买或出售交易
        bool isSell = _isSellTransaction(from, to);
        bool isBuy = _isBuyTransaction(from, to);
        
        // 重置每日限制（如果需要）
        if (isSell) {
            _resetDailySellLimit(from);
        } else if (isBuy) {
            _resetDailyBuyLimit(to);
        }
        
        // 计算税收
        uint256 taxAmount = 0;
        if (!isExcludedFromTax[from] && !isExcludedFromTax[to] && (isSell || isBuy)) {
            taxAmount = _calculateTax(amount, isSell);
            
            if (taxAmount > 0 && !inSwapAndLiquify) {
                _handleTaxTransfer(from, amount, taxAmount);
                _afterTaxTransfer(from, to, amount - taxAmount);
                return;
            }
        }
        
        // 执行标准转账
        _superTransfer(from, to, amount);
    }
    
    /**
     * @dev 检查交易限制
     */
    function _checkTransactionLimits(address from, address to, uint256 amount) internal {
        // 检查单笔交易限制
        if (amount > maxTransactionAmount) {
            revert("Transaction amount exceeds maximum limit");
        }
        
        // 检查钱包余额限制（接收方）
        uint256 newBalance = balanceOf(to) + amount;
        if (newBalance > maxWalletBalance) {
            revert("Wallet balance exceeds maximum limit");
        }
        
        // 检查每日卖出限制
        if (_isSellTransaction(from, to)) {
            uint256 daySellAmount = dailySellAmount[from] + amount;
            if (daySellAmount > maxDailySellAmount) {
                revert("Daily sell amount exceeds maximum limit");
            }
            dailySellAmount[from] = daySellAmount;
        }
        
        // 检查每日买入次数限制
        if (_isBuyTransaction(from, to)) {
            uint256 dayBuys = dailyBuys[to] + 1;
            if (dayBuys > maxDailyBuys) {
                revert("Daily buy count exceeds maximum limit");
            }
            dailyBuys[to] = dayBuys;
        }
    }
    
    /**
     * @dev 重置每日卖出限制
     */
    function _resetDailySellLimit(address account) internal {
        if (block.timestamp >= lastSellResetTime[account] + 24 hours) {
            dailySellAmount[account] = 0;
            lastSellResetTime[account] = block.timestamp;
        }
    }
    
    /**
     * @dev 重置每日买入限制
     */
    function _resetDailyBuyLimit(address account) internal {
        if (block.timestamp >= lastBuyResetTime[account] + 24 hours) {
            dailyBuys[account] = 0;
            lastBuyResetTime[account] = block.timestamp;
        }
    }
    
    /**
     * @dev 判断是否为卖出交易
     */
    function _isSellTransaction(address from, address to) internal view returns (bool) {
        return from != owner() && to == uniswapV2Pair;
    }
    
    /**
     * @dev 判断是否为买入交易
     */
    function _isBuyTransaction(address from, address to) internal view returns (bool) {
        return from == uniswapV2Pair && to != owner();
    }
    
    /**
     * @dev 计算税收
     */
    function _calculateTax(uint256 amount, bool isSell) internal view returns (uint256) {
        uint256 taxRate = isSell ? sellTaxRate : buyTaxRate;
        return (amount * taxRate) / TAX_DENOMINATOR;
    }
    
    /**
     * @dev 处理税收转账
     */
    function _handleTaxTransfer(address from, uint256 amount, uint256 taxAmount) internal lockTheSwap {
        uint256 remainingAmount = amount - taxAmount;
        
        // 先执行正常转账部分
        _superTransfer(from, address(this), remainingAmount);
        
        // 分配税收
        _distributeTaxes(taxAmount);
    }
    
    /**
     * @dev 税收后转账
     */
    function _afterTaxTransfer(address /*from*/, address to, uint256 amount) internal {
        _superTransfer(address(this), to, amount);
    }
    
    /**
     * @dev 执行标准转账（无税）
     */
    function _superTransfer(address from, address to, uint256 amount) internal {
        super._update(from, to, amount);
    }
    
    /**
     * @dev 分配税收到各个钱包
     */
    function _distributeTaxes(uint256 totalTax) internal {
        uint256 marketingAmount = (totalTax * marketingShare) / 10000;
        uint256 liquidityAmount = (totalTax * liquidityShare) / 10000;
        uint256 devAmount = totalTax - marketingAmount - liquidityAmount;
        
        if (marketingAmount > 0) {
            _superTransfer(address(this), marketingWallet, marketingAmount);
        }
        
        if (liquidityAmount > 0) {
            _superTransfer(address(this), liquidityWallet, liquidityAmount);
        }
        
        if (devAmount > 0) {
            _superTransfer(address(this), devWallet, devAmount);
        }
        
        emit TaxesDistributed(marketingAmount, liquidityAmount, devAmount);
    }
    
    // ========== 管理员功能 ==========
    
    /**
     * @dev 更新税率
     */
    function updateTaxRates(uint256 _buyTaxRate, uint256 _sellTaxRate) external onlyOwner {
        require(_buyTaxRate <= 1000, "Buy tax rate cannot exceed 10%");
        require(_sellTaxRate <= 1000, "Sell tax rate cannot exceed 10%");
        
        buyTaxRate = _buyTaxRate;
        sellTaxRate = _sellTaxRate;
        
        emit TaxUpdated(_buyTaxRate, _sellTaxRate);
    }
    
    /**
     * @dev 更新税收钱包地址
     */
    function updateTaxWallets(
        address _marketingWallet,
        address _liquidityWallet,
        address _devWallet
    ) external onlyOwner {
        require(_marketingWallet != address(0), "Marketing wallet cannot be zero address");
        require(_liquidityWallet != address(0), "Liquidity wallet cannot be zero address");
        require(_devWallet != address(0), "Dev wallet cannot be zero address");
        
        marketingWallet = _marketingWallet;
        liquidityWallet = _liquidityWallet;
        devWallet = _devWallet;
        
        emit TaxWalletsUpdated(_marketingWallet, _liquidityWallet, _devWallet);
    }
    
    /**
     * @dev 更新税收分配比例
     */
    function updateTaxShares(
        uint256 _marketingShare,
        uint256 _liquidityShare,
        uint256 _devShare
    ) external onlyOwner {
        require(_marketingShare + _liquidityShare + _devShare == 10000, "Total share must be 100%");
        
        marketingShare = _marketingShare;
        liquidityShare = _liquidityShare;
        devShare = _devShare;
    }
    
    /**
     * @dev 更新交易限制
     */
    function updateTransactionLimits(
        uint256 _maxTransactionAmount,
        uint256 _maxWalletBalance,
        uint256 _maxDailySellAmount,
        uint256 _maxDailyBuys
    ) external onlyOwner {
        maxTransactionAmount = _maxTransactionAmount;
        maxWalletBalance = _maxWalletBalance;
        maxDailySellAmount = _maxDailySellAmount;
        maxDailyBuys = _maxDailyBuys;
        
        emit TransactionLimitsUpdated(_maxTransactionAmount, _maxWalletBalance, _maxDailySellAmount, _maxDailyBuys);
    }
    
    /**
     * @dev 设置免税地址
     */
    function setExcludedFromTax(address account, bool excluded) external onlyOwner {
        isExcludedFromTax[account] = excluded;
    }
    
    /**
     * @dev 设置免限制地址
     */
    function setExcludedFromLimit(address account, bool excluded) external onlyOwner {
        isExcludedFromLimit[account] = excluded;
    }
    
    /**
     * @dev 紧急提取代币
     */
    function emergencyWithdrawToken(address tokenAddress, uint256 amount) external onlyOwner {
        require(tokenAddress != address(this), "Cannot withdraw native token");
        IERC20(tokenAddress).safeTransfer(owner(), amount);
    }
    
    /**
     * @dev 获取指定用户的当前每日卖出量
     */
    function getCurrentDailySellAmount(address account) external view returns (uint256) {
        if (block.timestamp >= lastSellResetTime[account] + 24 hours) {
            return 0;
        }
        return dailySellAmount[account];
    }
    
    /**
     * @dev 获取指定用户的当前每日买入次数
     */
    function getCurrentDailyBuys(address account) external view returns (uint256) {
        if (block.timestamp >= lastBuyResetTime[account] + 24 hours) {
            return 0;
        }
        return dailyBuys[account];
    }
    
    /**
     * @dev 手动分配税收（如果自动分配失败）
     */
    function manualDistributeTaxes() external onlyOwner {
        uint256 contractBalance = balanceOf(address(this));
        if (contractBalance > 0) {
            _distributeTaxes(contractBalance);
        }
    }
    
    // ========== 接收以太币功能（如果需要） ==========
    
    receive() external payable {}
    
    fallback() external payable {}
}