// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "usingtellor/contracts/UsingTellor.sol";

contract EZBet is UsingTellor {
    // Question must resolve with "Yes" or "No".  Anything else is invalid and you just get your money back.  Even "YES" or "NO" or "yes" or "no".
    // Be retarded, but that not retarded. You can check if it properly settles and dispute if need be*/
    // Also note, tellor is decentralized.  Reporting a bad value can get you disputed.  Also be sure to check for disputes
    // if you got cash on the line.  We don't do it for you and you shouldn't assume others do. 
    // also run your own node (just throwing that in there)

    string public question;
    bytes public queryData = abi.encode("StringQuery", abi.encode(question));
    bytes32 public queryId = keccak256(queryData);
    bool public settled;
    bool public yesWins;
    bool public unresolved;
    uint256 public yesBets;
    uint256 public noBets;
    uint256 public endDate;
    mapping(address => uint256) addyToYes;
    mapping(address => uint256) addyToNo;


    event BetSettled(bool _yesWins);
    event NoBet(address _addy, uint256 _amt);
    event YesBet(address _addy, uint256 _amt);
    event WinningsClaimed(address _addy, uint256 _amt);

    // Input tellor oracle address
    constructor(address payable _tellorAddress, string memory _question, uint _amountYes, uint _amountNo, uint256 _endDate)
        UsingTellor(_tellorAddress) payable{
        question = _question;
        require(_amountNo > 0 && _amountYes > 0);
        require(msg.value == _amountNo + _amountYes);
        require(_endDate > block.timestamp);
        endDate = _endDate;
    }


    function betOnYes(uint256 _amt) external payable{
        require(block.timestamp < endDate);
        require(_amt == msg.value);
        addyToYes[msg.sender] = addyToYes[msg.sender] + msg.value;
        yesBets += msg.value;
        emit YesBet(msg.sender,msg.value);
    }

    function betOnNo(uint256 _amt) external payable{
        require(block.timestamp < endDate);
        require(_amt == msg.value);
        addyToNo[msg.sender] = addyToNo[msg.sender] + msg.value;
        noBets += msg.value;
        emit NoBet(msg.sender,msg.value);
    }
    
    function claimWinnings() external{
        if(settled){
            uint256 _amt;
            if(yesWins || unresolved){
                _amt = addyToYes[msg.sender];
                addyToYes[msg.sender] = 0;
                payable(msg.sender).transfer(_amt);
                emit WinningsClaimed(msg.sender, _amt);
            }
            if(!yesWins || unresolved){
                _amt = addyToNo[msg.sender];
                addyToNo[msg.sender] = 0;
                payable(msg.sender).transfer(_amt);
                emit WinningsClaimed(msg.sender, _amt);
            }
        }
    }

    //can be run 24 hours after the match is reported to Tellor
    function settleBet() external{
        require(!settled);
        // Retrieve data at least 24 hours old to allow time for disputes
        (bytes memory _value, uint256 _timestampRetrieved) =
            getDataAfter(queryId, endDate);
        // If timestampRetrieved is 0, no data was found
        if(block.timestamp - _timestampRetrieved > 24 hours) {
                settled = true;
                if(keccak256(_value) ==  keccak256("Yes")){
                    yesWins = true;
                }
                else if(keccak256(_value) !=  keccak256("No")){
                    unresolved = true;
                }
                emit BetSettled(yesWins);
        }
    }

    function getSettlementStatus() external view
        returns(bool,bool _yesWins, bool _unresolved,string memory,uint256 _timeUntilSettlement){
        (bytes memory _value, uint256 _timestampRetrieved) = getDataAfter(queryId, endDate);
        if (block.timestamp - _timestampRetrieved < 24 hours){
            _timeUntilSettlement = 24 hours - (block.timestamp - _timestampRetrieved);
        }
        if(keccak256(_value) ==  keccak256("Yes")){
                    _yesWins = true;
                }
                else if(keccak256(_value) != keccak256("No")){
                    _unresolved = true;
        }
        return (settled, _yesWins, _unresolved, string(_value),_timeUntilSettlement);
    }

    function getCurrentOddsOfYes() external view returns(uint256){
        return (yesBets * 100)/(yesBets + noBets);
    }
}
