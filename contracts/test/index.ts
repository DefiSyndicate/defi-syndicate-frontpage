import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { assert, expect } from "chai";
import { Contract } from "ethers";
import { ethers } from "hardhat";

describe("DefiSyndicate Contract", () => {
  let owner: SignerWithAddress, secondary: SignerWithAddress, ecosystem: SignerWithAddress, tertiary: SignerWithAddress;
  let wavax: Contract;
  let defiSyndicate: Contract;
  let joeRouter02: Contract;
  let joeFactory: Contract;
  let decimals: number = Math.pow(10, 9);
  
  before(async () => {
    // set up the environment
    // get signers
    [owner, secondary, ecosystem, tertiary] = await ethers.getSigners();

    // deploy WAVAX
    const WAVAX = await ethers.getContractFactory("WAVAX9Mock");
    wavax = await WAVAX.deploy();
    await wavax.deployed();

    // deploy JoeFactory
    const JoeFactory = await ethers.getContractFactory("JoeFactory");
    joeFactory = await JoeFactory.deploy(owner.address);
    await joeFactory.deployed();

    console.log("hash: " +await joeFactory.pairCodeHash())
    
    // deploy Joe Router
    const JoeRouter02 = await ethers.getContractFactory("JoeRouter02");
    joeRouter02 = await JoeRouter02.deploy(joeFactory.address, wavax.address);
    await joeRouter02.deployed();

    // deploy DefiSyndicate
    const DefiSyndicate = await ethers.getContractFactory("DefiSyndicate");
    defiSyndicate = await DefiSyndicate.deploy(joeRouter02.address);
    await defiSyndicate.deployed();
    await defiSyndicate.setEcoSystemFeeAddress(0, ecosystem.address);
    await defiSyndicate.setEcoSystemFeeAddress(1, ecosystem.address);
    await defiSyndicate.excludeFromFee(ecosystem.address);
  });
  

  it("Should Initialize", async () => {
    await expect(await defiSyndicate.name()).to.equal("Syndicate ID Number");
    await expect(await defiSyndicate.symbol()).to.equal("SIN");
    const defaultFees = await defiSyndicate._defaultFees();
    //console.log(defaultFees);
  });

  it("Should Wrap AVAX", async () => {
    const options = {value: ethers.utils.parseEther("500.0")};
    await wavax.deposit(options);
    await expect(await wavax.balanceOf(owner.address)).to.equal(ethers.utils.parseEther("500.0"));
  });

  it("Should Deposit In LP", async () => {
    await expect(await wavax.balanceOf(owner.address)).to.equal(ethers.utils.parseEther("500.0"));
    const options = {value: ethers.utils.parseEther("90")};
    const tokenAmount = 7650000 * decimals; // 85% of total supply
    await defiSyndicate.approve(joeRouter02.address, tokenAmount);
    await wavax.approve(joeRouter02.address, ethers.utils.parseEther("90"));
    joeRouter02.addLiquidityAVAX(defiSyndicate.address, tokenAmount, 0, 0, owner.address, Date.now()+3600, options);
    await expect(await wavax.balanceOf(owner.address)).to.equal(ethers.utils.parseEther("500.0"));
  });

  it("Should be able to buy SIN", async () => {
    const tokenAmount = 7650000 * decimals; // max tokens
    const options = {value: ethers.utils.parseEther("0.5")}; // how much ether to spend on SIN
    const path = [wavax.address, defiSyndicate.address]; // path from WAVAX to SIN
    await defiSyndicate.approve(joeRouter02.address, tokenAmount); // approve
    await wavax.approve(joeRouter02.address, tokenAmount);
    await wavax.connect(secondary).approve(joeRouter02.address, ethers.utils.parseEther("85.0"));
    await joeRouter02.connect(secondary).swapExactAVAXForTokens(0, path, secondary.address, Date.now()+3600, options);
    await expect(await defiSyndicate.balanceOf(secondary.address)).to.equal(35818231793898); // balance minus fees
  });

  it("SIN contract SHOULD show no reflections after BUY", async () => {
    //console.log("total reflections: " + await defiSyndicate.totalFees());
    expect(await defiSyndicate.totalFees()).to.equal(0);
  });

  it("SIN contract SHOULD have token balance from reflection", async () => {
    //console.log("total reflections: " + await defiSyndicate.totalFees());
    expect(await defiSyndicate.balanceOf(defiSyndicate.address)).to.equal(3792518660530); // to be converted to avax
  });

  it("Marketing wallet SHOULD have 6% of the BUY total", async () => {
    expect(await defiSyndicate.balanceOf(ecosystem.address)).to.equal(2528345773686);
  });

  it("Transfers between wallets SHOULD NOT incur fee", async () => {
    const xferAmount = 10000 * decimals;
    await defiSyndicate.connect(secondary).transfer(tertiary.address, xferAmount);
    expect(await defiSyndicate.balanceOf(secondary.address)).to.equal(35818231793898 - xferAmount);
    expect(await defiSyndicate.balanceOf(tertiary.address)).to.equal(xferAmount);
  });

  it("Should be able to SELL to AMM", async () => {
    const xferAmount = 10000 * decimals;
    const path = [defiSyndicate.address, wavax.address];
    await defiSyndicate.connect(tertiary).approve(joeRouter02.address, xferAmount);
    await joeRouter02.connect(tertiary).swapExactTokensForAVAXSupportingFeeOnTransferTokens(xferAmount, 0, path, tertiary.address, Date.now()+3600);
    expect(await defiSyndicate.balanceOf(tertiary.address)).to.equal(0);
  });

  // manually burning
  // it("Should burn 6%", async() => {
  //   expect(await defiSyndicate.balanceOf("0x000000000000000000000000000000000000dEaD")).to.equal(12000000000);
  // });

  it("SIN contract SHOULD show no reflections after SELL", async () => {
    expect(await defiSyndicate.totalFees()).to.equal(300000000000);
  });

  it("SIN contract SHOULD NOT have additional balance after SELL", async () => {
    expect(await defiSyndicate.balanceOf(defiSyndicate.address)).to.equal(3792518660530); 
  });

  it("Marketing wallet SHOULD have additional tokens after SELL", async () => {
    expect(await defiSyndicate.balanceOf(ecosystem.address)).to.equal(2552345773686); 
  });

  it("should distribute rewards", async () => {
    console.log(await defiSyndicate.distributorAddress());

  });


});
