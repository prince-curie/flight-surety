// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */

import "./interfaces/IFlightSuretyData.sol";

contract FlightSuretyApp {

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address payable private contractOwner;          // Account used to deploy contract

    struct ResponseInfo {
        address requester;
        bool isOpen;
        mapping(uint8 => address[]) responses;
    }
    mapping(bytes32 => ResponseInfo) oracleResponses;

    IFlightSuretyData _flightSuretyData;    

    uint fundingPrice = 10 ether;
    uint256 suretyPayoutMultiplier = uint(3)/uint(2);

    event AirlineFunded(bool isFunded);

    event FlightRegistered(string, uint256, bytes32);

    event InsurancePurchased(string);

    event PassengerPaid(string, uint256);
    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
         // Modify to call data contract's status
        require(true, "Contract is currently not operational");  
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /**
    * @dev Modifier that requires that a funded airline be the function caller
    */
    modifier requireFundedAirline()
    {
        require(_flightSuretyData.isAirlineFunded(msg.sender) == true, "Caller is not a funded airline");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor(address payable dataContract, address airline) 
    {
        contractOwner = payable(msg.sender);
        _flightSuretyData = IFlightSuretyData(dataContract);
        _flightSuretyData.registerAirline(airline, msg.sender);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
        public 
        view 
        returns(bool) 
    {
        return _flightSuretyData.isOperational();  // Modify to call data contract's status
    }

    function isAirline(address airline) 
        public 
        view 
        returns(bool) 
    {
        return _flightSuretyData.isAirline(airline); 
    }

    function isAirlineFunded(address airline) 
        public 
        view 
        returns(bool) 
    {
        return _flightSuretyData.isAirlineFunded(airline); 
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline( address airline )
        public
        requireFundedAirline
        returns(bool success, uint256 votes)
    {
        return _flightSuretyData.registerAirline(airline, msg.sender);
    }

    /**
    * @dev Completes airline registration by funding it.
    *
    */   
    function fundAirline()
        public
        payable
    {
        require(_flightSuretyData.isAirline(msg.sender) == true, 'Airline is not registered, kindly register airline.');
        require(msg.value >= fundingPrice, 'Please increase the funding price to the appropriate amount');
        require(_flightSuretyData.isAirlineFunded(msg.sender) == false, 'Airline already funded');
        
        bool isFunded = _flightSuretyData.fundsAirline(msg.sender, msg.value);
        
        _flightSuretyData.incrementFundedAirlineCount();

        emit AirlineFunded(isFunded);
    }

    /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlights(string calldata flight, uint256 timestamp)
        public
    {
        require(_flightSuretyData.isAirline(msg.sender) == true, 'Only airlines are allowed to register flight.');
        require(_flightSuretyData.isAirlineFunded(msg.sender) == true, 'Kindly fund your airline to enjoy added priviledges.');

        bytes32 flightKey = _flightSuretyData.registerFlight(
            flight, msg.sender, STATUS_CODE_UNKNOWN, timestamp
        );

        emit FlightRegistered(flight, timestamp, flightKey);
    }

    /**
    * @dev Buy insurance a flight.
    *
    */  
    function buyInsurance(bytes32 flightKey)
        public
        payable
    {
        require(_flightSuretyData.isAirline(msg.sender) == false, 'airlines are not allowed to buy flight insurance.');
        require(_flightSuretyData.isFlight(flightKey) == true, 'Flight is not registered');
        require(msg.value <= 1 ether, 'Insurance cost a maximum of 1 ether');
        
        uint256 payout = msg.value * suretyPayoutMultiplier;
        _flightSuretyData.buy(msg.value, msg.sender, flightKey, payout);

        emit InsurancePurchased('Insurance purchased successfully');
    }

    function getFlightKey(address airline, string calldata flight, uint256 timestamp)
        pure
        internal
        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }
    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus
    (
        address airline,
        string calldata flight,
        uint256 timestamp,
        uint8 statusCode,
        bytes32 key
    )
        internal
    {
        oracleResponses[key].isOpen = false;

        if(statusCode == STATUS_CODE_LATE_AIRLINE) {
            bytes32 flightKey = getFlightKey(airline, flight, timestamp);

            _flightSuretyData.creditInsurees(oracleResponses[key].requester, flightKey);

            return;
        }
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(address airline, string calldata flight, uint256 timestamp)
        external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        
        oracleResponses[key].requester = msg.sender;
        oracleResponses[key].isOpen = true;

        emit OracleRequest(index, airline, flight, timestamp);
    }

    // Sends passengers money to his wallet
    function payPassenger()
        external
    {
        uint256 passengerPay = _flightSuretyData.pay(msg.sender);

        if(passengerPay == 0) revert('You do not have funds for withdrawal');

        emit PassengerPaid("You have received the sum of", passengerPay);
    } 


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle()
        external
        payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes()
        view
        external
        returns(uint8[3] memory)
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
    (
        uint8 index,
        address airline,
        string calldata flight,
        uint256 timestamp,
        uint8 statusCode
    )
        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode, key);
        }
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account)
        internal
        returns(uint8[3] memory)
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex(address account)
        internal
        returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

} 
