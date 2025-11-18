const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("🚀 开始部署Meme代币项目...\n");
  
  // 获取部署账户信息
  const [deployer] = await ethers.getSigners();
  console.log("📋 部署账户信息:");
  console.log("  账户地址:", deployer.address);
  console.log("  账户余额:", ethers.formatEther(await deployer.provider.getBalance(deployer.address)), "ETH\n");

  // 获取网络信息
  const network = await ethers.provider.getNetwork();
  console.log("🌐 网络信息:");
  console.log("  网络名称:", network.name);
  console.log("  链ID:", network.chainId, "\n");

  try {
    // 1. 部署MemeToken合约
    console.log("1️⃣ 部署MemeToken合约...");
    const MemeToken = await ethers.getContractFactory("MemeToken");
    
    // 配置代币参数
    const tokenName = "MemeShiba";
    const tokenSymbol = "MEMESHI";
    const totalSupply = "1000000000"; // 10亿代币
    
    // 配置税收钱包（使用部署者和其他测试地址）
    const marketingWallet = deployer.address;
    const liquidityWallet = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"; // Hardhat第2个账户
    const devWallet = "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC";    // Hardhat第3个账户
    
    const memeToken = await MemeToken.deploy(
      tokenName,
      tokenSymbol,
      totalSupply,
      marketingWallet,
      liquidityWallet,
      devWallet
    );
    
    await memeToken.waitForDeployment();
    const memeTokenAddress = await memeToken.getAddress();
    console.log("  ✅ MemeToken合约地址:", memeTokenAddress);
    console.log("  📊 代币信息:");
    console.log("    名称:", await memeToken.name());
    console.log("    符号:", await memeToken.symbol());
    console.log("    总供应量:", ethers.formatEther(await memeToken.totalSupply()), `${tokenSymbol}`);
    console.log("    部署者余额:", ethers.formatEther(await memeToken.balanceOf(deployer.address)), `${tokenSymbol}\n`);

    // 2. 部署LiquidityManager合约
    console.log("2️⃣ 部署LiquidityManager合约...");
    const LiquidityManager = await ethers.getContractFactory("LiquidityManager");
    const liquidityManager = await LiquidityManager.deploy(memeTokenAddress);
    
    await liquidityManager.waitForDeployment();
    const liquidityManagerAddress = await liquidityManager.getAddress();
    console.log("  ✅ LiquidityManager合约地址:", liquidityManagerAddress, "\n");

    // 3. 创建Uniswap V2配对（模拟）
    console.log("3️⃣ 设置Uniswap配对信息...");
    // 在实际部署中，需要通过Uniswap Router创建配对
    // 这里我们使用一个模拟地址用于测试
    const uniswapPairAddress = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f"; // Uniswap V2 Factory地址（作为示例）
    
    // 设置配对地址
    await memeToken.setUniswapPair(uniswapPairAddress);
    await liquidityManager.setLiquidityPair(uniswapPairAddress);
    console.log("  ✅ Uniswap配对地址设置完成:", uniswapPairAddress);

    // 4. 开启交易功能
    console.log("4️⃣ 开启交易功能...");
    await memeToken.enableTrading();
    console.log("  ✅ 交易功能已开启");

    // 5. 验证配置
    console.log("\n📋 验证合约配置...");
    console.log("  税收配置:");
    console.log("    买入税率:", (await memeToken.buyTaxRate()) / 100, "%");
    console.log("    卖出税率:", (await memeToken.sellTaxRate()) / 100, "%");
    console.log("    营销钱包:", await memeToken.marketingWallet());
    console.log("    流动性钱包:", await memeToken.liquidityWallet());
    console.log("    开发钱包:", await memeToken.devWallet());

    console.log("  交易限制:");
    console.log("    最大交易量:", ethers.formatEther(await memeToken.maxTransactionAmount()), `${tokenSymbol}`);
    console.log("    最大钱包余额:", ethers.formatEther(await memeToken.maxWalletBalance()), `${tokenSymbol}`);
    console.log("    每日最大卖出量:", ethers.formatEther(await memeToken.maxDailySellAmount()), `${tokenSymbol}`);
    console.log("    每日最大买入次数:", await memeToken.maxDailyBuys());

    console.log("  流动性管理:");
    console.log("    自动添加流动性:", await liquidityManager.autoAddLiquidity());
    console.log("    最小流动性:", ethers.formatEther(await liquidityManager.minimumLiquidity()), `${tokenSymbol}`);
    console.log("    自动流动性份额:", (await liquidityManager.autoLiquidityShare()) / 100, "%");

    // 6. 保存部署信息到文件
    console.log("\n💾 保存部署信息...");
    const deploymentInfo = {
      network: {
        name: network.name,
        chainId: network.chainId.toString()
      },
      deployer: {
        address: deployer.address,
        balance: ethers.formatEther(await deployer.provider.getBalance(deployer.address))
      },
      contracts: {
        memeToken: {
          address: memeTokenAddress,
          name: tokenName,
          symbol: tokenSymbol,
          totalSupply: ethers.formatEther(await memeToken.totalSupply())
        },
        liquidityManager: {
          address: liquidityManagerAddress
        }
      },
      config: {
        uniswapPair: uniswapPairAddress,
        taxRates: {
          buy: (await memeToken.buyTaxRate()).toString(),
          sell: (await memeToken.sellTaxRate()).toString()
        },
        wallets: {
          marketing: await memeToken.marketingWallet(),
          liquidity: await memeToken.liquidityWallet(),
          dev: await memeToken.devWallet()
        },
        limits: {
          maxTransaction: ethers.formatEther(await memeToken.maxTransactionAmount()),
          maxWallet: ethers.formatEther(await memeToken.maxWalletBalance()),
          maxDailySell: ethers.formatEther(await memeToken.maxDailySellAmount()),
          maxDailyBuys: (await memeToken.maxDailyBuys()).toString()
        }
      },
      deployedAt: new Date().toISOString()
    };

    // 保存到JSON文件
    const fs = require("fs");
    fs.writeFileSync(
      "deployment-info.json", 
      JSON.stringify(deploymentInfo, null, 2)
    );
    console.log("  ✅ 部署信息已保存到 deployment-info.json");

    // 7. 显示下一步操作提示
    console.log("\n🎉 部署完成！");
    console.log("\n📝 后续操作建议:");
    console.log("1. 在Etherscan上验证合约源码");
    console.log("2. 向Uniswap V2添加流动性");
    console.log("3. 在DEX上测试代币交易");
    console.log("4. 设置代币徽标和信息（如需要）");
    
    if (network.name === "localhost") {
      console.log("\n🧪 本地测试命令:");
      console.log("  编译合约: npm run compile");
      console.log("  运行测试: npm run test");
      console.log("  启动本地节点: npm run node");
      console.log("  部署到本地: npm run deploy");
    } else if (network.name === "sepolia") {
      console.log("\n🔗 Sepolia测试网:");
      console.log("  Etherscan链接: https://sepolia.etherscan.io/address/" + memeTokenAddress);
      console.log("  查看部署信息: cat deployment-info.json");
    }

    console.log("\n✨ 部署成功完成！");

  } catch (error) {
    console.error("❌ 部署过程中发生错误:");
    console.error(error.message);
    process.exit(1);
  }
}

// 错误处理
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ 部署失败:", error);
    process.exit(1);
  });