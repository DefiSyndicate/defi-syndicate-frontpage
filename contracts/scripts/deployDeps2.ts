// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
  const [signer] = await ethers.getSigners()
  const options = {gasPrice: 25000000000, gasLimit: 8000000, nonce: await signer.getTransactionCount()};
  
  // deploy Joe Router
  const JoeRouter02 = await ethers.getContractFactory("JoeRouter02");
  const joeRouter02 = await JoeRouter02.deploy("", "", options);
  await joeRouter02.deployed();
  console.log(`Coin deployed to: ${joeRouter02.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
