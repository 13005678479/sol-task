const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("🚀 开始部署MemeToken合约...\n");
  
  const [deployer] = await ethers.getSigners();
  console.log("📋 部署账户:", deployer.address);
  console.log("  余额:", ethers.formatEther(await deployer.provider.getBalance(deployer.address)), "ETH\n");

  const MemeToken = await ethers.getContractFactory("MemeToken");
  
  // 代币配置参数
  const tokenConfig = {
    name: "MemeShiba",
    symbol: "MEMESHI", 
    totalSupply: "1000000000", // 10亿
    marketingWallet: deployer.address,
    liquidityWallet: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
    devWallet: "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
  };

  console.log("📊 代币配置:");
  console.log("  名称:", tokenConfig.name);
  console.log("  符号:", tokenConfig.symbol);
  console.log("  总供应量:", tokenConfig.totalSupply, tokenConfig.symbol);
  console.log("  营销钱包:", tokenConfig.marketingWallet);
  console.log("  流动性钱包:", tokenConfig.liquidityWallet);
  console.log("  开发钱包:", tokenConfig.devWallet);

  const memeToken = await MemeToken.deploy(
    tokenConfig.name,
    tokenConfig.symbol,
    tokenConfig.totalSupply,
    tokenConfig.marketingWallet,
    tokenConfig.liquidityWallet,
    tokenConfig.devWallet
  );

  await memeToken.waitForDeployment();
  const memeTokenAddress = await memeToken.getAddress();

  console.log("\n✅ MemeToken合约部署成功!");
  console.log("  合约地址:", memeTokenAddress);
  
  // 显示初始配置
  console.log("\n📋 初始配置:");
  console.log("  买入税率:", Number(await memeToken.buyTaxRate()) / 100, "%");
  console.log("  卖出税率:", Number(await memeToken.sellTaxRate()) / 100, "%");
  console.log("  最大交易量:", ethers.formatEther(await memeToken.maxTransactionAmount()), tokenConfig.symbol);
  console.log("  交易状态:", await memeToken.tradingEnabled() ? "已开启" : "未开启");

  // 开启交易功能
  console.log("\n🔓 开启交易功能...");
  await memeToken.enableTrading();
  console.log("  ✅ 交易功能已开启");

  // 保存合约地址
  const deploymentInfo = {
    memeToken: {
      address: memeTokenAddress,
      ...tokenConfig,
      deployedAt: new Date().toISOString()
    }
  };

  const fs = require("fs");
  fs.writeFileSync(
    "deployment-meme-token.json",
    JSON.stringify(deploymentInfo, null, 2)
  );
  console.log("  💾 部署信息已保存到 deployment-meme-token.json");

  console.log("\n🎉 MemeToken合约部署完成!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ 部署失败:", error);
    process.exit(1);
  });