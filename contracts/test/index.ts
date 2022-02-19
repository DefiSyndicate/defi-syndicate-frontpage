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
  });
  

  it("Should Initialize", async () => {
    await expect(await defiSyndicate.name()).to.equal("DefiSyndicate");
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
    const tokenAmount = 7650000 * decimals; //85% of total supply
    await defiSyndicate.approve(joeRouter02.address, tokenAmount);
    await wavax.approve(joeRouter02.address, ethers.utils.parseEther("90"));
    joeRouter02.addLiquidityAVAX(defiSyndicate.address, tokenAmount, 0, 0, owner.address, Date.now()+3600, options);
    await expect(await wavax.balanceOf(owner.address)).to.equal(ethers.utils.parseEther("500.0"));
  });

  it("Should Buy SIN", async () => {
    const tokenAmount = 7650000 * decimals;
    const options = {value: ethers.utils.parseEther("0.5")};
    const path = [wavax.address, defiSyndicate.address];
    await defiSyndicate.approve(joeRouter02.address, tokenAmount);
    await wavax.approve(joeRouter02.address, tokenAmount);
    await wavax.connect(secondary).approve(joeRouter02.address, ethers.utils.parseEther("85.0"));
    await joeRouter02.connect(secondary).swapExactAVAXForTokens(0, path, secondary.address, Date.now()+3600, options);
    await expect(await defiSyndicate.balanceOf(secondary.address)).to.equal(35833340128263);
  });

  it("Should have reflections", async () => {
    //console.log("total reflections: " + await defiSyndicate.totalFees());
    expect(await defiSyndicate.totalFees()).to.equal(3792518660530);
  });

  it("Should Have Marketing Balance", async () => {
    expect(await defiSyndicate.balanceOf(ecosystem.address)).to.equal(2528345773686);
  });

  it("Transfers between wallets should not incur fee", async () => {
    const xferAmount = 200 * decimals;
    await defiSyndicate.transfer(tertiary.address, xferAmount);
    expect(await defiSyndicate.balanceOf(tertiary.address)).to.equal(xferAmount);
  });

  it("Should be able to sell through TJ", async () => {
    //uint256 amountIn,
    //uint256 amountOutMin,
    //address[] calldata path,
    //address to,
    //uint256 deadline
    const xferAmount = 200 * decimals;
    const path = [defiSyndicate.address, wavax.address];
    await defiSyndicate.connect(tertiary).approve(joeRouter02.address, xferAmount);
    await joeRouter02.connect(tertiary).swapExactTokensForAVAXSupportingFeeOnTransferTokens(xferAmount, 0, path, tertiary.address, Date.now()+3600);
    console.log(await defiSyndicate.balanceOf(tertiary.address));
  });

});
