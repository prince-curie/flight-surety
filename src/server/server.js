import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';
import regeneratorRuntime from "regenerator-runtime";

let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.HttpProvider(config.url));
web3.setProvider(config.url.replace('http', 'ws'))
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);

const app = express();
let accounts

function getAccounts() {
  return web3.eth.getAccounts().then(data => data);
}

(async () => {
  accounts = await getAccounts()

  web3.eth.defaultAccount = accounts[0];

  let registrationFee = await flightSuretyApp.methods.REGISTRATION_FEE().call()

  for (let counter = 0; counter < accounts.length; counter++ ) {
    await flightSuretyApp.methods.registerOracle().send(
      {from: accounts[counter], value: web3.utils.toWei('1', 'ether'), gas: 300000})
  }

})();


flightSuretyApp.events.OracleRequest({},function(error, event) {
  let {returnValues} = event

  for(let counter=0; counter<accounts.length; counter++) {
    flightSuretyApp.methods.getMyIndexes().call({from: accounts[counter]}).then(indexes => {

      let status = [0, 10, 20, 30, 40, 50]

      for(let index = 0; index < indexes.length; index++) {
        
        let randomNumber = Math.floor(Math.random() * 5) + 1
        
        flightSuretyApp.methods.submitOracleResponse(
          indexes[index], 
          returnValues.airline, 
          returnValues.flight, 
          returnValues.timestamp, 
          status[randomNumber]
        ).send({from: accounts[counter]}).then(console.log).catch(error => error)
          
      };  
    })
  }
})




app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

export default app;
