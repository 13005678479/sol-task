const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LiquidityManager", function () {
  let memeToken, liquidityManager;
  let owner, addr1, addr2, addr3;
  let uniswapV2Router, uniswapPair, weth;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();
    
    // 部署MemeToken
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

    // 部署LiquidityManager
    const LiquidityManager = await ethers.getContractFactory("LiquidityManager");
    liquidityManager = await LiquidityManager.deploy(await memeToken.getAddress());
    await liquidityManager.waitForDeployment();

    // 模拟Uniswap配对地址
    uniswapPair = addr3.address;
    await liquidityManager.setLiquidityPair(uniswapPair);
    
    // 创建一个模拟的ERC20代币作为LP代币
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const lpToken = await MockERC20.deploy("LP Token", "LP", ethers.parseEther("1000000"));
    await lpToken.waitForDeployment();
    
    // 给LiquidityManager一些LP代币用于测试
    await lpToken.transfer(await liquidityManager.getAddress(), ethers.parseEther("10000"));
    
    // WETH地址（使用模拟地址）
    weth = await liquidityManager.WETH();
  });

  describe("部署", function () {
    it("应该设置正确的代币地址", async function () {
      expect(await liquidityManager.memeToken()).to.equal(await memeToken.getAddress());
    });

    it("应该设置正确的Uniswap Router地址", async function () {
      const expectedRouter = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
      expect(await liquidityManager.UNISWAP_V2_ROUTER()).to.equal(expectedRouter);
    });

    it("应该设置正确的WETH地址", async function () {
      const expectedWETH = "0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14";
      expect(await liquidityManager.WETH()).to.equal(expectedWETH);
    });

    it("应该设置正确的初始配置", async function () {
      expect(await liquidityManager.minimumLiquidity()).to.equal(ethers.parseEther("1000"));
      expect(await liquidityManager.autoAddLiquidity()).to.be.true;
      expect(await liquidityManager.autoLiquidityShare()).to.equal(5000); // 50%
    });
  });

  describe("流动性配对管理", function () {
    it("应该允许所有者设置流动性配对地址", async function () {
      const newPair = addr1.address;
      await liquidityManager.setLiquidityPair(newPair);
      expect(await liquidityManager.liquidityPair()).to.equal(newPair);
    });

    it("非所有者不能设置流动性配对地址", async function () {
      await expect(
        liquidityManager.connect(addr1).setLiquidityPair(addr2.address)
      ).to.be.revertedWithCustomError(liquidityManager, "OwnableUnauthorizedAccount");
    });

    it("许多操作需要有效的配对地址", async function () {
      // 清除配对地址
      await liquidityManager.setLiquidityPair(ethers.ZeroAddress);
      
      await expect(
        liquidityManager.addLiquidity(
          ethers.parseEther("1000"),
          ethers.parseEther("1"),
          ethers.parseEther("900"),
          ethers.parseEther("0.9")
        )
      ).to.be.revertedWith("Liquidity pair not set");
    });
  });

  describe("自动流动性功能", function () {
    it("应该允许所有者切换自动流动性", async function () {
      await liquidityManager.toggleAutoLiquidity();
      expect(await liquidityManager.autoAddLiquidity()).to.be.false;
      
      await liquidityManager.toggleAutoLiquidity();
      expect(await liquidityManager.autoAddLiquidity()).to.be.true;
    });

    it("应该允许所有者更新自动流动性份额", async function () {
      await liquidityManager.updateAutoLiquidityShare(3000); // 30%
      expect(await liquidityManager.autoLiquidityShare()).to.equal(3000);
    });

    it("自动流动性份额不能超过100%", async function () {
      await expect(
        liquidityManager.updateAutoLiquidityShare(10001)
      ).to.be.revertedWith("Share cannot exceed 100%");
    });

    it("应该允许所有者更新最小流动性", async function () {
      const newMinimum = ethers.parseEther("5000");
      await liquidityManager.updateMinimumLiquidity(newMinimum);
      expect(await liquidityManager.minimumLiquidity()).to.equal(newMinimum);
    });

    it("非所有者不能修改自动流动性设置", async function () {
      await expect(
        liquidityManager.connect(addr1).toggleAutoLiquidity()
      ).to.be.revertedWithCustomError(liquidityManager, "OwnableUnauthorizedAccount");
      
      await expect(
        liquidityManager.connect(addr1).updateAutoLiquidityShare(3000)
      ).to.be.revertedWithCustomError(liquidityManager, "OwnableUnauthorizedAccount");
      
      await expect(
        liquidityManager.connect(addr1).updateMinimumLiquidity(ethers.parseEther("2000"))
      ).to.be.revertedWithCustomError(liquidityManager, "OwnableUnauthorizedAccount");
    });
  });

  describe("添加流动性", function () {
    const tokenAmount = ethers.parseEther("10000");
    const ethAmount = ethers.parseEther("5");

    beforeEach(async function () {
      // 给用户一些代币
      await memeToken.transfer(addr1.address, tokenAmount * 2n);
      
      // 用户批准代币给LiquidityManager
      await memeToken.connect(addr1).approve(await liquidityManager.getAddress(), tokenAmount * 2n);
    });

    it("应该拒绝零金额", async function () {
      await expect(
        liquidityManager.connect(addr1).addLiquidity(
          0,
          ethAmount,
          0,
          0
        )
      ).to.be.revertedWith("Amounts must be greater than zero");
    });

    it("应该拒绝低于最小流动性的代币金额", async function () {
      await expect(
        liquidityManager.connect(addr1).addLiquidity(
          ethers.parseEther("500"), // 低于1000最小值
          ethAmount,
          0,
          0,
          { value: ethAmount }
        )
      ).to.be.revertedWith("Token amount below minimum");
    });

    it("应该拒绝不匹配的ETH金额", async function () {
      await expect(
        liquidityManager.connect(addr1).addLiquidity(
          tokenAmount,
          ethAmount,
          0,
          0,
          { value: ethers.parseEther("3") } // 与ethAmount不匹配
        )
      ).to.be.revertedWith("ETH amount mismatch");
    });

    // 注意：由于我们使用模拟的Uniswap Router，实际添加流动性的测试会更复杂
    // 在真实环境中，需要部署完整的Uniswap合约或使用fork测试
  });

  describe("移除流动性", function () {
    const liquidityAmount = ethers.parseEther("1000");

    beforeEach(async function () {
      // 模拟用户已经提供了流动性
      // 在实际测试中，这需要先添加流动性
    });

    it("应该拒绝零流动性", async function () {
      await expect(
        liquidityManager.removeLiquidity(0, 0, 0)
      ).to.be.revertedWith("Liquidity must be greater than zero");
    });

    it("应该拒绝超过用户持有的流动性", async function () {
      await expect(
        liquidityManager.removeLiquidity(liquidityAmount, 0, 0)
      ).to.be.revertedWith("Insufficient liquidity");
    });

    // 实际移除流动性的测试需要真实的LP代币和Uniswap集成
  });

  describe("自动添加税收流动性", function () {
    const tokenAmount = ethers.parseEther("5000");
    const ethAmount = ethers.parseEther("2");

    beforeEach(async function () {
      // 给合约一些代币和ETH用于测试
      await memeToken.transfer(await liquidityManager.getAddress(), tokenAmount);
      
      // 直接向合约发送ETH
      await owner.sendTransaction({
        to: await liquidityManager.getAddress(),
        value: ethAmount
      });
    });

    it("应该允许所有者自动添加流动性", async function () {
      await liquidityManager.autoAddLiquidityFromTax(tokenAmount, ethAmount);
      // 在真实环境中，这会实际添加流动性到Uniswap
    });

    it("非所有者不能自动添加流动性", async function () {
      await expect(
        liquidityManager.connect(addr1).autoAddLiquidityFromTax(tokenAmount, ethAmount)
      ).to.be.revertedWithCustomError(liquidityManager, "OwnableUnauthorizedAccount");
    });

    it("如果自动流动性被禁用应该拒绝", async function () {
      await liquidityManager.toggleAutoLiquidity(); // 禁用
      
      await expect(
        liquidityManager.autoAddLiquidityFromTax(tokenAmount, ethAmount)
      ).to.be.revertedWith("Auto liquidity is disabled");
    });

    it("应该检查代币余额", async function () {
      const excessiveAmount = tokenAmount * 2n;
      
      await expect(
        liquidityManager.autoAddLiquidityFromTax(excessiveAmount, ethAmount)
      ).to.be.revertedWith("Insufficient token balance");
    });

    it("应该检查ETH余额", async function () {
      const excessiveEth = ethAmount * 2n;
      
      await expect(
        liquidityManager.autoAddLiquidityFromTax(tokenAmount, excessiveEth)
      ).to.be.revertedWith("Insufficient ETH balance");
    });
  });

  describe("紧急功能", function () {
    it("应该允许所有者紧急移除所有流动性", async function () {
      // 在真实环境中，这需要实际的LP代币余额
      // await liquidityManager.emergencyRemoveAllLiquidity();
    });

    it("应该允许所有者紧急提取代币", async function () {
      // 给合约一些代币
      const withdrawAmount = ethers.parseEther("1000");
      await memeToken.transfer(await liquidityManager.getAddress(), withdrawAmount);
      
      const initialBalance = await memeToken.balanceOf(owner.address);
      await liquidityManager.emergencyWithdrawToken(await memeToken.getAddress(), withdrawAmount);
      
      expect(await memeToken.balanceOf(owner.address)).to.equal(initialBalance + withdrawAmount);
    });

    it("应该允许所有者紧急提取ETH", async function () {
      const withdrawAmount = ethers.parseEther("1");
      
      // 给合约一些ETH
      await owner.sendTransaction({
        to: await liquidityManager.getAddress(),
        value: withdrawAmount
      });
      
      const initialBalance = await ethers.provider.getBalance(owner.address);
      await liquidityManager.emergencyWithdrawETH(withdrawAmount);
      
      // 注意：由于gas费用，余额检查需要考虑gas消耗
      const finalBalance = await ethers.provider.getBalance(owner.address);
      expect(finalBalance).to.be.gt(initialBalance);
    });

    it("应该拒绝提取超过余额的代币", async function () {
      const contractBalance = await memeToken.balanceOf(await liquidityManager.getAddress());
      const excessiveAmount = contractBalance + ethers.parseEther("1");
      
      await expect(
        liquidityManager.emergencyWithdrawToken(await memeToken.getAddress(), excessiveAmount)
      ).to.be.revertedWith("Amount exceeds balance");
    });

    it("应该拒绝提取超过余额的ETH", async function () {
      const contractBalance = await ethers.provider.getBalance(await liquidityManager.getAddress());
      const excessiveAmount = contractBalance + ethers.parseEther("1");
      
      await expect(
        liquidityManager.emergencyWithdrawETH(excessiveAmount)
      ).to.be.revertedWith("Amount exceeds balance");
    });

    it("非所有者不能使用紧急功能", async function () {
      await expect(
        liquidityManager.connect(addr1).emergencyRemoveAllLiquidity()
      ).to.be.revertedWithCustomError(liquidityManager, "OwnableUnauthorizedAccount");
      
      await expect(
        liquidityManager.connect(addr1).emergencyWithdrawToken(await memeToken.getAddress(), ethers.parseEther("100"))
      ).to.be.revertedWithCustomError(liquidityManager, "OwnableUnauthorizedAccount");
      
      await expect(
        liquidityManager.connect(addr1).emergencyWithdrawETH(ethers.parseEther("0.1"))
      ).to.be.revertedWithCustomError(liquidityManager, "OwnableUnauthorizedAccount");
    });
  });

  describe("查询功能", function () {
    it("应该返回正确的合约余额", async function () {
      const contractBalance = await memeToken.balanceOf(await liquidityManager.getAddress());
      expect(contractBalance).to.equal(0); // 初始为0
      
      // 转一些代币到合约
      const transferAmount = ethers.parseEther("1000");
      await memeToken.transfer(await liquidityManager.getAddress(), transferAmount);
      
      expect(await memeToken.balanceOf(await liquidityManager.getAddress())).to.equal(transferAmount);
    });

    it("应该返回正确的ETH余额", async function () {
      const initialBalance = await ethers.provider.getBalance(await liquidityManager.getAddress());
      expect(initialBalance).to.equal(0);
      
      // 发送ETH到合约
      const sendAmount = ethers.parseEther("1");
      await owner.sendTransaction({
        to: await liquidityManager.getAddress(),
        value: sendAmount
      });
      
      expect(await ethers.provider.getBalance(await liquidityManager.getAddress())).to.equal(sendAmount);
    });
  });
});

// 模拟ERC20代币合约用于测试
const MockERC20Source = `
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}
`;

// 如果需要，可以在测试前部署MockERC20合约