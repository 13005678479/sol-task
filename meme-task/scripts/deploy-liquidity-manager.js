const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("🚀 开始部署LiquidityManager合约...\n");
  
  const [deployer] = await ethers.getSigners();
  console.log("📋 部署账户:", deployer.address);
  console.log("  余额:", ethers.formatEther(await deployer.provider.getBalance(deployer.address)), "ETH\n");

  // 获取MemeToken合约地址（从命令行参数或部署文件中读取）
  let memeTokenAddress;
  
  if (process.argv.length > 2) {
    memeTokenAddress = process.argv[2];
    console.log("📝 使用命令行提供的代币地址:", memeTokenAddress);
  } else {
    // 尝试从部署文件读取
    try {
      const fs = require("fs");
      const deploymentInfo = JSON.parse(fs.readFileSync("deployment-meme-token.json", "utf8"));
      memeTokenAddress = deploymentInfo.memeToken.address;
      console.log("📝 从部署文件读取代币地址:", memeTokenAddress);
    } catch (error) {
      console.error("❌ 无法获取MemeToken地址，请先部署MemeToken合约或通过参数提供地址");
      console.log("用法: npx hardhat run deploy-liquidity-manager.js --network <network> <token_address>");
      process.exit(1);
    }
  }

  // 验证代币合约
  try {
    const tokenContract = await ethers.getContractAt("MemeToken", memeTokenAddress);
    const tokenName = await tokenContract.name();
    const tokenSymbol = await tokenContract.symbol();
    console.log("  ✅ 代币验证成功:", tokenName, "(", tokenSymbol, ")");
  } catch (error) {
    console.error("❌ 代币地址验证失败:", error.message);
    process.exit(1);
  }

  const LiquidityManager = await ethers.getContractFactory("LiquidityManager");
  
  const liquidityManager = await LiquidityManager.deploy(memeTokenAddress);
  await liquidityManager.waitForDeployment();
  const liquidityManagerAddress = await liquidityManager.getAddress();

  console.log("\n✅ LiquidityManager合约部署成功!");
  console.log("  合约地址:", liquidityManagerAddress);
  console.log("  管理的代币:", memeTokenAddress);

  // 显示初始配置
  console.log("\n📋 初始配置:");
  console.log("  Uniswap Router:", await liquidityManager.UNISWAP_V2_ROUTER());
  console.log("  WETH地址:", await liquidityManager.WETH());
  console.log("  最小流动性:", ethers.formatEther(await liquidityManager.minimumLiquidity()));
  console.log("  自动添加流动性:", await liquidityManager.autoAddLiquidity());
  console.log("  自动流动性份额:", (await liquidityManager.autoLiquidityShare()) / 100, "%");

  // 保存合约地址和配置
  const deploymentInfo = {
    liquidityManager: {
      address: liquidityManagerAddress,
      memeTokenAddress: memeTokenAddress,
      config: {
        uniswapRouter: await liquidityManager.UNISWAP_V2_ROUTER(),
        weth: await liquidityManager.WETH(),
        minimumLiquidity: (await liquidityManager.minimumLiquidity()).toString(),
        autoAddLiquidity: await liquidityManager.autoAddLiquidity(),
        autoLiquidityShare: (await liquidityManager.autoLiquidityShare()).toString()
      },
      deployedAt: new Date().toISOString()
    }
  };

  const fs = require("fs");
  fs.writeFileSync(
    "deployment-liquidity-manager.json",
    JSON.stringify(deploymentInfo, null, 2)
  );
  console.log("  💾 部署信息已保存到 deployment-liquidity-manager.json");

  // 更新主部署文件
  try {
    let mainDeployment = {};
    try {
      mainDeployment = JSON.parse(fs.readFileSync("deployment-info.json", "utf8"));
    } catch (error) {
      // 如果文件不存在，创建新的
    }
    
    mainDeployment.contracts = mainDeployment.contracts || {};
    mainDeployment.contracts.liquidityManager = {
      address: liquidityManagerAddress,
      memeTokenAddress: memeTokenAddress
    };
    
    fs.writeFileSync("deployment-info.json", JSON.stringify(mainDeployment, null, 2));
    console.log("  💾 主部署文件已更新");
  } catch (error) {
    console.log("  ⚠️  无法更新主部署文件:", error.message);
  }

  console.log("\n🎉 LiquidityManager合约部署完成!");
  console.log("\n📝 下一步操作:");
  console.log("1. 创建Uniswap V2流动性池");
  console.log("2. 设置流动性池配对地址");
  console.log("3. 添加初始流动性");
  console.log("4. 测试流动性管理功能");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ 部署失败:", error);
    process.exit(1);
  });