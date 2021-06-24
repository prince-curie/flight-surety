import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
        this.timestamp = Math.floor(Date.now() / 1000)
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {
           
            this.owner = accts[0];

            let counter = 1;
            
            while(this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }

            while(this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }

            callback();
        });
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    fetchFlightStatus(flight, callback) {
        let self = this;
        let payload = {
            airline: self.airlines[0],
            flight: flight,
            timestamp: self.timestamp
        } 
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner}, (error, result) => {
                callback(error, result);
            });
    }

    fundAirline(callback) {
        let self = this;
        
        self.flightSuretyApp.methods
            .fundAirline()
            .send({ from: self.airlines[0], value: this.web3.utils.toWei('10', 'ether')}, (error, result) => {
                callback(error, result);
            });
    }

    registerFlights(flight, callback) {
        let self = this;
        let payload = {
            flight: flight,
            timestamp: self.timestamp
        }

        self.flightSuretyApp.methods
            .registerFlights(payload.flight, payload.timestamp)
            .send({ from: self.airlines[0], gas: 700000})
            .on('receipt', function(receipt){
                
                callback(null, receipt)
            })
            .on('error', function(error, receipt) { // If the transaction was rejected by the network with a receipt, the second parameter will be the receipt.
                
                callback(error, receipt)
            }); 
    }

    buyInsurance(flightKey, amount, callback) {
        let self = this
        let value = self.web3.utils.toWei(amount, 'ether')

        self.flightSuretyApp.methods.buyInsurance(flightKey)
            .send({ from:self.passengers[0], value: value, gas: 300000 })
            .on('receipt', function({events}) {
                callback(null, events)
            })
            .on('error', function(error, receipt) {
                callback(error, receipt)
                console.log(error)
            })
    }

    payPassenger(callback) {
        let self = this

        self.flightSuretyApp.methods.payPassenger()
            .send({ from: self.passengers[0]}, (error, result) => {
                console.log('result ==> ',result)
            })
            .on('receipt', function(events) {
                console.log('events ==> ',events)
                callback(null, events)
            })
            .on('error', function(error, receipt) {
                callback(error, receipt)
                console.log(error)
            })
    }
}