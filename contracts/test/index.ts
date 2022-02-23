import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { assert, expect } from "chai";
import { BigNumber, Contract } from "ethers";
import { ethers, waffle } from "hardhat";

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
    const DefiSyndicate = await ethers.getContractFactory("DefiSyndicateV2");
    defiSyndicate = await DefiSyndicate.deploy(joeRouter02.address, ecosystem.address);
    await defiSyndicate.deployed();
  });

  it("Should Initialize", async () => {
    expect(await defiSyndicate.name()).to.equal("Syndicate ID Number");
    expect(await defiSyndicate.symbol()).to.equal("SIN");
    expect(await defiSyndicate.marketingFeeReceiver()).to.equal(ecosystem.address);
  });

  it("Should Wrap AVAX", async () => {
    const options = {value: ethers.utils.parseEther("500.0")};
    await wavax.deposit(options);
    expect(await wavax.balanceOf(owner.address)).to.equal(ethers.utils.parseEther("500.0"));
  });

  it("Should Deposit In LP", async () => {
    expect(await wavax.balanceOf(owner.address)).to.equal(ethers.utils.parseEther("500.0"));
    const options = {value: ethers.utils.parseEther("93")}; //
    const tokenAmount = 7200000 * decimals; // 85% of total supply
    await defiSyndicate.approve(joeRouter02.address, tokenAmount);
    await wavax.approve(joeRouter02.address, ethers.utils.parseEther("90"));
    joeRouter02.addLiquidityAVAX(defiSyndicate.address, tokenAmount, 0, 0, owner.address, Date.now()+3600, options);
    expect(await wavax.balanceOf(owner.address)).to.equal(ethers.utils.parseEther("500.0"));
  });

  it("Should be able to buy SIN", async () => {
    const tokenAmount = 7650000 * decimals; // max tokens
    const options = {value: ethers.utils.parseEther("0.5")}; // how much ether to spend on SIN
    const path = [wavax.address, defiSyndicate.address]; // path from WAVAX to SIN
    await defiSyndicate.approve(joeRouter02.address, tokenAmount); // approve
    await wavax.approve(joeRouter02.address, tokenAmount);
    await wavax.connect(secondary).approve(joeRouter02.address, ethers.utils.parseEther("85.0"));
    await joeRouter02.connect(secondary).swapExactAVAXForTokens(0, path, secondary.address, Date.now()+3600, options);
    expect(await defiSyndicate.balanceOf(secondary.address)).to.equal(35818231793897); // balance minus fees
  });

  it("SIN contract SHOULD show reflections after BUY", async () => {
    //console.log("total reflections: " + await defiSyndicate.totalFees());
    expect(await defiSyndicate.balanceOf(defiSyndicate.address)).to.equal(6320864434217); // full 15% tax should be in here right now
  });

  it("OVER 9000!!!! tokens should not trigger swap and distribution on buys", async () => {
    const options = {value: ethers.utils.parseEther("0.5")}; // how much ether to spend on SIN
    const path = [wavax.address, defiSyndicate.address]; // path from WAVAX to SIN
    await joeRouter02.connect(tertiary).swapExactAVAXForTokens(0, path, tertiary.address, Date.now()+3600, options);
    expect(await defiSyndicate.balanceOf(tertiary.address)).to.equal(35425208783120); // balance minus fees
    expect(await defiSyndicate.balanceOf(ecosystem.address)).to.equal(0); // balance minus fees
  });

  it("Transfers between wallets SHOULD NOT incur fee", async () => {
    const xferAmount = 10000 * decimals;
    await defiSyndicate.connect(secondary).transfer(tertiary.address, xferAmount);
    expect(await defiSyndicate.balanceOf(secondary.address)).to.equal(35818231793897 - xferAmount);
    expect(await defiSyndicate.balanceOf(tertiary.address)).to.equal(xferAmount + 35425208783120);
  });

  it("Should be able to SELL to AMM (should trigger distribution)", async () => {
    const beforeBalance = await ecosystem.getBalance();
    const xferAmount = 10000 * decimals;
    const path = [defiSyndicate.address, wavax.address];
    await defiSyndicate.connect(tertiary).approve(joeRouter02.address, xferAmount);
    await joeRouter02.connect(tertiary).swapExactTokensForAVAXSupportingFeeOnTransferTokens(xferAmount, 0, path, tertiary.address, Date.now()+3600);
    expect(await defiSyndicate.balanceOf(tertiary.address)).to.equal(35425208783120);
    expect(await ecosystem.getBalance()).to.be.above(beforeBalance);
  });

  it("SHOULD be able to handle LOTs of accounts", async () => {
    const signers = await ethers.getSigners();
    const tokenAmount = 7650000 * decimals; // max tokens
    const options = {value: ethers.utils.parseEther("1")}; // how much ether to spend on SIN
    const path = [wavax.address, defiSyndicate.address]; // path from WAVAX to SIN
    const provider = waffle.provider;

    const buyNow = (i: number) => {
      console.log("buying with: " + i);
      return wavax.connect(signers[i]).approve(joeRouter02.address, ethers.utils.parseEther("85.0"))
      .then(joeRouter02.connect(signers[i]).swapExactAVAXForTokens(0, path, signers[i].address, Date.now()+3600, options))
      .then(owner.getBalance())
      .then(setTimeout(console.log, 1000, i + " finished."));
    }

    const sellNow = (i: number) => {
      const path = [defiSyndicate.address, wavax.address];
      return defiSyndicate.balanceOf(signers[i - 1].address)
        .then((balance: number) => { 
          console.log(`balanceOf ${i - 1}: ` + balance);
          return ([defiSyndicate.connect(signers[i - 1]).approve(joeRouter02.address, balance), balance])
        })
        .then(([contractRes, balance]: any) => {
          console.log(`balanceOf ${i - 1}: ` + balance);
          joeRouter02.connect(signers[i - 1]).swapExactTokensForAVAXSupportingFeeOnTransferTokens(balance, 0, path, signers[i].address, Date.now()+3600)
        });
    }
    let res;
    let distributorBalance: BigNumber = BigNumber.from("0");
    let lastDistributorBalance: BigNumber = BigNumber.from("0");
    for(let i=4; i <= signers.length; i++){
      //await defiSyndicate.approve(joeRouter02.address, tokenAmount); // approve
      //await wavax.approve(joeRouter02.address, tokenAmount);
      if(i % 5 == 0 && i != 5){
        res = await sellNow(i);
      }else{
        res = await buyNow(i);
      }
      await new Promise(r => setTimeout(r, 500));


      console.log("owner: " + await owner.getBalance());
      console.log("secondary: " + await secondary.getBalance());
      console.log("tertiary: " + await tertiary.getBalance());
      console.log("ecosystem: " + await ecosystem.getBalance());
      console.log("rando 5: " + await signers[4].getBalance());
      console.log("rando 9: " + await signers[8].getBalance());
      console.log("rando 11: " + await signers[10].getBalance());
      distributorBalance = await provider.getBalance(defiSyndicate.distributorAddress());
      if(lastDistributorBalance != null && distributorBalance > lastDistributorBalance) console.log("INCREASED DISTRIBUTOR BALANCE NOW!!!!!!");
      if(lastDistributorBalance != null && distributorBalance < lastDistributorBalance) console.log("*************DECREASED DISTRIBUTOR BALANCE NOW!!!!!!");
      console.log("Distributor: " + distributorBalance);
      lastDistributorBalance = distributorBalance;
    }
  });


});

