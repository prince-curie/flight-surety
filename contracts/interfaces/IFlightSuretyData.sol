// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

interface IFlightSuretyData {
    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
        external
        view 
        returns(bool);

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
        returns(bool);

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
        returns(bool);

    /**
    * @dev increase the total number of funded airlines by one
    *
    * @return A number that is the new total number of airlines
    */      
    function incrementFundedAirlineCount() 
        external 
        returns(uint256);
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
        returns(bool success, uint votes);

    /**
    * @dev funds airline
    *
    * Funds an airline when called
    */
    function fundsAirline(address airline, uint256 funds)
        external

        returns(bool);

    /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight(
        string calldata flight, address airlineAddress, uint8 statusCode, uint256 timestamp
    )
        external
        returns (bytes32);

    /**
    * @dev Confirms a registered flight.
    *
    */  
    function isFlight( bytes32 key )
        external
        view
        returns (bool);

    /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy(uint256 amount, address passenger, bytes32 flightKey, uint256 payout)
        external;

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees(address passenger, bytes32 flightKey)
        external;    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay(address passenger)
        external
        returns(uint256 passengerPay);
}
