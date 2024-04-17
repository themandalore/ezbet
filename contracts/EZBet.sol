// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "usingtellor/contracts/UsingTellor.sol";

/**
 @author themandalore
 @title EZBet
 @dev This is a contract for making a simple bet.  Vote yes or vote no.  Yes deposits split the no pot if yes, and vice-versa
 endDate is when betting stop, 12 hours (the delay variable) for the event, then 24 hours after tellor report to wait for disputes
*/
contract EZBet is UsingTellor {
    // Question must resolve with "Yes" or "No".  Anything else is invalid and you just get your money back.  Even "YES" or "NO" or "yes" or "no".
    // Be retarded, but that not retarded. You can check if it properly settles and dispute if need be*/
    // Also note, tellor is decentralized.  Reporting a bad value can get you disputed.  Also be sure to check for disputes
    // if you got cash on the line.  We don't do it for you and you shouldn't assume others do. 
    // also run your own node (just throwing that in there)

    string public question;
    bytes public queryData;
    bytes32 public queryId;
    bool public settled;
    bool public yesWins;
    bool public unresolved;
    uint256 public yesBets;
    uint256 public noBets;
    uint256 public endDate;
    uint256 public delay = 12 hours;//time for match (so bets happen, then delay, then 24 hours for tellor report)
    mapping(address => uint256) public addyToYes;
    mapping(address => uint256) public addyToNo;


    event BetSettled(bool _yesWins);
    event NoBet(address _addy, uint256 _amt);
    event YesBet(address _addy, uint256 _amt);
    event WinningsClaimed(address _addy, uint256 _amt);

    /**
     * @dev constructor to kick things off
     * @param _tellorAddress the tellor oracle (TellorFlex.sol) address
     * @param _question the question you want to ask, be sure to have it resolve Yes or No
     * @param _amountYes initial yes bet
     * @param _amountNo initial no bet
     * @param _endDate time that the betting ends.  event ends 12 hours later. Tellor has 24 hours to report
     */
    constructor(address payable _tellorAddress, string memory _question, uint _amountYes, uint _amountNo, uint256 _endDate)
        UsingTellor(_tellorAddress) payable{
        question = _question;
        queryData = abi.encode("StringQuery", abi.encode(question));
        queryId = keccak256(queryData);
        require(_amountNo > 0 && _amountYes > 0, "amounts must be > 0");
        require(msg.value == _amountNo + _amountYes, "must send funds");
        require(_endDate > block.timestamp, "end date must be in the future");
        addyToYes[msg.sender] = _amountYes;
        addyToNo[msg.sender] = _amountNo;
        yesBets = _amountYes;
        noBets = _amountNo;
        endDate = _endDate;
    }

    /**
     * @dev allows user to bet on the question resolving yes
     * @param _amt a uint for the amount of eth you want to send
     */
    function betOnYes(uint256 _amt) external payable{
        require(block.timestamp < endDate, "end date passed");
        require(_amt > 0, "amount too low");
        require(_amt == msg.value, "amount != msg.value");
        addyToYes[msg.sender] = addyToYes[msg.sender] + msg.value;
        yesBets += msg.value;
        emit YesBet(msg.sender,msg.value);
    }

    /**
     * @dev allows user to bet on the question resolving no
     * @param _amt a uint for the amount of eth you want to send
     */
    function betOnNo(uint256 _amt) external payable{
        require(block.timestamp < endDate, "end date passed");
        require(_amt > 0, "amount too low");
        require(_amt == msg.value, "amount != msg.value");
        addyToNo[msg.sender] = addyToNo[msg.sender] + msg.value;
        noBets += msg.value;
        emit NoBet(msg.sender,msg.value);
    }
    
    /**
     * @dev allows parties who bet to claim their winnings
     */
    function claimWinnings() external{
        if(settled){
            uint256 _amt;
            uint256 _myAmt;
            if(unresolved){
                _amt = addyToYes[msg.sender] + addyToNo[msg.sender];
                addyToYes[msg.sender] = 0; 
                addyToNo[msg.sender] = 0; 
            }
            else if(yesWins ){
                _myAmt = addyToYes[msg.sender];
                _amt = (noBets * _myAmt/yesBets) + _myAmt;
                addyToYes[msg.sender] = 0;
            }
            else{
                _myAmt = addyToNo[msg.sender];
                _amt = (yesBets * _myAmt/noBets) + _myAmt;
                addyToNo[msg.sender] = 0;
            }
            require(_amt > 0, "amount must be greater than 0");
            payable(msg.sender).transfer(_amt);
            emit WinningsClaimed(msg.sender, _amt);
        }
    }

    /**
     * @dev allows anyone to settle the bet, 36 hours after the endDate (and a valid tellor report 24 hours old)
     */
     //can be run 24 hours after the match is reported to Tellor
    function settleBet() external{
        require(!settled, "settled");
        (bytes memory _value, uint256 _timestampRetrieved) =
            getDataAfter(queryId, endDate + delay);
        require(_timestampRetrieved !=0, "no tellor value");
        if(block.timestamp - _timestampRetrieved >= 24 hours) {
                settled = true;
                if(keccak256(_value) == keccak256(abi.encode("Yes"))){
                            yesWins = true;
                        }
                else if(keccak256(_value) != keccak256(abi.encode("No"))){
                            unresolved = true;
                }
                emit BetSettled(yesWins);
        }
    }

    //view functions
    /**
     * @dev shows you the current odds of yes, rounded down to nearest pct
     */
    function getCurrentOddsOfYes() external view returns(uint256){
        return (yesBets * 100)/(yesBets + noBets);
    }

    /**
     * @dev allows you to check how the market will settle and how long until settlement
     */
    function getSettlementStatus() external view
        returns(bool,bool _yesWins, bool _unresolved,string memory,uint256 _timeUntilSettlement){
        (bytes memory _value, uint256 _timestampRetrieved) = getDataAfter(queryId, endDate + delay);
        if(_timestampRetrieved > 0){
                    if( block.timestamp > _timestampRetrieved + 24 hours){
            _timeUntilSettlement = 0;
            }
            else if (block.timestamp - _timestampRetrieved < 24 hours){
                _timeUntilSettlement = 24 hours - (block.timestamp - _timestampRetrieved);
            }
            if(keccak256(_value) == keccak256(abi.encode("Yes"))){
                        _yesWins = true;
                    }
            else if(keccak256(_value) != keccak256(abi.encode("No"))){
                        _unresolved = true;
            }
        }
        else{
            _timeUntilSettlement = (endDate + delay + 24 hours) - block.timestamp;
        }
        return (settled, _yesWins, _unresolved, string(_value),_timeUntilSettlement);
    }
}
