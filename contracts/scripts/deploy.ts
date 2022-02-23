// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
  const options = {gasPrice: 25000000000, gasLimit: 8000000};
  const DefiSyndicate = await ethers.getContractFactory("DefiSyndicateV2");
  const defiSyndicate = await DefiSyndicate.deploy("0xE54Ca86531e17Ef3616d22Ca28b0D458b6C89106", "0x0fe2454716e3356B752af87eE064d1e1A5cA6A81", options);
  await defiSyndicate.deployed();
  console.log(`Coin deployed to: ${defiSyndicate.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
