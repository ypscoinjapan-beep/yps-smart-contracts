const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  
  console.log("🚀 Starting YPS Staking Contracts Deployment...");
  console.log("📋 Deployer Address:", deployer.address);
  console.log("💰 Deployer Balance:", ethers.utils.formatEther(await deployer.getBalance()), "BNB");
  
  const TREASURY_ADDRESS = "0x0aca7c8998cb357a74a879f5b665ef4aec306448";
  const USDT_ADDRESS = "0x55d398326f99059fF775485246999027B3197955";
  
  console.log("\n📦 Configuration:");
  console.log("🏦 Treasury Address:", TREASURY_ADDRESS);
  console.log("💵 USDT Address:", USDT_ADDRESS);
  
  try {
    console.log("\n🔨 Deploying USDT Staking Contract...");
    const USDTStaking = await ethers.getContractFactory("YPSUSDTStaking");
    const usdtStaking = await USDTStaking.deploy(USDT_ADDRESS, TREASURY_ADDRESS);
    await usdtStaking.deployed();
    
    console.log("✅ USDT Staking deployed to:", usdtStaking.address);
    
    console.log("\n🔨 Deploying BNB Staking Contract...");
    const BNBStaking = await ethers.getContractFactory("YPSBNBStaking");
    const bnbStaking = await BNBStaking.deploy(TREASURY_ADDRESS);
    await bnbStaking.deployed();
    
    console.log("✅ BNB Staking deployed to:", bnbStaking.address);
    
    console.log("\n🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!");
    console.log("=========================================");
    console.log("📋 Contract Addresses:");
    console.log("💵 USDT Staking:", usdtStaking.address);
    console.log("🔥 BNB Staking:", bnbStaking.address);
    console.log("🏦 Treasury:", TREASURY_ADDRESS);
    console.log("👤 Deployer:", deployer.address);
    console.log("=========================================");
    
    const addresses = {
      USDT_STAKING: usdtStaking.address,
      BNB_STAKING: bnbStaking.address,
      TREASURY: TREASURY_ADDRESS,
      DEPLOYER: deployer.address,
      NETWORK: "BSC Mainnet"
    };
    
    console.log("\n💾 Addresses saved for reference:");
    console.log(JSON.stringify(addresses, null, 2));
    
  } catch (error) {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });