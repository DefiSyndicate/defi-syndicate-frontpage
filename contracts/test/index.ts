import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { assert, expect } from "chai";
import { Contract } from "ethers";
import { ethers } from "hardhat";

describe("DefiSyndicate Contract", () => {
  let owner: SignerWithAddress, secondary: SignerWithAddress;
  let wavax: Contract;
  let defiSyndicate: Contract;
  let joeRouter02: Contract;
  
  before(async () => {
    // set up the environment
    // get signers
    [owner, secondary] = await ethers.getSigners();

    // deploy WAVAX
    const WAVAX = await ethers.getContractFactory("WAVAX");
    wavax = await WAVAX.deploy();
    await wavax.deployed();

    // deploy JoeFactory
    const JoeFactory = await ethers.getContractFactory("JoeFactory");
    const joeFactory = await JoeFactory.deploy(owner.address);
    await joeFactory.deployed();
    
    // deploy Joe Router
    const JoeRouter02 = await ethers.getContractFactory("JoeRouter02");
    joeRouter02 = await JoeRouter02.deploy(joeFactory.address, wavax.address);
    await joeRouter02.deployed();

    // deploy DefiSyndicate
    const DefiSyndicate = await ethers.getContractFactory("DefiSyndicate");
    defiSyndicate = await DefiSyndicate.deploy(joeRouter02.address);
    await defiSyndicate.deployed();
  });
  

  it("Should Initialize", async () => {
    await expect(await defiSyndicate.name()).to.equal("DefiSyndicate");
    await expect(await defiSyndicate.symbol()).to.equal("SIN");
  });

  it("Should Wrap AVAX", async () => {
    const options = {value: ethers.utils.parseEther("500.0")};
    wavax.deposit(options);
    await expect(await wavax.balanceOf(owner.address)).to.equal(ethers.utils.parseEther("500.0"));
  });

  it("Should Deposit In LP", async () => {
    await expect(await wavax.balanceOf(owner.address)).to.equal(ethers.utils.parseEther("500.0"));
    const LPPair = await defiSyndicate.uniswapV2Pair();
    const amoutADesired = ethers.utils.parseEther("85.00");
    const amoutbDesired = ethers.utils.parseEther("7650000.00");
    joeRouter02.addLiquidity(wavax.address, defiSyndicate.address, amoutADesired, amoutbDesired, 0, 0, LPPair, Date.now()+3600);
    await expect(await wavax.balanceOf(owner.address)).to.equal(ethers.utils.parseEther("500.0"));
  });


});
