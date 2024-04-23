const chai = require("chai");
const { solidity } = require("ethereum-waffle");
chai.use(solidity);
const { expect, assert } = chai;
const { ethers } = require("hardhat");
const {abi, bytecode} = require("usingtellor/artifacts/contracts/TellorPlayground.sol/TellorPlayground.json");
const h = require("./helpers/helpers");
describe("Test EZBet", function() {
  let ezbet;
  let tellorOracle;
  const abiCoder = new ethers.utils.AbiCoder();
  // generate queryData and queryId for eth/usd price
  const noArgs = abiCoder.encode(["string"], ["No"]);
  const yesArgs = abiCoder.encode(["string"], ["Yes"]);
  const unArgs = abiCoder.encode(["string"], ["Unresolved"]);
  const _myQ = "Did Levan win EvW12 vs Devon?"
  const questionArgs = abiCoder.encode(["string"], [_myQ]);
  const EZBET_QUERY_DATA = abiCoder.encode(["string", "bytes"], ["StringQuery", questionArgs]);
  const EZBET_QUERY_ID = ethers.utils.keccak256(EZBET_QUERY_DATA);
  let Ezbet, iBal, _myEndDate, accounts;

  // Set up Tellor Playground Oracle and SampleUsingTellor
  beforeEach(async function () {
    accounts = await ethers.getSigners();
    iBal = await ethers.provider.getBalance(accounts[0].address);
    let TellorOracle = await ethers.getContractFactory(abi, bytecode);
    tellorOracle = await TellorOracle.deploy();
    await tellorOracle.deployed();
    let blockNumBefore = await ethers.provider.getBlockNumber();
    let  blockBefore = await ethers.provider.getBlock(blockNumBefore);
    _myEndDate = blockBefore.timestamp + 86400*3;
    Ezbet = await ethers.getContractFactory("EZBet");
    ezbet = await Ezbet.connect(accounts[0]).deploy(tellorOracle.address, _myQ,BigInt(1e18),BigInt(1e18),_myEndDate,{value:BigInt(2e18)});
    await ezbet.deployed();
  });

  it("constructor", async function() {
    assert(await ezbet.question.call() == _myQ, "question should be the same")
    assert(await ezbet.endDate.call() == _myEndDate, "end date should match")
    let newBal = await ethers.provider.getBalance(accounts[0].address);
    assert(BigInt(iBal - newBal) - BigInt(2e18) > 0)
    assert(BigInt(iBal - newBal) - BigInt(2e18) < BigInt(3e16))//little wiggle room for gas
    assert(await ezbet.tellor() == tellorOracle.address, "tellor should be set properly");
    assert(await ezbet.yesBets.call() == BigInt(1e18))
    assert(await ezbet.noBets.call() == BigInt(1e18))
  });
  it("betOnNo", async function() {
    let iBal1 = await ethers.provider.getBalance(accounts[1].address);
    await ezbet.connect(accounts[1]).betOnNo({value:BigInt(4e18)})
    let newBal = await ethers.provider.getBalance(accounts[1].address);
    assert(BigInt(iBal1 - newBal) - BigInt(4e18) > 0)
    assert(BigInt(iBal1 - newBal) - BigInt(4e18) < BigInt(3e16))//little wiggle room for gas
    let _val = await ezbet.addyToNo(accounts[1].address)
    assert(_val == BigInt(4e18), "val should be right")
    assert(await ezbet.noBets.call() == BigInt(5e18), "noBets should be right")
  });
  it("betOnYes", async function() {
    let iBal1 = await ethers.provider.getBalance(accounts[2].address);
    await ezbet.connect(accounts[2]).betOnYes({value:BigInt(4e18)})
    let newBal = await ethers.provider.getBalance(accounts[2].address);
    assert(BigInt(iBal1 - newBal) - BigInt(4e18) > 0)
    assert(BigInt(iBal1 - newBal) - BigInt(4e18) < BigInt(3e16))//little wiggle room for gas
    let _val = await ezbet.addyToYes(accounts[2].address)
    assert(_val == BigInt(4e18), "val should be right")
    assert(await ezbet.yesBets.call() == BigInt(5e18), "yesBets should be right")
  });
  it("settleBet", async function() {
    await ezbet.connect(accounts[1]).betOnNo({value:BigInt(4e18)})
    await ezbet.connect(accounts[2]).betOnYes({value:BigInt(4e18)})
    // advance block timestamp by 15 minutes to allow our value to be retrieved
    await ethers.provider.send("evm_increaseTime", [86400 * 3.5]);
    await ethers.provider.send("evm_mine");
    await tellorOracle.submitValue(EZBET_QUERY_ID, yesArgs, 0, EZBET_QUERY_DATA);
    await ethers.provider.send("evm_increaseTime", [86400 + 100]);
    await ethers.provider.send("evm_mine");
    await ezbet.settleBet();
    assert(await ezbet.yesWins.call(), "yes should win")
    assert(await ezbet.unresolved.call() == false, "should be resolved")
    assert(await ezbet.settled.call(), "should be settled")
  });
  it("claimWinnings", async function() {
    await ezbet.connect(accounts[1]).betOnYes({value:BigInt(4e18)})
    await ezbet.connect(accounts[2]).betOnNo({value:BigInt(4e18)})
    // advance block timestamp by 15 minutes to allow our value to be retrieved
    await ethers.provider.send("evm_increaseTime", [86400 * 3.5]);
    await ethers.provider.send("evm_mine");
    await tellorOracle.submitValue(EZBET_QUERY_ID, yesArgs, 0, EZBET_QUERY_DATA);
    await ethers.provider.send("evm_increaseTime", [86400 + 100]);
    await ethers.provider.send("evm_mine");
    await ezbet.settleBet();
    let iBal0 = await ethers.provider.getBalance(accounts[0].address);
    let iBal1 = await ethers.provider.getBalance(accounts[1].address);
    let iBal2 = await ethers.provider.getBalance(accounts[2].address);
    await ezbet.connect(accounts[0]).claimWinnings()
    await ezbet.connect(accounts[1]).claimWinnings()
    //await h.expectThrow(await ezbet.connect(accounts[2]).claimWinnings()) // "ERC20: transfer amount exceeds balance"
    let newBal0 = await ethers.provider.getBalance(accounts[0].address);
    let newBal1 = await ethers.provider.getBalance(accounts[1].address);
    let newBal2 = await ethers.provider.getBalance(accounts[2].address);
    assert(await ezbet.addyToYes(accounts[0].address) == 0)
    assert(await ezbet.addyToYes(accounts[1].address) == 0)
    assert(await ezbet.addyToYes(accounts[2].address) == 0)
    assert(BigInt(newBal1 - iBal1) - BigInt(7.99e18) > 0)
    assert(BigInt(newBal0 - iBal0) - BigInt(1.99e18) > 0)
    assert(BigInt(iBal2 - newBal2)  == 0)
  });
  it("getSettlementStatus", async function() {
    await ezbet.connect(accounts[1]).betOnYes({value:BigInt(4e18)})
    await ezbet.connect(accounts[2]).betOnNo({value:BigInt(4e18)})
    // advance block timestamp by 15 minutes to allow our value to be retrieved
    let _res = await ezbet.getSettlementStatus()
    let blockNumBefore = await ethers.provider.getBlockNumber();
    let  block = await ethers.provider.getBlock(blockNumBefore);
    assert(_res[0] == false, "settled should be correct")
    assert(_res[1] == false, "yesWins should be correct")
    assert(_res[2] == false, "unresolved should be correct")
    assert(_res[3] == "", "_value should be correct")
    assert(_res[4] == (_myEndDate + 1.5 * 86400) - block.timestamp)
    await ethers.provider.send("evm_increaseTime", [86400 * 3.5]);
    await ethers.provider.send("evm_mine");
    await tellorOracle.submitValue(EZBET_QUERY_ID, yesArgs, 0, EZBET_QUERY_DATA);
    _res = await ezbet.getSettlementStatus()
    assert(_res[0] == false, "settled should be correct")
    assert(_res[1] == true, "yesWins should be correct")
    assert(_res[2] == false, "unresolved should be correct")
    let _val = abiCoder.decode(["bytes"],abiCoder.encode(["string"], [_res[3]]))
    assert(_val[0] == yesArgs, "_value should be correct")
    blockNumBefore = await ethers.provider.getBlockNumber();
    block = await ethers.provider.getBlock(blockNumBefore);
    assert(_res[4] - ((_myEndDate + 1.5 * 86400) - block.timestamp)  <10)
    assert(_res[4] - ((_myEndDate + 1.5 * 86400) - block.timestamp)  > -10)
    await ethers.provider.send("evm_increaseTime", [86400 + 100]);
    await ethers.provider.send("evm_mine");
    await ezbet.settleBet();
    _res = await ezbet.getSettlementStatus()
    blockNumBefore = await ethers.provider.getBlockNumber();
    block = await ethers.provider.getBlock(blockNumBefore);
    assert(_res[0] == true, "settled should be correct")
    assert(_res[1] == true, "yesWins should be correct")
    assert(_res[2] == false, "unresolved should be correct")
    _val = abiCoder.decode(["bytes"],abiCoder.encode(["string"], [_res[3]]))
    assert(_val[0] == yesArgs, "_value should be correct")
    assert(_res[4] == 0)
  });
  it("getCurrentOdds", async function() {
    ezbet = await Ezbet.connect(accounts[0]).deploy(tellorOracle.address, _myQ,BigInt(1e17),BigInt(1e17),_myEndDate,{value:BigInt(2e17)});
    await ezbet.deployed();
    //50
    let _res = await ezbet.getCurrentOddsOfYes()
    assert(_res == 50, "odds should be correct")
    //1
    await ezbet.connect(accounts[1]).betOnNo({value:BigInt(98e17)})
    _res = await ezbet.getCurrentOddsOfYes()
    assert(_res == 1, "odds should be correct")
    //25
    await ezbet.connect(accounts[1]).betOnNo({value:BigInt(1e17)})
    await ezbet.connect(accounts[2]).betOnYes({value:BigInt(30e17)})
    _res = await ezbet.getCurrentOddsOfYes()
    assert(_res == 23, "odds should be correct")
    //75
    await ezbet.connect(accounts[2]).betOnYes({value:BigInt(270e17)})
    _res = await ezbet.getCurrentOddsOfYes()
    assert(_res == 75, "odds should be correct")
    //99
    await ezbet.connect(accounts[2]).betOnYes({value:BigInt(10000e17)})
    _res = await ezbet.getCurrentOddsOfYes()
    assert(_res == 99, "odds should be correct")
  });
  it("full Yes", async function() {
    await ezbet.connect(accounts[1]).betOnYes({value:BigInt(8e18)})
    // advance block timestamp by 15 minutes to allow our value to be retrieved
    await ethers.provider.send("evm_increaseTime", [86400 * 3.5]);
    await ethers.provider.send("evm_mine");
    await tellorOracle.submitValue(EZBET_QUERY_ID, yesArgs, 0, EZBET_QUERY_DATA);
    console.log("y", yesArgs)
    await ethers.provider.send("evm_increaseTime", [86400 + 100]);
    await ethers.provider.send("evm_mine");
    await ezbet.settleBet();
    let iBal0 = await ethers.provider.getBalance(accounts[0].address);
    let iBal1 = await ethers.provider.getBalance(accounts[1].address);
    let iBal2 = await ethers.provider.getBalance(accounts[2].address);
    await ezbet.connect(accounts[0]).claimWinnings()
    await ezbet.connect(accounts[1]).claimWinnings()
    await expect(ezbet.connect(accounts[0]).claimWinnings()).to.be.reverted;
    await expect(ezbet.connect(accounts[1]).claimWinnings()).to.be.reverted;
    await expect(ezbet.connect(accounts[2]).claimWinnings()).to.be.reverted;
    //await h.expectThrow(await ezbet.connect(accounts[2]).claimWinnings()) // "ERC20: transfer amount exceeds balance"
    let newBal0 = await ethers.provider.getBalance(accounts[0].address);
    let newBal1 = await ethers.provider.getBalance(accounts[1].address);
    let newBal2 = await ethers.provider.getBalance(accounts[2].address);
    assert(await ezbet.addyToYes(accounts[0].address) == 0)
    assert(await ezbet.addyToYes(accounts[1].address) == 0)
    assert(await ezbet.addyToYes(accounts[2].address) == 0)
    assert(BigInt(newBal1 - iBal1) - BigInt(8.88e18) > 0)
    assert(BigInt(newBal0 - iBal0) - BigInt(1.1e18) > 0)
    assert(BigInt(iBal2 - newBal2)  < BigInt(1e16))
  })
  it("full No", async function() {
    await ezbet.connect(accounts[1]).betOnYes({value:BigInt(7e18)})
    await ezbet.connect(accounts[2]).betOnNo({value:BigInt(1e18)})
    // advance block timestamp by 15 minutes to allow our value to be retrieved
    await ethers.provider.send("evm_increaseTime", [86400 * 3.5]);
    await ethers.provider.send("evm_mine");
    await tellorOracle.submitValue(EZBET_QUERY_ID, noArgs, 0, EZBET_QUERY_DATA);
    await ethers.provider.send("evm_increaseTime", [86400 + 100]);
    await ethers.provider.send("evm_mine");
    await ezbet.settleBet();
    let iBal0 = await ethers.provider.getBalance(accounts[0].address);
    let iBal1 = await ethers.provider.getBalance(accounts[1].address);
    let iBal2 = await ethers.provider.getBalance(accounts[2].address);
    await ezbet.connect(accounts[0]).claimWinnings()
    await ezbet.connect(accounts[2]).claimWinnings()
    await expect(ezbet.connect(accounts[0]).claimWinnings()).to.be.reverted;
    await expect(ezbet.connect(accounts[1]).claimWinnings()).to.be.reverted;
    await expect(ezbet.connect(accounts[2]).claimWinnings()).to.be.reverted;
    //await h.expectThrow(await ezbet.connect(accounts[2]).claimWinnings()) // "ERC20: transfer amount exceeds balance"
    let newBal0 = await ethers.provider.getBalance(accounts[0].address);
    let newBal1 = await ethers.provider.getBalance(accounts[1].address);
    let newBal2 = await ethers.provider.getBalance(accounts[2].address);
    assert(await ezbet.addyToNo(accounts[0].address) == 0)
    assert(await ezbet.addyToNo(accounts[1].address) == 0)
    assert(await ezbet.addyToNo(accounts[2].address) == 0)
    assert(BigInt(newBal2 - iBal2) - BigInt(4.99e18) > 0)
    assert(BigInt(newBal0 - iBal0) - BigInt(4.99e18) > 0)
    assert(BigInt(iBal1 - newBal1)  < BigInt(1e16))
  })
  it("full Unresolved", async function() {
    await ezbet.connect(accounts[1]).betOnYes({value:BigInt(4e18)})
    await ezbet.connect(accounts[2]).betOnNo({value:BigInt(4e18)})
    // advance block timestamp by 15 minutes to allow our value to be retrieved
    await ethers.provider.send("evm_increaseTime", [86400 * 3.5]);
    await ethers.provider.send("evm_mine");
    await tellorOracle.submitValue(EZBET_QUERY_ID, unArgs, 0, EZBET_QUERY_DATA);
    await ethers.provider.send("evm_increaseTime", [86400 + 100]);
    await ethers.provider.send("evm_mine");
    await ezbet.settleBet();
    assert(await ezbet.unresolved.call(), "should be unresolved")
    let iBal0 = await ethers.provider.getBalance(accounts[0].address);
    let iBal1 = await ethers.provider.getBalance(accounts[1].address);
    let iBal2 = await ethers.provider.getBalance(accounts[2].address);
    await ezbet.connect(accounts[0]).claimWinnings()
    await ezbet.connect(accounts[1]).claimWinnings()
    await ezbet.connect(accounts[2]).claimWinnings()
    await expect(ezbet.connect(accounts[0]).claimWinnings()).to.be.reverted;
    await expect(ezbet.connect(accounts[1]).claimWinnings()).to.be.reverted;
    await expect(ezbet.connect(accounts[2]).claimWinnings()).to.be.reverted;
    //await h.expectThrow(await ezbet.connect(accounts[2]).claimWinnings()) // "ERC20: transfer amount exceeds balance"
    let newBal0 = await ethers.provider.getBalance(accounts[0].address);
    let newBal1 = await ethers.provider.getBalance(accounts[1].address);
    let newBal2 = await ethers.provider.getBalance(accounts[2].address);
    assert(await ezbet.addyToNo(accounts[0].address) == 0)
    assert(await ezbet.addyToNo(accounts[1].address) == 0)
    assert(await ezbet.addyToNo(accounts[2].address) == 0)
    assert(BigInt(newBal2 - iBal2) - BigInt(3.99e18) > 0)
    assert(BigInt(newBal1 - iBal1) - BigInt(3.99e18) > 0)
    assert(BigInt(newBal0 - iBal0) - BigInt(1.99e18) > 0)
  })
});
