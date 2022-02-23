// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
  const [signer] = await ethers.getSigners()
  const options = {gasPrice: 25000000000, gasLimit: 8000000, nonce: await signer.getTransactionCount()};
  const DefiSyndicate = await ethers.getContractFactory("DefiSyndicateV2");
  //dev
  const defiSyndicate = await DefiSyndicate.deploy("0x9816150896217D551EbD8fD1fA62F479AeE4AAF4", "0x0fe2454716e3356B752af87eE064d1e1A5cA6A81", options); //ropsten router and marketing addy
  //prod
  //const defiSyndicate = await DefiSyndicate.deploy("0x60aE616a2155Ee3d9A68541Ba4544862310933d4", "0xa0E609C0fB8605E5C2AfaaaD99C332aA36F1Cb99", options); //ropsten router and marketing addy
  
  await defiSyndicate.deployed();
  console.log(`Coin deployed to: ${defiSyndicate.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
