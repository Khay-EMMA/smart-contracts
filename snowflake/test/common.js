const IdentityRegistry = artifacts.require('./_testing/IdentityRegistry.sol')
const HydroToken = artifacts.require('./_testing/HydroToken.sol')
const Snowflake = artifacts.require('./Snowflake.sol')
const ClientRaindrop = artifacts.require('./resolvers/ClientRaindrop/ClientRaindrop.sol')
const OldClientRaindrop = artifacts.require('./_testing/OldClientRaindrop.sol')

async function initialize (owner, users) {
  const instances = {}

  instances.HydroToken = await HydroToken.new({ from: owner })
  for (let i = 0; i < users.length; i++) {
    await instances.HydroToken.transfer(
      users[i].address,
      web3.utils.toBN(10000).mul(web3.utils.toBN(1e18)),
      { from: owner }
    )
  }

  instances.IdentityRegistry = await IdentityRegistry.new({ from: owner })

  instances.Snowflake = await Snowflake.new(
    instances.IdentityRegistry.address, instances.HydroToken.address, { from: owner }
  )

  instances.OldClientRaindrop = await OldClientRaindrop.new({ from: owner })

  instances.ClientRaindrop = await ClientRaindrop.new(
    instances.Snowflake.address, instances.OldClientRaindrop.address, 0, 0, { from: owner }
  )
  await instances.Snowflake.setClientRaindropAddress(instances.ClientRaindrop.address, { from: owner })

  return instances
}

function timeTravel (seconds) {
  return new Promise((resolve, reject) => {
    web3.currentProvider.send({
      jsonrpc: '2.0',
      method: 'evm_increaseTime',
      params: [seconds],
      id: new Date().getTime()
    }, (err, result) => {
      if (err) return reject(err)
      return resolve(result)
    })
  })
}
module.exports = {
  initialize: initialize,
  timeTravel: timeTravel
}
