const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("集成测试 - MemeToken + LiquidityManager", function () {
  let memeToken, liquidityManager, mockRouter, mockPair, mockWETH;
  let owner, marketingWallet, liquidityWallet, devWallet, user1, user2, user3;
  let totalSupply = ethers.parseEther("1000000000");

  beforeEach(async function () {
    [owner, marketingWallet, liquidityWallet, devWallet, user1, user2, user3] = await ethers.getSigners();
    
    // 部署MockWETH
    const MockWETH = await ethers.getContractFactory("MockWETH");
    mockWETH = await MockWETH.deploy();
    await mockWETH.waitForDeployment();

    // 部署MockUniswapRouter
    const MockUniswapRouter = await ethers.getContractFactory("MockUniswapRouter");
    mockRouter = await MockUniswapRouter.deploy(mockWETH.getAddress());
    await mockRouter.waitForDeployment();

    // 部署MockPair
    const MockPair = await ethers.getContractFactory("MockPair");
    mockPair = await MockPair.deploy();
    await mockPair.waitForDeployment();

    // 部署MemeToken
    const MemeToken = await ethers.getContractFactory("MemeToken");
    memeToken = await MemeToken.deploy(
      "MemeShiba",
      "MEMESHI",
      1000000000,
      marketingWallet.address,
      liquidityWallet.address,
      devWallet.address
    );
    await memeToken.waitForDeployment();

    // 部署LiquidityManager
    const LiquidityManager = await ethers.getContractFactory("LiquidityManager");
    liquidityManager = await LiquidityManager.deploy(await memeToken.getAddress());
    await liquidityManager.waitForDeployment();

    // 设置配对地址
    await memeToken.setUniswapPair(await mockPair.getAddress());
    await liquidityManager.setLiquidityPair(await mockPair.getAddress());
    
    // 开启交易
    await memeToken.enableTrading();

    // 给Router和Pair一些代币用于模拟交易
    await memeToken.transfer(await mockPair.getAddress(), ethers.parseEther("10000000"));
    await memeToken.transfer(await mockRouter.getAddress(), ethers.parseEther("5000000"));

    // 给用户一些代币
    await memeToken.transfer(user1.address, ethers.parseEther("1000000"));
    await memeToken.transfer(user2.address, ethers.parseEther("1000000"));
    await memeToken.transfer(user3.address, ethers.parseEther("1000000"));
  });

  describe("完整交易流程", function () {
    it("应该正确处理买入交易", async function () {
      const buyAmount = ethers.parseEther("10000");
      const expectedTax = buyAmount * 200n / 10000n; // 2%税收
      const expectedReceive = buyAmount - expectedTax;
      
      const initialUserBalance = await memeToken.balanceOf(user1.address);
      const initialMarketingBalance = await memeToken.balanceOf(marketingWallet.address);
      
      // 模拟买入（从Pair到User）
      await memeToken.connect(mockPair).transfer(user1.address, buyAmount);
      
      const finalUserBalance = await memeToken.balanceOf(user1.address);
      const finalMarketingBalance = await memeToken.balanceOf(marketingWallet.address);
      
      expect(finalUserBalance - initialUserBalance).to.equal(expectedReceive);
      // 税收应该分配到各个钱包
      expect(finalMarketingBalance).to.be.gt(initialMarketingBalance);
    });

    it("应该正确处理卖出交易", async function () {
      const sellAmount = ethers.parseEther("5000");
      const expectedTax = sellAmount * 200n / 10000n; // 2%税收
      const expectedPairReceive = sellAmount - expectedTax;
      
      const initialUserBalance = await memeToken.balanceOf(user1.address);
      const initialPairBalance = await memeToken.balanceOf(mockPair.getAddress());
      
      // 模拟卖出（从User到Pair）
      await memeToken.connect(user1).transfer(await mockPair.getAddress(), sellAmount);
      
      const finalUserBalance = await memeToken.balanceOf(user1.address);
      const finalPairBalance = await memeToken.balanceOf(mockPair.getAddress());
      
      expect(initialUserBalance - finalUserBalance).to.equal(sellAmount);
      expect(finalPairBalance - initialPairBalance).to.equal(expectedPairReceive);
    });

    it("应该正确执行交易限制", async function () {
      const maxTx = await memeToken.maxTransactionAmount();
      const exceedAmount = maxTx + ethers.parseEther("1000");
      
      // 用户尝试超过最大交易限制应该失败
      await expect(
        memeToken.connect(user1).transfer(user2.address, exceedAmount)
      ).to.be.revertedWith("Transaction amount exceeds maximum limit");
    });

    it("免税地址应该能够无限制交易", async function () {
      const maxTx = await memeToken.maxTransactionAmount();
      const exceedAmount = maxTx + ethers.parseEther("10000");
      
      // 营销钱包是免税的，应该能够转移超过限制的金额
      await memeToken.transfer(marketingWallet.address, exceedAmount);
      await expect(
        memeToken.connect(marketingWallet).transfer(user2.address, exceedAmount)
      ).to.not.be.reverted;
    });
  });

  describe("税收分配机制", function () {
    it("应该正确分配税收到各个钱包", async function () {
      const taxAmount = ethers.parseEther("10000");
      
      const initialMarketingBalance = await memeToken.balanceOf(marketingWallet.address);
      const initialLiquidityBalance = await memeToken.balanceOf(liquidityWallet.address);
      const initialDevBalance = await memeToken.balanceOf(devWallet.address);
      
      // 手动分配税收进行测试
      await memeToken.transfer(await memeToken.getAddress(), taxAmount);
      await memeToken.manualDistributeTaxes();
      
      const finalMarketingBalance = await memeToken.balanceOf(marketingWallet.address);
      const finalLiquidityBalance = await memeToken.balanceOf(liquidityWallet.address);
      const finalDevBalance = await memeToken.balanceOf(devWallet.address);
      
      // 检查分配比例（40% marketing, 30% liquidity, 30% dev）
      expect(finalMarketingBalance - initialMarketingBalance).to.equal(taxAmount * 4000n / 10000n);
      expect(finalLiquidityBalance - initialLiquidityBalance).to.equal(taxAmount * 3000n / 10000n);
      expect(finalDevBalance - initialDevBalance).to.equal(taxAmount * 3000n / 10000n);
    });

    it("税收分配比例更新后应该正确工作", async function () {
      // 更新税收分配比例
      await memeToken.updateTaxShares(5000, 2500, 2500); // 50%, 25%, 25%
      
      const taxAmount = ethers.parseEther("10000");
      
      const initialMarketingBalance = await memeToken.balanceOf(marketingWallet.address);
      const initialLiquidityBalance = await memeToken.balanceOf(liquidityWallet.address);
      const initialDevBalance = await memeToken.balanceOf(devWallet.address);
      
      await memeToken.transfer(await memeToken.getAddress(), taxAmount);
      await memeToken.manualDistributeTaxes();
      
      const finalMarketingBalance = await memeToken.balanceOf(marketingWallet.address);
      const finalLiquidityBalance = await memeToken.balanceOf(liquidityWallet.address);
      const finalDevBalance = await memeToken.balanceOf(devWallet.address);
      
      // 检查新的分配比例
      expect(finalMarketingBalance - initialMarketingBalance).to.equal(taxAmount * 5000n / 10000n);
      expect(finalLiquidityBalance - initialLiquidityBalance).to.equal(taxAmount * 2500n / 10000n);
      expect(finalDevBalance - initialDevBalance).to.equal(taxAmount * 2500n / 10000n);
    });
  });

  describe("每日限制功能", function () {
    it("应该正确跟踪和重置每日卖出限制", async function () {
      const maxDailySell = await memeToken.maxDailySellAmount();
      const sellAmount = maxDailySell / 2n;
      
      // 第一次卖出
      await memeToken.connect(user1).transfer(await mockPair.getAddress(), sellAmount);
      expect(await memeToken.getCurrentDailySellAmount(user1.address)).to.equal(sellAmount);
      
      // 第二次卖出
      await memeToken.connect(user1).transfer(await mockPair.getAddress(), sellAmount);
      expect(await memeToken.getCurrentDailySellAmount(user1.address)).to.equal(sellAmount * 2n);
      
      // 前进24小时后应该重置
      await time.increase(24 * 60 * 60 + 1);
      expect(await memeToken.getCurrentDailySellAmount(user1.address)).to.equal(0);
    });

    it("应该正确跟踪和重置每日买入次数", async function () {
      const maxBuys = await memeToken.maxDailyBuys();
      
      // 模拟多次买入
      for (let i = 0; i < maxBuys; i++) {
        await memeToken.connect(mockPair).transfer(user1.address, ethers.parseEther("100"));
      }
      
      expect(await memeToken.getCurrentDailyBuys(user1.address)).to.equal(maxBuys);
      
      // 下一次买入应该失败
      await expect(
        memeToken.connect(mockPair).transfer(user1.address, ethers.parseEther("100"))
      ).to.be.revertedWith("Daily buy count exceeds maximum limit");
      
      // 24小时后应该重置
      await time.increase(24 * 60 * 60 + 1);
      expect(await memeToken.getCurrentDailyBuys(user1.address)).to.equal(0);
      
      // 现在应该能够再次买入
      await memeToken.connect(mockPair).transfer(user1.address, ethers.parseEther("100"));
      expect(await memeToken.getCurrentDailyBuys(user1.address)).to.equal(1);
    });
  });

  describe("流动性管理集成", function () {
    it("应该能够使用税收自动添加流动性", async function () {
      const taxAmount = ethers.parseEther("50000");
      const ethAmount = ethers.parseEther("10");
      
      // 给合约代币和ETH
      await memeToken.transfer(await liquidityManager.getAddress(), taxAmount);
      await owner.sendTransaction({
        to: await liquidityManager.getAddress(),
        value: ethAmount
      });
      
      const initialLiquidityProviderBalance = await mockPair.balanceOf(owner.address);
      
      // 自动添加流动性
      await liquidityManager.autoAddLiquidityFromTax(taxAmount, ethAmount);
      
      // 在真实环境中，这会增加LP代币余额
      expect(await liquidityManager.autoAddLiquidity()).to.be.true;
    });

    it("流动性管理器应该正确计算需要的代币数量", async function () {
      const ethAmount = ethers.parseEther("5");
      
      // 设置一些储备量
      await mockPair.setReserves(ethers.parseEther("100000"), ethers.parseEther("100"));
      
      const requiredTokens = await liquidityManager.calculateTokenAmountForLiquidity(ethAmount);
      expect(requiredTokens).to.equal(ethers.parseEther("50000")); // 5:100 比例
    });
  });

  describe("紧急场景", function () {
    it("应该能够紧急停止交易", async function () {
      await memeToken.emergencyStop();
      expect(await memeToken.tradingEnabled()).to.be.false;
      
      // 普通用户应该无法交易
      await expect(
        memeToken.connect(user1).transfer(user2.address, ethers.parseEther("100"))
      ).to.be.revertedWith("Trading is not enabled yet");
      
      // 但所有者应该仍然能够交易
      await expect(
        memeToken.transfer(user2.address, ethers.parseEther("100"))
      ).to.not.be.reverted;
    });

    it("应该能够紧急提取流动性", async function () {
      // 给LiquidityManager一些LP代币
      await mockPair.transfer(await liquidityManager.getAddress(), ethers.parseEther("1000"));
      
      const initialLPBalance = await mockPair.balanceOf(owner.address);
      
      // 紧急移除流动性
      await liquidityManager.emergencyRemoveAllLiquidity();
      
      // 在真实环境中，这会移除所有流动性并将代币返回给所有者
      expect(await mockPair.balanceOf(await liquidityManager.getAddress())).to.equal(0);
    });
  });

  describe("权限控制", function () {
    it("只有所有者能够执行管理功能", async function () {
      // 非所有者不能开启/关闭交易
      await expect(
        memeToken.connect(user1).enableTrading()
      ).to.be.revertedWithCustomError(memeToken, "OwnableUnauthorizedAccount");
      
      await expect(
        memeToken.connect(user1).emergencyStop()
      ).to.be.revertedWithCustomError(memeToken, "OwnableUnauthorizedAccount");
      
      // 非所有者不能更新税率
      await expect(
        memeToken.connect(user1).updateTaxRates(300, 300)
      ).to.be.revertedWithCustomError(memeToken, "OwnableUnauthorizedAccount");
      
      // 非所有者不能执行流动性管理操作
      await expect(
        liquidityManager.connect(user1).toggleAutoLiquidity()
      ).to.be.revertedWithCustomError(liquidityManager, "OwnableUnauthorizedAccount");
    });

    it("应该能够转移所有权", async function () {
      await memeToken.transferOwnership(user1.address);
      expect(await memeToken.owner()).to.equal(user1.address);
      
      // 新所有者应该能够执行管理功能
      await memeToken.connect(user1).emergencyStop();
      expect(await memeToken.tradingEnabled()).to.be.false;
    });
  });

  describe("边界条件测试", function () {
    it("应该正确处理零金额交易", async function () {
      await expect(
        memeToken.connect(user1).transfer(user2.address, 0)
      ).to.be.revertedWith("Transfer amount must be greater than zero");
    });

    it("应该正确处理最大金额交易", async function () {
      const userBalance = await memeToken.balanceOf(user1.address);
      const maxTransferAmount = userBalance;
      
      // 用户应该能够转移全部余额
      await expect(
        memeToken.connect(user1).transfer(user2.address, maxTransferAmount)
      ).to.not.be.reverted;
    });

    it("应该正确处理合约地址间的转账", async function () {
      const transferAmount = ethers.parseEther("10000");
      
      // 应该能够转账到合约地址
      await expect(
        memeToken.transfer(await liquidityManager.getAddress(), transferAmount)
      ).to.not.be.reverted;
    });
  });
});

// Mock合约源码（这些合约用于模拟Uniswap的功能）
const MockWETHSource = `
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockWETH is ERC20 {
    constructor() ERC20("Wrapped Ether", "WETH") {}
}
`;

const MockUniswapRouterSource = `
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
        // Mock实现
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
        // Mock实现
        return (liquidity, liquidity);
    }
}
`;

const MockPairSource = `
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
`;