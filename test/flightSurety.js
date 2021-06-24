
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', (accounts) => {

  var config;
    const fundingPrice = web3.utils.toWei('10', "ether")

  before('setup contract', async () => {
    config = await Test.Config(accounts);

    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirline.call(newAirline); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

    it('new (airline) can be funded to complete registration', async () => {
        try {
            await config.flightSuretyApp.fundAirline({from: config.firstAirline, value: fundingPrice});            
        } catch (error) {
            console.log('error1 ==> ', error)
        }

        let result = await config.flightSuretyApp.isAirlineFunded(config.firstAirline); 

        // ASSERT
        // assert.equal(logs[0].event, 'AirlineFunded', "Airline funding event failed.");
        assert.equal(result, true, "Airline funding failed.");
    })
 
    it('(airline) can register a new airline if it is fully registered', async () => {
        let newAirline = accounts[2];

        try {
            
            await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
        } catch(e) {

        }

        let result = await config.flightSuretyApp.isAirline(newAirline, {from: config.firstAirline}); 

        // ASSERT
        assert.equal(result, true, "Airline should not be able to register another airline if it hasn't provided funding");
    })

    it('(multiparty) concensus not met for airline registration', async () => {
        let airline3 = accounts[3];
        let airline2 = accounts[2];
        let airline4 = accounts[4];
        let newAirline = accounts[5];

        await config.flightSuretyApp.registerAirline(airline3, {from: config.firstAirline});
        await config.flightSuretyApp.registerAirline(airline4, {from: config.firstAirline});

        await config.flightSuretyApp.fundAirline({from: airline2, value: fundingPrice});
        await config.flightSuretyApp.fundAirline({from: airline3, value: fundingPrice});
        await config.flightSuretyApp.fundAirline({from: airline4, value: fundingPrice});

        try {
            await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
        } catch(e) {
            console.log("reg error ==> ", e)
        }

        let result = await config.flightSuretyApp.isAirline.call(newAirline, {from: config.firstAirline}); 

        // ASSERT
        assert.equal(result, false, "Airline should not be registered if consensus is not met");
    })

    it('(multiparty) concensus met for airline registration', async () => {
        let airline2 = accounts[2];
        let newAirline = accounts[5];

        try {            
            const result = await config.flightSuretyApp.registerAirline(newAirline, {from: airline2});
        } catch(e) {
            console.log('reg airline-2 ==> ', e)
        }

        let result = await config.flightSuretyApp.isAirline.call(newAirline, {from: config.firstAirline});

        // ASSERT
        assert.equal(result, true, "Airline should be registered if consensus is met");
    })

    it('(Flights) can be registered', async () => {
        let timestamp = Date.now()

        let {logs} = await config.flightSuretyApp.registerFlights('Qa1234er', timestamp, {from: config.firstAirline})

        assert.equal(logs[0].event, 'FlightRegistered', "Flight not registered.");
    })

    it('(passenger) can pay for flight insurance', async () => {
        let timestamp = Date.now()

        let key = await config.flightSuretyData.allFlights(0)
        
        let result
        try {
            
        result = await config.flightSuretyApp.buyInsurance(key, {from: accounts[6], value: web3.utils.toWei('0.1', "ether")})
        } catch (error) {
            console.log('error 2 ==> ', error)
        }

        assert.equal(result.logs[0].event, 'InsurancePurchased', "insurance purchased.");
    })
});
