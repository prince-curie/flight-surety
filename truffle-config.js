let HDWalletProvider = require("@truffle/hdwallet-provider");
let mnemonic = "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat";

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: "8545",
      network_id: '*',
    }
  },
  compilers: {
    solc: {
      version: "^0.8.5"
    }
  }
};