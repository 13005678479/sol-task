const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Simple Uniswap DEX", function () {
  let tokenA, tokenB, liquidityPool;
  let owner, user1, user2;
  
  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    // 部署TokenA
    const TokenA = await ethers.getContractFactory("ERC20Token");
    tokenA = await TokenA.deploy("TokenA", "TKA", 1000000);

    // 部署TokenB
    const TokenB = await ethers.getContractFactory("ERC20Token");
    tokenB = await TokenB.deploy("TokenB", "TKB", 1000000);

    // 部署流动性池
    const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
    liquidityPool = await LiquidityPool.deploy(await tokenA.getAddress(), await tokenB.getAddress());

    // 给用户转账一些代币
    await tokenA.transfer(user1.address, ethers.parseUnits("100000", 18));
    await tokenB.transfer(user1.address, ethers.parseUnits("100000", 18));
    await tokenA.transfer(user2.address, ethers.parseUnits("100000", 18));
    await tokenB.transfer(user2.address, ethers.parseUnits("100000", 18));
  });

  describe("ERC20 Token", function () {
    it("应该有正确的名称和符号", async function () {
      expect(await tokenA.name()).to.equal("Token A");
      expect(await tokenA.symbol()).to.equal("TKA");
      expect(await tokenB.name()).to.equal("Token B");
      expect(await tokenB.symbol()).to.equal("TKB");
    });

    it("应该有正确的初始供应量", async function () {
      const totalSupply = ethers.parseUnits("1000000", 18);
      expect(await tokenA.totalSupply()).to.equal(totalSupply);
      expect(await tokenB.totalSupply()).to.equal(totalSupply);
    });

    it("只有所有者可以铸造代币", async function () {
      const mintAmount = ethers.parseUnits("1000", 18);
      await expect(tokenA.mint(user1.address, mintAmount))
        .to.emit(tokenA, "Transfer")
        .withArgs(ethers.ZeroAddress, user1.address, mintAmount);
    });
  });

  describe("Liquidity Pool", function () {
    beforeEach(async function () {
      // 授权流动性池使用代币
      await tokenA.approve(await liquidityPool.getAddress(), ethers.parseUnits("500000", 18));
      await tokenB.approve(await liquidityPool.getAddress(), ethers.parseUnits("500000", 18));
      await tokenA.connect(user1).approve(await liquidityPool.getAddress(), ethers.parseUnits("100000", 18));
      await tokenB.connect(user1).approve(await liquidityPool.getAddress(), ethers.parseUnits("100000", 18));
    });

    it("应该正确添加初始流动性", async function () {
      const amountA = ethers.parseUnits("100000", 18);
      const amountB = ethers.parseUnits("100000", 18);

      await expect(liquidityPool.addLiquidity(amountA, amountB))
        .to.emit(liquidityPool, "AddLiquidity")
        .withArgs(owner.address, amountA, amountB);

      const [reserve0, reserve1] = await liquidityPool.getReserves();
      expect(reserve0).to.equal(amountA);
      expect(reserve1).to.equal(amountB);

      const lpBalance = await liquidityPool.balanceOf(owner.address);
      expect(lpBalance).to.be.gt(0);
    });

    it("多个用户可以添加流动性", async function () {
      // 添加初始流动性
      const initialAmount = ethers.parseUnits("100000", 18);
      await liquidityPool.addLiquidity(initialAmount, initialAmount);

      // 用户1添加流动性
      const userAmount = ethers.parseUnits("10000", 18);
      await liquidityPool.connect(user1).addLiquidity(userAmount, userAmount);

      const [reserve0, reserve1] = await liquidityPool.getReserves();
      expect(reserve0).to.equal(initialAmount.add(userAmount));
      expect(reserve1).to.equal(initialAmount.add(userAmount));
    });

    it("用户可以移除流动性", async function () {
      // 添加流动性
      const amount = ethers.parseUnits("100000", 18);
      await liquidityPool.addLiquidity(amount, amount);

      const lpBalance = await liquidityPool.balanceOf(owner.address);
      
      await expect(liquidityPool.removeLiquidity(lpBalance))
        .to.emit(liquidityPool, "RemoveLiquidity");

      const [reserve0, reserve1] = await liquidityPool.getReserves();
      expect(reserve0).to.equal(0);
      expect(reserve1).to.equal(0);
    });

    it("可以计算输出金额", async function () {
      // 添加流动性
      const amount = ethers.parseUnits("100000", 18);
      await liquidityPool.addLiquidity(amount, amount);

      const amountIn = ethers.parseUnits("1000", 18);
      const path = [await tokenA.getAddress(), await tokenB.getAddress()];
      const amounts = await liquidityPool.getAmountsOut(amountIn, path);

      expect(amounts[0]).to.equal(amountIn);
      expect(amounts[1]).to.be.gt(0);
      expect(amounts[1]).to.be.lt(amountIn); // 考虑手续费
    });

    it("可以执行代币交换", async function () {
      // 添加流动性
      const amount = ethers.parseUnits("100000", 18);
      await liquidityPool.addLiquidity(amount, amount);

      const amountIn = ethers.parseUnits("1000", 18);
      const path = [await tokenA.getAddress(), await tokenB.getAddress()];
      const amounts = await liquidityPool.getAmountsOut(amountIn, path);
      
      const initialBalanceB = await tokenB.balanceOf(user1.address);
      
      await liquidityPool.connect(user1).swapExactTokensForTokens(
        amountIn,
        0, // 最小输出金额设为0用于测试
        path,
        user1.address
      );

      const finalBalanceB = await tokenB.balanceOf(user1.address);
      expect(finalBalanceB).to.equal(initialBalanceB.add(amounts[1]));
    });

    it("quote函数应该正确计算价格", async function () {
      const amountA = ethers.parseUnits("100", 18);
      const reserveA = ethers.parseUnits("1000", 18);
      const reserveB = ethers.parseUnits("2000", 18);

      const amountB = await liquidityPool.quote(amountA, reserveA, reserveB);
      expect(amountB).to.equal(ethers.parseUnits("200", 18));
    });

    it("应该拒绝无效的流动性添加", async function () {
      await expect(
        liquidityPool.addLiquidity(0, ethers.parseUnits("100", 18))
      ).to.be.revertedWith("Insufficient liquidity amount");

      await expect(
        liquidityPool.addLiquidity(ethers.parseUnits("100", 18), 0)
      ).to.be.revertedWith("Insufficient liquidity amount");
    });

    it("应该拒绝无效的流动性移除", async function () {
      await expect(
        liquidityPool.removeLiquidity(0)
      ).to.be.revertedWith("Insufficient liquidity to remove");
    });

    it("应该拒绝无效的交换路径", async function () {
      await expect(
        liquidityPool.getAmountsOut(
          ethers.parseUnits("100", 18),
          [await tokenA.getAddress()] // 路径太短
        )
      ).to.be.revertedWith("Invalid path");
    });
  });

  describe("Integration Test", function () {
    it("完整的交换流程应该正常工作", async function () {
      // 1. 添加初始流动性
      const liquidityAmount = ethers.parseUnits("100000", 18);
      await tokenA.approve(await liquidityPool.getAddress(), liquidityAmount);
      await tokenB.approve(await liquidityPool.getAddress(), liquidityAmount);
      await liquidityPool.addLiquidity(liquidityAmount, liquidityAmount);

      // 2. 用户1进行交换
      const swapAmount = ethers.parseUnits("1000", 18);
      await tokenA.connect(user1).approve(await liquidityPool.getAddress(), swapAmount);
      
      const path = [await tokenA.getAddress(), await tokenB.getAddress()];
      const amounts = await liquidityPool.getAmountsOut(swapAmount, path);
      
      const initialBalanceB = await tokenB.balanceOf(user1.address);
      
      await liquidityPool.connect(user1).swapExactTokensForTokens(
        swapAmount,
        amounts[1],
        path,
        user1.address
      );

      const finalBalanceB = await tokenB.balanceOf(user1.address);
      expect(finalBalanceB).to.equal(initialBalanceB.add(amounts[1]));

      // 3. 检查流动性池储备量是否正确更新
      const [reserve0, reserve1] = await liquidityPool.getReserves();
      expect(reserve0).to.equal(liquidityAmount.add(swapAmount));
      expect(reserve1).to.equal(liquidityAmount.sub(amounts[1]));
    });
  });
});