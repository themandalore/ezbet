/**
 *Submitted for verification at Etherscan.io on 2024-04-17
*/

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ITellor {
    function getNewValueCountbyQueryId(bytes32 _queryId) external view returns (uint256);
    function getTimestampbyQueryIdandIndex(bytes32 _queryId, uint256 _index) external view returns (uint256);
    function retrieveData(bytes32 _queryId, uint256 _timestamp) external view returns (bytes memory);
    function getDataAfter(bytes32 _queryId, uint256 _timestamp) external view returns (bytes memory _value, uint256 _timestampRetrieved);
    function getIndexForDataAfter(bytes32 _queryId, uint256 _timestamp) external view returns (bool _found, uint256 _index);
    function isInDispute(bytes32 _queryId, uint256 _timestamp) external view returns (bool);
}

/**
 @author Tellor Inc
 @title UsingTellor
 @dev This contract helps smart contracts read data from Tellor
 */
contract UsingTellor {
    ITellor public tellor;
    /**
     * @dev the constructor sets the oracle address in storage
     * @param _tellor is the Tellor Oracle address
     */
    constructor(address payable _tellor) {
        tellor = ITellor(_tellor);
    }

    /*Getters*/
    /**
     * @dev Retrieves the next value for the queryId after the specified timestamp
     * @param _queryId is the queryId to look up the value for
     * @param _timestamp after which to search for next value
     * @return _value the value retrieved
     * @return _timestampRetrieved the value's timestamp
     */
    function getDataAfter(bytes32 _queryId, uint256 _timestamp)
        internal
        view
        returns (bytes memory _value, uint256 _timestampRetrieved)
    {
        (bool _found, uint256 _index) = getIndexForDataAfter(
            _queryId,
            _timestamp
        );
        if (!_found) { return ("", 0);}
        _timestampRetrieved = getTimestampbyQueryIdandIndex(_queryId, _index);
        _value = retrieveData(_queryId, _timestampRetrieved);
        return (_value, _timestampRetrieved);
    }

    /**
     * @dev Retrieves latest array index of data before the specified timestamp for the queryId
     * @param _queryId is the queryId to look up the index for
     * @param _timestamp is the timestamp before which to search for the latest index
     * @return _found whether the index was found
     * @return _index the latest index found before the specified timestamp
     */
    // slither-disable-next-line calls-loop
    function getIndexForDataAfter(bytes32 _queryId, uint256 _timestamp)
        internal
        view
        returns (bool _found, uint256 _index)
    {
        uint256 _count = getNewValueCountbyQueryId(_queryId);
        if (_count == 0) return (false, 0);
        _count--;
        bool _search = true; // perform binary search
        uint256 _middle = 0;
        uint256 _start = 0;
        uint256 _end = _count;
        uint256 _timestampRetrieved;
        // checking boundaries to short-circuit the algorithm
        _timestampRetrieved = getTimestampbyQueryIdandIndex(_queryId, _end);
        if (_timestampRetrieved <= _timestamp) return (false, 0);
        _timestampRetrieved = getTimestampbyQueryIdandIndex(_queryId, _start);
        if (_timestampRetrieved > _timestamp) {
            _search = false;
        }
        while (_search) {
            _middle = (_end + _start) / 2;
            _timestampRetrieved = getTimestampbyQueryIdandIndex(
                _queryId,
                _middle
            );
            if (_timestampRetrieved > _timestamp) {
                uint256 _prevTime = getTimestampbyQueryIdandIndex(
                    _queryId,
                    _middle - 1
                );
                if (_prevTime <= _timestamp) {
                    _search = false;
                } else {_end = _middle - 1;}
            } else {
                uint256 _nextTime = getTimestampbyQueryIdandIndex(
                    _queryId,
                    _middle + 1
                );
                if (_nextTime > _timestamp) {
                    _search = false;
                    _middle++;
                    _timestampRetrieved = _nextTime;
                } else {_start = _middle + 1;}
            }
        }
        if (!isInDispute(_queryId, _timestampRetrieved)) {
            // _timestampRetrieved is correct
            return (true, _middle);
        } else {
            while (
                isInDispute(_queryId, _timestampRetrieved) && _middle < _count
            ) {
                _middle++;
                _timestampRetrieved = getTimestampbyQueryIdandIndex(
                    _queryId,
                    _middle
                );
            }
            if (
                _middle == _count && isInDispute(_queryId, _timestampRetrieved)
            ) {return (false, 0);}
            return (true, _middle);
        }
    }

    /**
     * @dev Counts the number of values that have been submitted for the queryId
     * @param _queryId the id to look up
     * @return uint256 count of the number of values received for the queryId
     */
    function getNewValueCountbyQueryId(bytes32 _queryId) internal view returns (uint256){
        return tellor.getNewValueCountbyQueryId(_queryId);
    }

    /**
     * @dev Gets the timestamp for the value based on their index
     * @param _queryId is the id to look up
     * @param _index is the value index to look up
     * @return uint256 timestamp
     */
    function getTimestampbyQueryIdandIndex(bytes32 _queryId, uint256 _index) internal view returns (uint256){
        return tellor.getTimestampbyQueryIdandIndex(_queryId, _index);
    }

    /**
     * @dev Determines whether a value with a given queryId and timestamp has been disputed
     * @param _queryId is the value id to look up
     * @param _timestamp is the timestamp of the value to look up
     * @return bool true if queryId/timestamp is under dispute
     */
    function isInDispute(bytes32 _queryId, uint256 _timestamp) internal view returns (bool) {
        return tellor.isInDispute(_queryId, _timestamp);
    }

    /**
     * @dev Retrieve value from oracle based on queryId/timestamp
     * @param _queryId being requested
     * @param _timestamp to retrieve data/value from
     * @return bytes value for query/timestamp submitted
     */
    function retrieveData(bytes32 _queryId, uint256 _timestamp) internal view returns (bytes memory){
        return tellor.retrieveData(_queryId, _timestamp);
    }
}

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
    // if you got cash on the line.

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
    //e.g. 0x8cFc184c877154a8F9ffE0fe75649dbe5e2DBEbf,"Did Levan win EvW12 vs Devon?",1,1,1713628800
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
     */
    function betOnYes() external payable{
        require(block.timestamp < endDate, "end date passed");
        require(msg.value > 0, "amount too low");
        addyToYes[msg.sender] = addyToYes[msg.sender] + msg.value;
        yesBets += msg.value;
        emit YesBet(msg.sender,msg.value);
    }

    /**
     * @dev allows user to bet on the question resolving no
     */
    function betOnNo() external payable{
        require(block.timestamp < endDate, "end date passed");
        require(msg.value > 0, "amount too low");
        addyToNo[msg.sender] = addyToNo[msg.sender] + msg.value;
        noBets += msg.value;
        emit NoBet(msg.sender,msg.value);
    }
    
    /**
     * @dev allows parties who bet to claim their winnings
     */
    function claimWinnings() external{
        require(settled);
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

    /**
     * @dev allows anyone to settle the bet, 36 hours after the endDate (and a valid tellor report 24 hours old)
     */
    function settleBet() external{
        require(!settled, "settled");
        (bytes memory _value, uint256 _timestampRetrieved) =
            getDataAfter(queryId, endDate + delay);
        require(_timestampRetrieved !=0, "no tellor value");
        require(block.timestamp - _timestampRetrieved >= 24 hours);
        settled = true;
        if(keccak256(_value) == keccak256(abi.encode("Yes"))){
                    yesWins = true;
                }
        else if(keccak256(_value) != keccak256(abi.encode("No"))){
                    unresolved = true;
        }
        emit BetSettled(yesWins);
    }

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