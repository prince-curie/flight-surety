// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

contract FlightSuretyData {
    // using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address payable private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    mapping (address => bool) authorizedUsers;
    uint256 private totalFundedAirlines;
    uint256 private totalFunds;

    struct Flight {
        string flight;
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }
    mapping(bytes32 => Flight) public flights;
    bytes32[] public allFlights;
    
    struct AirlineCompany {
        bool isRegistered;
        bool isFunded;
        uint256 votes;
        mapping(address => bool) voters;
    }
    mapping(address => AirlineCompany) public airlines;

    struct Passenger {
        uint256 amount;
        bytes32 flightKey;
        uint256 payout;
    }
    mapping(bytes32 => Passenger) passengers;

    mapping(address => uint256) public insureePayouts;

    event CreditInsurees(string, uint256);
    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor() 
    {
        contractOwner = payable(msg.sender);
        totalFundedAirlines = 0;
    }

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
        require(operational, "Contract is currently not operational");
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
    * @dev Modifier that requires the "an authorized" account to be the function caller
    */
    modifier requireAuthorizedUser()
    {
        if(authorizedUsers[msg.sender] != true) {
            revert("Caller is not authorized");
        }    
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
        external
        view 
        returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus( bool mode ) 
        external
        requireContractOwner
    {
        operational = mode;
    }

    /**
    * @dev Get registration status of an airline
    *
    * @param airline address of the airline
    *
    * @return A bool that is the current airline registration status
    */      
    function isAirline(address airline) 
        external
        view 
        returns(bool) 
    {
        return airlines[airline].isRegistered;
    }

    /**
    * @dev Get funded status of an airline
    *
    * @param airline address of the airline
    *
    * @return A bool that is the current airline registration status
    */      
    function isAirlineFunded(address airline) 
        external
        view 
        returns(bool) 
    {
        return airlines[airline].isFunded;
    }

    /**
    * @dev increase the total number of funded airlines by one
    *
    * @return A number that is the new total number of airlines
    */      
    function incrementFundedAirlineCount() 
        external 
        returns(uint256) 
    {
        return totalFundedAirlines += 1;
    } 
    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline( address airline, address airlineRegistrar )
        external
        returns(bool success, uint votes)
    {
        uint256 two = 2;
        uint256 userConsensusActivationLevel = 4;

        AirlineCompany storage airlineCompany = airlines[airline];
        airlineCompany.isFunded = false;

        if(totalFundedAirlines < userConsensusActivationLevel) {
        
            airlineCompany.isRegistered = true;
            airlineCompany.votes = 0;

            return (true, airlines[airline].votes);
        }

        require(airlineCompany.voters[airlineRegistrar] == false, "You have voted this airline.");


        airlineCompany.votes += 1;
        airlineCompany.isRegistered = false;
        airlineCompany.voters[airlineRegistrar] = true;

        if((totalFundedAirlines / airlineCompany.votes) <= two) {
            airlineCompany.isRegistered = true;
        }

        return (true, airlineCompany.votes);
    }

    /**
    * @dev funds airline
    *
    * Funds an airline when called
    */
    function fundsAirline(address airline, uint256 funds)
        external

        returns(bool)
    {
        airlines[airline].isFunded = true;

        totalFunds += funds;

        return airlines[airline].isFunded;
    }

    /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight(
        string calldata flight, address airlineAddress, uint8 statusCode, uint256 timestamp
    )
        external
        returns (bytes32)
    {
        bytes32 key = keccak256(
            abi.encodePacked(airlineAddress, flight, timestamp)
        );

        flights[key] = Flight(flight, true, statusCode, timestamp, airlineAddress);
        
        allFlights.push(key);

        return key;
    }

    /**
    * @dev Confirms a registered flight.
    *
    */  
    function isFlight( bytes32 key )
        external
        view
        returns (bool)
    {
        return flights[key].isRegistered;
    }

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy(uint256 amount, address passenger, bytes32 flightKey, uint256 payout)
        external
    {
        bytes32 passengerAddress = keccak256(abi.encodePacked(passenger, flightKey));

        totalFunds += amount;

        passengers[passengerAddress] = Passenger(amount, flightKey, payout);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees(address passenger, bytes32 flightKey)
        external
    {
        bytes32 passengerAddress = keccak256(abi.encodePacked(passenger, flightKey));

        uint256 payout = passengers[passengerAddress].payout;

        insureePayouts[passenger] += payout;

        emit CreditInsurees('Account creditted with ', payout);
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay(address passenger)
        external
        returns(uint256 passengerPay)
    {
        passengerPay = insureePayouts[passenger];

        insureePayouts[passenger] = 0;

        payable(passenger).transfer(passengerPay);

        return passengerPay;
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund()
        public
        payable
    {
        contractOwner.transfer(msg.value);
    }

    function getFlightKey
    (
        address airline,
        string memory flight,
        uint256 timestamp
    )
        pure
        internal
        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev authorizes the an address to call this contract
    */
    function authorizeCaller(address callerAddress) external requireContractOwner
    {
        authorizedUsers[callerAddress] = true;
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    receive() 
                            external 
                            payable 
    {
        fund();
    }


}

