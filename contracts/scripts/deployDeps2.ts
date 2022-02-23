// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
  const [signer] = await ethers.getSigners()
  const options = {nonce: await signer.getTransactionCount()};
  
  // deploy Joe Router
  const JoeRouter02 = await ethers.getContractFactory("JoeRouter02");
  const joeRouter02 = await JoeRouter02.deploy("0x520D96c33403ff2ceA8a0E06B3f76b2BD6341108", "0x29cb3a8160275d8c49BA2a216F6438520a395719", options); //ropsten JoeFactory and WAVAX
  await joeRouter02.deployed();
  console.log(`Coin deployed to: ${joeRouter02.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
