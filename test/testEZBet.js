const { expect } = require("chai");
const { ethers } = require("hardhat");
const {abi, bytecode} = require("usingtellor/artifacts/contracts/TellorPlayground.sol/TellorPlayground.json");

describe("Test EZBet", function() {
  let ezbet;
  let tellorOracle;
  const abiCoder = new ethers.utils.AbiCoder();
  // generate queryData and queryId for eth/usd price
  const noArgs = abiCoder.encode(["string"], ["No"]);
  const yesArgs = abiCoder.encode(["string"], ["Yes"]);
  const _myQ = "Did Levan win EvW12 vs Devon?"
  const questionArgs = abiCoder.encode(["string"], [_myQ]);
  const EZBET_QUERY_DATA = abiCoder.encode(["string", "bytes"], ["StringQuery", questionArgs]);
  const EZBET_QUERY_ID = ethers.utils.keccak256(EZBET_QUERY_DATA);
  let iBal;

  // Set up Tellor Playground Oracle and SampleUsingTellor
  beforeEach(async function () {
    let accounts = await ethers.getSigners();
    iBal = await ethers.provider.getBalance(accounts[0].address);
    console.log(iBal);
    let TellorOracle = await ethers.getContractFactory(abi, bytecode);
    tellorOracle = await TellorOracle.deploy();
    await tellorOracle.deployed();

    let blockNumBefore = await ethers.provider.getBlockNumber();
    let  blockBefore = await ethers.provider.getBlock(blockNumBefore);
    let _myEndDate = blockBefore.timestamp + 86400*3;

    let Ezbet = await ethers.getContractFactory("EZBet");
    ezbet = await Ezbet.deploy(tellorOracle.address, _myQ,BigInt(1e18),BigInt(1e18),_myEndDate,{value:BigInt(2e18)});
    await ezbet.deployed();
  });

  it("constructor", async function() {

  });
  // it("betOnNo", async function() {

  // };
  // it("betOnYes", async function() {

  // };
  // it("settleBett", async function() {

  // };
  // it("claimWinnings", async function() {

  // };
  // it("getSettlementStatus", async function() {

  // }
  // it("getCurrentOdds", async function() {

  // };
  // it("full Yes", async function() {
  //   //place a bet on each side (verify bets are properly tracked)
  //   // fast forward
  //   //settle bet (verify correct outcomes / variable changes)
  //   //claim winnings (verify proper payments)

  //   await tellorOracle.submitValue(EZBET_QUERY_ID, yesArgs, 0, EZBET_QUERY_DATA);
  //   // advance block timestamp by 15 minutes to allow our value to be retrieved
  //   await ethers.provider.send("evm_increaseTime", [901]);
  //   await ethers.provider.send("evm_mine");
  //   // retrieve value from playground in our sample contract
  //   await sampleUsingTellor.readEthPrice();
  //   // read our saved value from the sample contract
  //   const retrievedVal = await sampleUsingTellor.ethPrice();
  //   expect(BigInt(retrievedVal)).to.equal(mockValue);
  // })

  // it("full No", async function() {
  //   // mock value to report
  //   const mockValue1 = BigInt(2000e18);
  //   const mockValue2 = BigInt(3000e18);
  //   const mockValue3 = BigInt(4000e18);
  //   // convert to bytes
  //   const mockValue1Bytes = abiCoder.encode(["uint256"], [mockValue1]);
  //   const mockValue2Bytes = abiCoder.encode(["uint256"], [mockValue2]);
  //   const mockValue3Bytes = abiCoder.encode(["uint256"], [mockValue3]);
  //   // submit value to playground
  //   await tellorOracle.submitValue(ETH_USD_QUERY_ID, mockValue1Bytes, 0, ETH_USD_QUERY_DATA);
  //   blocky1 = await ethers.provider.getBlock();
  //   await tellorOracle.submitValue(ETH_USD_QUERY_ID, mockValue2Bytes, 0, ETH_USD_QUERY_DATA);
  //   blocky2 = await ethers.provider.getBlock();

  //   // without advancing time, value should be 0
  //   await sampleUsingTellor.readEthPrice();
  //   let retrievedVal = await sampleUsingTellor.ethPrice();
  //   expect(BigInt(retrievedVal)).to.equal(0n);

  //   // advance time to 15 minutes
  //   await ethers.provider.send("evm_increaseTime", [901]);
  //   await ethers.provider.send("evm_mine");

  //   // ethPrice should be second submitted value
  //   await sampleUsingTellor.readEthPrice();
  //   retrievedVal = await sampleUsingTellor.ethPrice();
  //   expect(BigInt(retrievedVal)).to.equal(mockValue2);

  //   // dispute second value
  //   await tellorOracle.beginDispute(ETH_USD_QUERY_ID, blocky2.timestamp)

  //   // ethPrice should still be second submitted value
  //   await sampleUsingTellor.readEthPrice();
  //   retrievedVal = await sampleUsingTellor.ethPrice();
  //   expect(BigInt(retrievedVal)).to.equal(mockValue2);

  //   // submit third value
  //   await tellorOracle.submitValue(ETH_USD_QUERY_ID, mockValue3Bytes, 0, ETH_USD_QUERY_DATA);

  //   // advance time to 15 minutes
  //   await ethers.provider.send("evm_increaseTime", [901]);

  //   // ethPrice should be third submitted value
  //   await sampleUsingTellor.readEthPrice();
  //   retrievedVal = await sampleUsingTellor.ethPrice();
  //   expect(BigInt(retrievedVal)).to.equal(mockValue3);
  // })
});
