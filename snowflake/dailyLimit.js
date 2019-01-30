const ProtectedWallet = artifacts.require("./ProtectedWallet.sol")

module.exports = async () => {
    const wallet = await ProtectedWallet.at("0x08F81Ed78d0AE50cD861228BF2deF0b114497808")
    console.log("Resetting chainlink state...")
    await wallet.resetChainlinkState()
    let newLimit = web3.utils.toBN(820).mul(web3.utils.toBN(1e18))
    let oldLimit = await wallet.getDailyLimit()
    console.log("Old daily limit: ", oldLimit, "\n")
    console.log("Requesting new daily limit...")
    await wallet.requestChangeDailyLimit(newLimit)
    console.log("Request made...")
    setTimeout(async () => {
        let newerLimit = await wallet.getDailyLimit()
        console.log("final:", newerLimit)
        return process.exit()
    }, 30000)
}