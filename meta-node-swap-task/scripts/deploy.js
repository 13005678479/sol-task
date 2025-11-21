const { ethers } = require("hardhat");

async function main() {
  console.log("开始部署合约...");

  // 获取部署账户
  const [deployer] = await ethers.getSigners();
  console.log("部署账户:", deployer.address);
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("账户余额:", ethers.formatEther(balance), "ETH");

  // 1. 部署TokenA
  console.log("\n部署TokenA...");
  const TokenA = await ethers.getContractFactory("ERC20Token");
  const tokenA = await TokenA.deploy("Token A", "TKA", 1000000);
  console.log("TokenA部署地址:", await tokenA.getAddress());
  console.log("TokenA总供应量:", await tokenA.totalSupply());

  // 2. 部署TokenB
  console.log("\n部署TokenB...");
  const TokenB = await ethers.getContractFactory("ERC20Token");
  const tokenB = await TokenB.deploy("Token B", "TKB", 1000000);
  console.log("TokenB部署地址:", await tokenB.getAddress());
  console.log("TokenB总供应量:", await tokenB.totalSupply());

  // 3. 部署流动性池
  console.log("\n部署流动性池...");
  const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
  const liquidityPool = await LiquidityPool.deploy(await tokenA.getAddress(), await tokenB.getAddress());
  console.log("流动性池部署地址:", await liquidityPool.getAddress());

  // 4. 给流动性池授权
  console.log("\n授权TokenA给流动性池...");
  await tokenA.approve(await liquidityPool.getAddress(), ethers.parseUnits("500000", 18));
  
  console.log("授权TokenB给流动性池...");
  await tokenB.approve(await liquidityPool.getAddress(), ethers.parseUnits("500000", 18));

  // 5. 添加初始流动性
  console.log("\n添加初始流动性...");
  const amountA = ethers.parseUnits("100000", 18);
  const amountB = ethers.parseUnits("100000", 18);
  
  await liquidityPool.addLiquidity(amountA, amountB);
  console.log("已添加流动性:");
  console.log("- TokenA:", ethers.formatUnits(amountA, 18));
  console.log("- TokenB:", ethers.formatUnits(amountB, 18));

  // 6. 获取流动性池信息
  const [reserve0, reserve1] = await liquidityPool.getReserves();
  console.log("\n流动性池当前储备:");
  console.log("- TokenA储备:", ethers.formatUnits(reserve0, 18));
  console.log("- TokenB储备:", ethers.formatUnits(reserve1, 18));
  console.log("- LP代币总供应量:", ethers.formatUnits(await liquidityPool.totalSupply(), 18));

  console.log("\n✅ 部署完成!");
  console.log("\n部署信息:");
  console.log("TokenA地址:", await tokenA.getAddress());
  console.log("TokenB地址:", await tokenB.getAddress());
  console.log("流动性池地址:", await liquidityPool.getAddress());
  console.log("部署账户:", deployer.address);

  return {
    tokenA: await tokenA.getAddress(),
    tokenB: await tokenB.getAddress(),
    liquidityPool: await liquidityPool.getAddress(),
    deployer: deployer.address
  };
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("部署失败:", error);
    process.exit(1);
  });