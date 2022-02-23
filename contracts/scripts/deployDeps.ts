// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
  const [signer] = await ethers.getSigners()
  console.log("transaction count: " + await signer.getTransactionCount())
  const options = {nonce: await signer.getTransactionCount()};
  // deploy WAVAX
  const WAVAX = await ethers.getContractFactory("WAVAX9Mock");
  const wavax = await WAVAX.deploy(options);
  await wavax.deployed();
  console.log("wavax address: " + await wavax.address);

  // deploy JoeFactory
  const factoryOptions = {nonce: await signer.getTransactionCount()};
  const JoeFactory = await ethers.getContractFactory("JoeFactory");
  const joeFactory = await JoeFactory.deploy(signer.address, factoryOptions);
  await joeFactory.deployed();

  console.log("pairCodeHash: " + await joeFactory.pairCodeHash());
  console.log("router address: " + await joeFactory.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
