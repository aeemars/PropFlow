const fs = require("fs");
const path = require("path");
const { ethers } = require("ethers");

// Manually parse .env file
const envPath = path.join(__dirname, ".env");
if (fs.existsSync(envPath)) {
  const envConfig = fs.readFileSync(envPath, "utf8");
  for (const line of envConfig.split("\n")) {
    const parts = line.split("=");
    if (parts.length >= 2) {
      const key = parts[0].trim();
      const val = parts.slice(1).join("=").trim().replace(/^['"]|['"]$/g, "");
      process.env[key] = val;
    }
  }
}

const ARC_RPC      = process.env.ARC_TESTNET_RPC || 'https://rpc.testnet.arc.network';
const ARC_CHAIN_ID = parseInt(process.env.ARC_CHAIN_ID || '5042002');
const KYC_REGISTRY_ADDRESS = process.env.KYC_REGISTRY_ADDRESS;
const ADMIN_PRIVATE_KEY = process.env.ADMIN_PRIVATE_KEY;
const WALLET_ADDRESS_TO_APPROVE = "0x64AC5e8E827B0c95f3134dc0580c6dE455034C51";

if (!KYC_REGISTRY_ADDRESS || !ADMIN_PRIVATE_KEY) {
  console.error("Error: KYC_REGISTRY_ADDRESS and ADMIN_PRIVATE_KEY must be defined in .env");
  process.exit(1);
}

const KYC_ABI = ['function approve(address investor) external', 'function isVerified(address investor) view returns (bool)'];

async function run() {
  console.log(`Connecting to Arc RPC: ${ARC_RPC}...`);
  const provider = new ethers.JsonRpcProvider(ARC_RPC, ARC_CHAIN_ID);
  const signer = new ethers.Wallet(ADMIN_PRIVATE_KEY, provider);

  const kycRegistry = new ethers.Contract(KYC_REGISTRY_ADDRESS, KYC_ABI, signer);

  console.log(`Checking if ${WALLET_ADDRESS_TO_APPROVE} is already verified...`);
  const isAlreadyVerified = await kycRegistry.isVerified(WALLET_ADDRESS_TO_APPROVE);
  console.log("On-chain verification status:", isAlreadyVerified);

  if (isAlreadyVerified) {
    console.log("Address is already verified on-chain!");
    return;
  }

  console.log(`Approving KYC for address ${WALLET_ADDRESS_TO_APPROVE} on-chain...`);
  const tx = await kycRegistry.approve(WALLET_ADDRESS_TO_APPROVE);
  console.log("Transaction sent. Hash:", tx.hash);
  console.log("Waiting for confirmation...");
  const receipt = await tx.wait();
  console.log("Transaction confirmed in block:", receipt.blockNumber);
}

run().catch(console.error);
