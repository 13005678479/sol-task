const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
    console.log("Starting MetaNode Staking deployment...");
    
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    
    const balance = await deployer.getBalance();
    console.log("Account balance:", ethers.utils.formatEther(balance));
    
    // 1. Deploy MetaNode Token
    console.log("\n1. Deploying MetaNode Token...");
    const MetaNodeToken = await ethers.getContractFactory("MetaNodeToken");
    const metaNodeToken = await MetaNodeToken.deploy(
        "MetaNode Token",           // name
        "METANODE",                // symbol
        ethers.utils.parseEther("1000000"), // initial supply 1M
        ethers.utils.parseEther("10000000") // max supply 10M
    );
    await metaNodeToken.deployed();
    console.log("MetaNode Token deployed to:", metaNodeToken.address);
    
    // 2. Deploy a sample ERC20 Reward Token for testing
    console.log("\n2. Deploying Sample Reward Token...");
    const RewardToken = await ethers.getContractFactory("MetaNodeToken");
    const rewardToken = await RewardToken.deploy(
        "Sample Reward Token",
        "REWARD",
        ethers.utils.parseEther("100000000"), // 100M initial supply
        ethers.utils.parseEther("1000000000") // 1B max supply
    );
    await rewardToken.deployed();
    console.log("Sample Reward Token deployed to:", rewardToken.address);
    
    // 3. Deploy MetaNode Staking Contract
    console.log("\n3. Deploying MetaNode Staking Contract...");
    const MetaNodeStaking = await ethers.getContractFactory("MetaNodeStaking");
    const currentBlock = await ethers.provider.getBlockNumber();
    
    const metaNodeStaking = await MetaNodeStaking.deploy(
        metaNodeToken.address,
        ethers.utils.parseEther("1"), // 1 METANODE per block
        currentBlock + 1             // Start next block
    );
    await metaNodeStaking.deployed();
    console.log("MetaNode Staking deployed to:", metaNodeStaking.address);
    
    // 4. Add staking pools
    console.log("\n4. Adding staking pools...");
    
    // Pool 1: Native ETH (using WETH for testing)
    const wethAddress = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"; // Mainnet WETH
    
    // For Sepolia testing, we'll use the reward token as staking token
    console.log("Adding ETH pool...");
    const ethPoolTx = await metaNodeStaking.addPool(
        rewardToken.address,     // Using reward token as staking token for ETH pool
        100,                    // Pool weight
        ethers.utils.parseEther("0.1"), // Min deposit: 0.1 ETH equivalent
        100                     // Lock period: 100 blocks
    );
    await ethPoolTx.wait();
    console.log("ETH pool added");
    
    // Pool 2: ERC20 Token pool
    console.log("Adding ERC20 pool...");
    const erc20PoolTx = await metaNodeStaking.addPool(
        rewardToken.address,     // Same token for simplicity
        50,                     // Pool weight
        ethers.utils.parseEther("100"), // Min deposit: 100 tokens
        200                     // Lock period: 200 blocks
    );
    await erc20PoolTx.wait();
    console.log("ERC20 pool added");
    
    // 5. Transfer some tokens to staking contract for rewards
    console.log("\n5. Funding staking contract with rewards...");
    const fundAmount = ethers.utils.parseEther("100000"); // 100K tokens for rewards
    await metaNodeToken.transfer(metaNodeStaking.address, fundAmount);
    console.log("Funded staking contract with:", ethers.utils.formatEther(fundAmount), "METANODE tokens");
    
    // 6. Approve tokens for staking (deployer approval)
    console.log("\n6. Approving tokens for staking...");
    const approveAmount = ethers.utils.parseEther("10000"); // 10K tokens
    await rewardToken.approve(metaNodeStaking.address, approveAmount);
    console.log("Approved tokens for staking");
    
    // 7. Save deployment info
    const deploymentInfo = {
        network: hre.network.name,
        deployer: deployer.address,
        contracts: {
            metaNodeToken: metaNodeToken.address,
            rewardToken: rewardToken.address,
            metaNodeStaking: metaNodeStaking.address
        },
        deploymentBlock: currentBlock,
        timestamp: new Date().toISOString()
    };
    
    console.log("\n=== DEPLOYMENT SUMMARY ===");
    console.log(JSON.stringify(deploymentInfo, null, 2));
    
    // Save to file
    const fs = require("fs");
    fs.writeFileSync(
        `deployment-${hre.network.name}.json`,
        JSON.stringify(deploymentInfo, null, 2)
    );
    
    console.log("\nDeployment info saved to deployment.json");
    
    return deploymentInfo;
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });