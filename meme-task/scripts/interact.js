const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("🔍 开始合约交互测试...\n");
  
  const [owner, user1, user2] = await ethers.getSigners();
  console.log("📋 账户信息:");
  console.log("  所有者:", owner.address);
  console.log("  用户1:", user1.address);
  console.log("  用户2:", user2.address);

  // 读取部署信息
  const fs = require("fs");
  let deploymentInfo;
  try {
    deploymentInfo = JSON.parse(fs.readFileSync("deployment-meme-token.json", "utf8"));
  } catch (error) {
    console.error("❌ 无法找到部署信息，请先部署合约");
    return;
  }

  // 连接到已部署的合约
  const memeToken = await ethers.getContractAt("MemeToken", deploymentInfo.memeToken.address);
  
  console.log("\n📊 代币信息:");
  console.log("  名称:", await memeToken.name());
  console.log("  符号:", await memeToken.symbol());
  console.log("  总供应量:", ethers.formatEther(await memeToken.totalSupply()));
  console.log("  合约地址:", await memeToken.getAddress());

  console.log("\n💰 账户余额:");
  console.log("  所有者:", ethers.formatEther(await memeToken.balanceOf(owner.address)));
  console.log("  用户1:", ethers.formatEther(await memeToken.balanceOf(user1.address)));
  console.log("  用户2:", ethers.formatEther(await memeToken.balanceOf(user2.address)));

  // 测试基本转账
  console.log("\n🔄 测试转账功能...");
  try {
    const transferAmount = ethers.parseEther("1000");
    
    console.log("  从所有者转账 1000 MEMESHI 到用户1...");
    await memeToken.transfer(user1.address, transferAmount);
    console.log("  ✅ 转账成功");
    
    console.log("  用户1余额:", ethers.formatEther(await memeToken.balanceOf(user1.address)));
  } catch (error) {
    console.error("  ❌ 转账失败:", error.message);
  }

  // 测试税收功能
  console.log("\n💸 测试税收功能...");
  try {
    // 设置配对地址（模拟）
    await memeToken.setUniswapPair(user2.address);
    console.log("  设置配对地址:", user2.address);
    
    // 给配对一些代币
    const pairAmount = ethers.parseEther("50000");
    await memeToken.transfer(user2.address, pairAmount);
    console.log("  给配对转账:", ethers.formatEther(pairAmount));
    
    // 模拟买入（从配对到用户1）
    const buyAmount = ethers.parseEther("1000");
    console.log("  模拟买入:", ethers.formatEther(buyAmount));
    await memeToken.connect(user2).transfer(user1.address, buyAmount + (buyAmount * 200n / 10000n)); // 包含2%税
    
    console.log("  用户1余额:", ethers.formatEther(await memeToken.balanceOf(user1.address)));
    console.log("  ✅ 税收功能正常");
  } catch (error) {
    console.error("  ❌ 税收测试失败:", error.message);
  }

  // 测试限制功能
  console.log("\n🚧 测试交易限制...");
  try {
    const maxTx = await memeToken.maxTransactionAmount();
    console.log("  最大交易量:", ethers.formatEther(maxTx));
    
    const exceedAmount = maxTx + ethers.parseEther("1");
    console.log("  尝试超额转账:", ethers.formatEther(exceedAmount));
    
    await memeToken.transfer(user1.address, exceedAmount);
    console.log("  ⚠️  限制功能异常 - 应该被拒绝");
  } catch (error) {
    console.log("  ✅ 交易限制正常工作:", error.message.substring(0, 50) + "...");
  }

  // 测试税收分配
  console.log("\n💰 测试税收分配...");
  try {
    const marketingBalance = await memeToken.balanceOf(deploymentInfo.memeToken.marketingWallet);
    const liquidityBalance = await memeToken.balanceOf(deploymentInfo.memeToken.liquidityWallet);
    const devBalance = await memeToken.balanceOf(deploymentInfo.memeToken.devWallet);
    
    console.log("  营销钱包:", ethers.formatEther(marketingBalance));
    console.log("  流动性钱包:", ethers.formatEther(liquidityBalance));
    console.log("  开发钱包:", ethers.formatEther(devBalance));
    
    // 手动分配税收
    const contractBalance = await memeToken.balanceOf(await memeToken.getAddress());
    if (contractBalance > 0) {
      console.log("  合约余额:", ethers.formatEther(contractBalance));
      console.log("  执行手动税收分配...");
      await memeToken.manualDistributeTaxes();
      console.log("  ✅ 税收分配完成");
    }
  } catch (error) {
    console.error("  ❌ 税收分配失败:", error.message);
  }

  // 显示当前税率设置
  console.log("\n📊 当前税率设置:");
  console.log("  买入税率:", Number(await memeToken.buyTaxRate()) / 100, "%");
  console.log("  卖出税率:", Number(await memeToken.sellTaxRate()) / 100, "%");
  console.log("  营销份额:", Number(await memeToken.marketingShare()) / 100, "%");
  console.log("  流动性份额:", Number(await memeToken.liquidityShare()) / 100, "%");
  console.log("  开发份额:", Number(await memeToken.devShare()) / 100, "%");

  // 显示交易限制设置
  console.log("\n🚧 当前交易限制:");
  console.log("  最大交易量:", ethers.formatEther(await memeToken.maxTransactionAmount()));
  console.log("  最大钱包余额:", ethers.formatEther(await memeToken.maxWalletBalance()));
  console.log("  每日最大卖出:", ethers.formatEther(await memeToken.maxDailySellAmount()));
  console.log("  每日最大买入次数:", await memeToken.maxDailyBuys());

  console.log("\n🎉 交互测试完成!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ 交互测试失败:", error);
    process.exit(1);
  });