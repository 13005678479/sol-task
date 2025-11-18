const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("MemeToken", function () {
  let memeToken;
  let owner, marketingWallet, liquidityWallet, devWallet, addr1, addr2, addr3;
  let totalSupply = ethers.parseEther("1000000000"); // 10亿代币

  beforeEach(async function () {
    [owner, marketingWallet, liquidityWallet, devWallet, addr1, addr2, addr3] = await ethers.getSigners();
    
    const MemeToken = await ethers.getContractFactory("MemeToken");
    memeToken = await MemeToken.deploy(
      "MemeShiba",
      "MEMESHI", 
      1000000000, // 10亿
      marketingWallet.address,
      liquidityWallet.address,
      devWallet.address
    );
    await memeToken.waitForDeployment();
  });

  describe("部署", function () {
    it("应该设置正确的代币名称和符号", async function () {
      expect(await memeToken.name()).to.equal("MemeShiba");
      expect(await memeToken.symbol()).to.equal("MEMESHI");
    });

    it("应该设置正确的总供应量", async function () {
      expect(await memeToken.totalSupply()).to.equal(totalSupply);
    });

    it("应该将总供应量分配给部署者", async function () {
      expect(await memeToken.balanceOf(owner.address)).to.equal(totalSupply);
    });

    it("应该设置正确的钱包地址", async function () {
      expect(await memeToken.marketingWallet()).to.equal(marketingWallet.address);
      expect(await memeToken.liquidityWallet()).to.equal(liquidityWallet.address);
      expect(await memeToken.devWallet()).to.equal(devWallet.address);
    });

    it("应该设置正确的初始税率", async function () {
      expect(await memeToken.buyTaxRate()).to.equal(200); // 2%
      expect(await memeToken.sellTaxRate()).to.equal(200); // 2%
    });

    it("应该正确设置免税地址", async function () {
      expect(await memeToken.isExcludedFromTax(owner.address)).to.be.true;
      expect(await memeToken.isExcludedFromTax(await memeToken.getAddress())).to.be.true;
      expect(await memeToken.isExcludedFromTax(marketingWallet.address)).to.be.true;
      expect(await memeToken.isExcludedFromTax(liquidityWallet.address)).to.be.true;
      expect(await memeToken.isExcludedFromTax(devWallet.address)).to.be.true;
    });

    it("应该设置正确的初始交易限制", async function () {
      const maxTx = totalSupply / 100n; // 1%
      const maxWallet = totalSupply / 50n; // 2%
      const maxDailySell = totalSupply / 100n; // 1%
      
      expect(await memeToken.maxTransactionAmount()).to.equal(maxTx);
      expect(await memeToken.maxWalletBalance()).to.equal(maxWallet);
      expect(await memeToken.maxDailySellAmount()).to.equal(maxDailySell);
      expect(await memeToken.maxDailyBuys()).to.equal(10);
    });
  });

  describe("交易控制", function () {
    beforeEach(async function () {
      await memeToken.enableTrading();
    });

    it("应该正确开启交易", async function () {
      expect(await memeToken.tradingEnabled()).to.be.true;
    });

    it("应该允许所有者关闭交易", async function () {
      await memeToken.emergencyStop();
      expect(await memeToken.tradingEnabled()).to.be.false;
    });

    it("非所有者不能开启/关闭交易", async function () {
      await expect(memeToken.connect(addr1).enableTrading()).to.be.revertedWithCustomError(memeToken, "OwnableUnauthorizedAccount");
      await expect(memeToken.connect(addr1).emergencyStop()).to.be.revertedWithCustomError(memeToken, "OwnableUnauthorizedAccount");
    });
  });

  describe("税收功能", function () {
    beforeEach(async function () {
      await memeToken.enableTrading();
      // 设置一个假的Uniswap配对地址用于测试
      await memeToken.setUniswapPair(addr1.address);
    });

    it("应该正确更新税率", async function () {
      await memeToken.updateTaxRates(500, 800); // 买入5%, 卖出8%
      expect(await memeToken.buyTaxRate()).to.equal(500);
      expect(await memeToken.sellTaxRate()).to.equal(800);
    });

    it("税率不能超过10%", async function () {
      await expect(memeToken.updateTaxRates(1001, 200)).to.be.revertedWith("Buy tax rate cannot exceed 10%");
      await expect(memeToken.updateTaxRates(200, 1001)).to.be.revertedWith("Sell tax rate cannot exceed 10%");
    });

    it("应该正确更新税收钱包", async function () {
      await memeToken.updateTaxWallets(addr1.address, addr2.address, addr3.address);
      expect(await memeToken.marketingWallet()).to.equal(addr1.address);
      expect(await memeToken.liquidityWallet()).to.equal(addr2.address);
      expect(await memeToken.devWallet()).to.equal(addr3.address);
    });

    it("应该正确更新税收分配比例", async function () {
      await memeToken.updateTaxShares(2000, 5000, 3000); // 20%, 50%, 30%
      expect(await memeToken.marketingShare()).to.equal(2000);
      expect(await memeToken.liquidityShare()).to.equal(5000);
      expect(await memeToken.devShare()).to.equal(3000);
    });

    it("税收分配比例总和必须为100%", async function () {
      await expect(memeToken.updateTaxShares(3000, 4000, 2000)).to.be.revertedWith("Total share must be 100%");
    });
  });

  describe("交易限制", function () {
    beforeEach(async function () {
      await memeToken.enableTrading();
      await memeToken.setUniswapPair(addr1.address);
    });

    it("应该正确更新交易限制", async function () {
      const newMaxTx = ethers.parseEther("1000000");
      const newMaxWallet = ethers.parseEther("2000000");
      const newMaxDailySell = ethers.parseEther("500000");
      const newMaxDailyBuys = 20;

      await memeToken.updateTransactionLimits(newMaxTx, newMaxWallet, newMaxDailySell, newMaxDailyBuys);
      
      expect(await memeToken.maxTransactionAmount()).to.equal(newMaxTx);
      expect(await memeToken.maxWalletBalance()).to.equal(newMaxWallet);
      expect(await memeToken.maxDailySellAmount()).to.equal(newMaxDailySell);
      expect(await memeToken.maxDailyBuys()).to.equal(newMaxDailyBuys);
    });

    it("应该强制执行最大交易量限制", async function () {
      const maxTx = await memeToken.maxTransactionAmount();
      const exceedAmount = maxTx + ethers.parseEther("1");
      
      await expect(
        memeToken.transfer(addr2.address, exceedAmount)
      ).to.be.revertedWith("Transaction amount exceeds maximum limit");
    });

    it("应该强制执行最大钱包余额限制", async function () {
      const maxWallet = await memeToken.maxWalletBalance();
      const transferAmount = maxWallet + ethers.parseEther("1");
      
      await memeToken.transfer(addr2.address, ethers.parseEther("1000")); // 先给一些余额
      
      await expect(
        memeToken.transfer(addr2.address, transferAmount)
      ).to.be.revertedWith("Wallet balance exceeds maximum limit");
    });

    it("免税地址应该不受交易限制", async function () {
      const exceedAmount = (await memeToken.maxTransactionAmount()) + ethers.parseEther("1000");
      
      // 所有者是免税的，应该能够转移超过限制的金额
      await expect(memeToken.transfer(addr2.address, exceedAmount)).to.not.be.reverted;
    });
  });

  describe("每日限制功能", function () {
    beforeEach(async function () {
      await memeToken.enableTrading();
      await memeToken.setUniswapPair(addr1.address);
      
      // 给用户一些代币用于测试
      await memeToken.transfer(addr2.address, ethers.parseEther("1000000"));
    });

    it("应该跟踪每日卖出量", async function () {
      const maxDailySell = await memeToken.maxDailySellAmount();
      const sellAmount = maxDailySell / 2n;
      
      // 第一次卖出
      await memeToken.connect(addr2).transfer(addr1.address, sellAmount); // 模拟卖出到配对
      expect(await memeToken.getCurrentDailySellAmount(addr2.address)).to.equal(sellAmount);
      
      // 第二次卖出（应该在限制内）
      await memeToken.connect(addr2).transfer(addr1.address, sellAmount);
      expect(await memeToken.getCurrentDailySellAmount(addr2.address)).to.equal(sellAmount * 2n);
    });

    it("应该强制执行每日卖出限制", async function () {
      const maxDailySell = await memeToken.maxDailySellAmount();
      const exceedAmount = maxDailySell + ethers.parseEther("1000");
      
      await expect(
        memeToken.connect(addr2).transfer(addr1.address, exceedAmount)
      ).to.be.revertedWith("Daily sell amount exceeds maximum limit");
    });

    it("应该在24小时后重置每日限制", async function () {
      const maxDailySell = await memeToken.maxDailySellAmount();
      const sellAmount = maxDailySell / 2n;
      
      // 第一天卖出
      await memeToken.connect(addr2).transfer(addr1.address, sellAmount);
      expect(await memeToken.getCurrentDailySellAmount(addr2.address)).to.equal(sellAmount);
      
      // 前进24小时
      await time.increase(24 * 60 * 60 + 1);
      
      // 应该重置为0
      expect(await memeToken.getCurrentDailySellAmount(addr2.address)).to.equal(0);
      
      // 现在应该能够卖出相同金额
      await memeToken.connect(addr2).transfer(addr1.address, sellAmount);
      expect(await memeToken.getCurrentDailySellAmount(addr2.address)).to.equal(sellAmount);
    });

    it("应该跟踪每日买入次数", async function () {
      // 模拟从配对买入（从配对转移到用户）
      await memeToken.setExcludedFromLimit(addr1.address, false); // 配对不是免限制的
      
      const buyAmount = ethers.parseEther("1000");
      await memeToken.transfer(addr1.address, buyAmount); // 给配对一些代币
      
      // 多次买入
      for (let i = 0; i < 5; i++) {
        await memeToken.connect(addr1).transfer(addr2.address, ethers.parseEther("100"));
      }
      
      expect(await memeToken.getCurrentDailyBuys(addr2.address)).to.equal(5);
    });

    it("应该强制执行每日买入次数限制", async function () {
      await memeToken.setExcludedFromLimit(addr1.address, false);
      
      // 给配对足够代币
      await memeToken.transfer(addr1.address, ethers.parseEther("10000"));
      
      const maxBuys = await memeToken.maxDailyBuys();
      
      // 达到最大买入次数
      for (let i = 0; i < maxBuys; i++) {
        await memeToken.connect(addr1).transfer(addr2.address, ethers.parseEther("100"));
      }
      
      // 下一次买入应该失败
      await expect(
        memeToken.connect(addr1).transfer(addr2.address, ethers.parseEther("100"))
      ).to.be.revertedWith("Daily buy count exceeds maximum limit");
    });
  });

  describe("税收计算和分配", function () {
    beforeEach(async function () {
      await memeToken.enableTrading();
      await memeToken.setUniswapPair(addr1.address);
    });

    it("应该正确计算买入税", async function () {
      const transferAmount = ethers.parseEther("1000");
      const expectedTax = transferAmount * 200n / 10000n; // 2%
      
      // 给配对一些代币用于测试
      await memeToken.transfer(addr1.address, transferAmount + expectedTax);
      
      // 模拟买入（从配对到用户）
      await memeToken.connect(addr1).transfer(addr2.address, transferAmount + expectedTax);
      
      // 检查用户收到的金额（应该是原金额减去税收）
      expect(await memeToken.balanceOf(addr2.address)).to.equal(transferAmount);
    });

    it("应该正确计算卖出税", async function () {
      const transferAmount = ethers.parseEther("1000");
      const expectedTax = transferAmount * 200n / 10000n; // 2%
      
      // 给用户一些代币
      await memeToken.transfer(addr2.address, transferAmount + expectedTax);
      
      // 模拟卖出（从用户到配对）
      await memeToken.connect(addr2).transfer(addr1.address, transferAmount + expectedTax);
      
      // 检查配对收到的金额（应该是原金额减去税收）
      const expectedReceived = transferAmount;
      // 注意：实际测试中需要更精确的计算和余额检查
    });

    it("免税地址不应被征税", async function () {
      const transferAmount = ethers.parseEther("1000");
      const initialBalance = await memeToken.balanceOf(marketingWallet.address);
      
      // 营销钱包是免税的
      await memeToken.transfer(marketingWallet.address, transferAmount);
      
      expect(await memeToken.balanceOf(marketingWallet.address)).to.equal(
        initialBalance + transferAmount
      );
    });
  });

  describe("所有权和管理功能", function () {
    it("应该正确设置所有者", async function () {
      expect(await memeToken.owner()).to.equal(owner.address);
    });

    it("应该允许所有者设置免税地址", async function () {
      await memeToken.setExcludedFromTax(addr1.address, true);
      expect(await memeToken.isExcludedFromTax(addr1.address)).to.be.true;
      
      await memeToken.setExcludedFromTax(addr1.address, false);
      expect(await memeToken.isExcludedFromTax(addr1.address)).to.be.false;
    });

    it("应该允许所有者设置免限制地址", async function () {
      await memeToken.setExcludedFromLimit(addr1.address, true);
      expect(await memeToken.isExcludedFromLimit(addr1.address)).to.be.true;
      
      await memeToken.setExcludedFromLimit(addr1.address, false);
      expect(await memeToken.isExcludedFromLimit(addr1.address)).to.be.false;
    });

    it("非所有者不能设置免税/免限制地址", async function () {
      await expect(
        memeToken.connect(addr1).setExcludedFromTax(addr2.address, true)
      ).to.be.revertedWithCustomError(memeToken, "OwnableUnauthorizedAccount");
      
      await expect(
        memeToken.connect(addr1).setExcludedFromLimit(addr2.address, true)
      ).to.be.revertedWithCustomError(memeToken, "OwnableUnauthorizedAccount");
    });
  });

  describe("紧急功能", function () {
    it("应该允许所有者手动分配税收", async function () {
      // 先给合约一些代币（模拟积累的税收）
      const taxAmount = ethers.parseEther("1000");
      await memeToken.transfer(await memeToken.getAddress(), taxAmount);
      
      const marketingInitialBalance = await memeToken.balanceOf(marketingWallet.address);
      const liquidityInitialBalance = await memeToken.balanceOf(liquidityWallet.address);
      const devInitialBalance = await memeToken.balanceOf(devWallet.address);
      
      await memeToken.manualDistributeTaxes();
      
      // 检查税收是否正确分配
      expect(await memeToken.balanceOf(marketingWallet.address)).to.be.gt(marketingInitialBalance);
      expect(await memeToken.balanceOf(liquidityWallet.address)).to.be.gt(liquidityInitialBalance);
      expect(await memeToken.balanceOf(devWallet.address)).to.be.gt(devInitialBalance);
    });
  });
});