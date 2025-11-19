const { ethers } = require("hardhat");

async function main() {
  console.log("开始部署合约...");

  // 获取部署账户
  const [deployer] = await ethers.getSigners();
  console.log("部署账户:", deployer.address);
  console.log("账户余额:", ethers.utils.formatEther(await deployer.getBalance()), "ETH");

  // 1. 部署TokenA
  console.log("\n部署TokenA...");
  const TokenA = await ethers.getContractFactory("ERC20Token");
  const tokenA = await TokenA.deploy("Token A", "TKA", 1000000);
  await tokenA.deployed();
  console.log("TokenA部署地址:", tokenA.address);
  console.log("TokenA总供应量:", await tokenA.totalSupply());

  // 2. 部署TokenB
  console.log("\n部署TokenB...");
  const TokenB = await ethers.getContractFactory("ERC20Token");
  const tokenB = await TokenB.deploy("Token B", "TKB", 1000000);
  await tokenB.deployed();
  console.log("TokenB部署地址:", tokenB.address);
  console.log("TokenB总供应量:", await tokenB.totalSupply());

  // 3. 部署流动性池
  console.log("\n部署流动性池...");
  const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
  const liquidityPool = await LiquidityPool.deploy(tokenA.address, tokenB.address);
  await liquidityPool.deployed();
  console.log("流动性池部署地址:", liquidityPool.address);

  // 4. 给流动性池授权
  console.log("\n授权TokenA给流动性池...");
  await tokenA.approve(liquidityPool.address, ethers.utils.parseUnits("500000", 18));
  
  console.log("授权TokenB给流动性池...");
  await tokenB.approve(liquidityPool.address, ethers.utils.parseUnits("500000", 18));

  // 5. 添加初始流动性
  console.log("\n添加初始流动性...");
  const amountA = ethers.utils.parseUnits("100000", 18);
  const amountB = ethers.utils.parseUnits("100000", 18);
  
  await liquidityPool.addLiquidity(amountA, amountB);
  console.log("已添加流动性:");
  console.log("- TokenA:", ethers.utils.formatUnits(amountA, 18));
  console.log("- TokenB:", ethers.utils.formatUnits(amountB, 18));

  // 6. 获取流动性池信息
  const [reserve0, reserve1] = await liquidityPool.getReserves();
  console.log("\n流动性池当前储备:");
  console.log("- TokenA储备:", ethers.utils.formatUnits(reserve0, 18));
  console.log("- TokenB储备:", ethers.utils.formatUnits(reserve1, 18));
  console.log("- LP代币总供应量:", ethers.utils.formatUnits(await liquidityPool.totalSupply(), 18));

  console.log("\n✅ 部署完成!");
  console.log("\n部署信息:");
  console.log("TokenA地址:", tokenA.address);
  console.log("TokenB地址:", tokenB.address);
  console.log("流动性池地址:", liquidityPool.address);
  console.log("部署账户:", deployer.address);

  return {
    tokenA: tokenA.address,
    tokenB: tokenB.address,
    liquidityPool: liquidityPool.address,
    deployer: deployer.address
  };
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("部署失败:", error);
    process.exit(1);
  });