const HDWalletProvider = require("truffle-hdwallet-provider")
var mnemonic = "banner absorb evoke hurt ketchup pelican misery surround enough tennis prize border"

const gas = 6.5 * 1e6
const gasPrice = 2000000000 // 2 gwei


module.exports = {
  networks: {
    development: {
      host: 'localhost',
      port: 8545,
      network_id: '*',
      websockets: true
    },
    rinkeby_infura: {
      provider: () => new HDWalletProvider(mnemonic, "https://rinkeby.infura.io/v3/75cc8cba22ab40b9bfa7406ae9b69a27"),
      network_id: 4,
      gas: gas
    },
    coverage: {
      host: 'localhost',
      port: 8555,
      network_id: '*',
      gas: 0xfffffffffff,
      gasPrice: 0x01,
      websockets: true
    },
    rinkebyIPC: {
      host: 'localhost',
      port: 8545,
      network_id: 4,
      timeoutBlocks: 200,
      gas: gas,
      gasPrice: gasPrice,
      skipDryRun: true
    },
    mainIPC: {
      host: 'localhost',
      port: 8545,
      network_id: 1,
      timeoutBlocks: 200,
      gas: gas,
      gasPrice: gasPrice,
      skipDryRun: true
    }
  },
  compilers: {
    solc: {
      version: './node_modules/solc',
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        }
      }
    }
  }
}
