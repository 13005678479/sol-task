const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("简单功能测试", function () {
  let memeToken;
  let owner, addr1, addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();
    
    const MemeToken = await ethers.getContractFactory("MemeToken");
    memeToken = await MemeToken.deploy(
      "MemeShiba",
      "MEMESHI",
      1000000000,
      owner.address,
      addr1.address,
      addr2.address
    );
    await memeToken.waitForDeployment();
  });

  describe("基本功能", function () {
    it("应该设置正确的代币信息", async function () {
      expect(await memeToken.name()).to.equal("MemeShiba");
      expect(await memeToken.symbol()).to.equal("MEMESHI");
      expect(await memeToken.totalSupply()).to.equal(ethers.parseEther("1000000000"));
    });

    it("应该将总供应量分配给部署者", async function () {
      expect(await memeToken.balanceOf(owner.address)).to.equal(ethers.parseEther("1000000000"));
    });

    it("应该能够正常转账", async function () {
      await memeToken.enableTrading();
      await memeToken.transfer(addr1.address, ethers.parseEther("1000"));
      
      expect(await memeToken.balanceOf(addr1.address)).to.equal(ethers.parseEther("1000"));
    });

    it("应该能够开启交易", async function () {
      expect(await memeToken.tradingEnabled()).to.be.false;
      await memeToken.enableTrading();
      expect(await memeToken.tradingEnabled()).to.be.true;
    });

    it("应该能够更新税率", async function () {
      await memeToken.updateTaxRates(500, 800);
      expect(await memeToken.buyTaxRate()).to.equal(500);
      expect(await memeToken.sellTaxRate()).to.equal(800);
    });

    it("应该能够设置免税地址", async function () {
      await memeToken.setExcludedFromTax(addr1.address, true);
      expect(await memeToken.isExcludedFromTax(addr1.address)).to.be.true;
    });
  });

  describe("税收功能", function () {
    beforeEach(async function () {
      await memeToken.enableTrading();
      // 设置一个假的配对地址用于测试
      await memeToken.setUniswapPair(addr2.address);
    });

    it("应该正确计算税收", async function () {
      const transferAmount = ethers.parseEther("1000");
      const expectedTax = transferAmount * 200n / 10000n; // 2%
      const expectedReceive = transferAmount - expectedTax;
      
      // 给配对一些代币
      await memeToken.transfer(addr2.address, transferAmount + expectedTax);
      
      // 模拟买入（从配对到用户）
      await memeToken.connect(addr2).transfer(addr1.address, transferAmount + expectedTax);
      
      // 检查用户收到的金额
      expect(await memeToken.balanceOf(addr1.address)).to.equal(expectedReceive);
    });

    it("免税地址不应该被征税", async function () {
      const transferAmount = ethers.parseEther("1000");
      const initialBalance = await memeToken.balanceOf(addr1.address);
      
      // 设置用户为免税
      await memeToken.setExcludedFromTax(addr1.address, true);
      
      await memeToken.transfer(addr1.address, transferAmount);
      
      expect(await memeToken.balanceOf(addr1.address)).to.equal(initialBalance + transferAmount);
    });
  });

  describe("交易限制", function () {
    beforeEach(async function () {
      await memeToken.enableTrading();
      await memeToken.setUniswapPair(addr2.address);
    });

    it("应该强制执行最大交易量限制", async function () {
      const maxTx = await memeToken.maxTransactionAmount();
      const exceedAmount = maxTx + ethers.parseEther("1");
      
      await expect(
        memeToken.transfer(addr1.address, exceedAmount)
      ).to.be.revertedWith("Transaction amount exceeds maximum limit");
    });

    it("免税地址应该不受交易限制", async function () {
      const maxTx = await memeToken.maxTransactionAmount();
      const exceedAmount = maxTx + ethers.parseEther("1000");
      
      // 设置为免税和免限制
      await memeToken.setExcludedFromTax(addr1.address, true);
      await memeToken.setExcludedFromLimit(addr1.address, true);
      
      await expect(
        memeToken.transfer(addr1.address, exceedAmount)
      ).to.not.be.reverted;
    });
  });
});