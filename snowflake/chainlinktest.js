const ProtectedWallet = artifacts.require("./ProtectedWallet.sol")

module.exports = async () => {
    const wallet = await ProtectedWallet.at("0xa6B17378902F2B683ceF104129A03E4C654E98AB")
    console.log("Resetting chainlink state...")
    await wallet.resetChainlinkState()
    let newLimit = web3.utils.toBN(840).mul(web3.utils.toBN(1e18))
    let oldLimit = await wallet.getDailyLimit()
    console.log("Old daily limit: ", oldLimit, "\n")
    console.log("Requesting new daily limit...")
    await wallet.requestChangeDailyLimit(newLimit)
    console.log("Request made...")
    setTimeout(async () => {
        let newerLimit = await wallet.getDailyLimit()
        console.log("final:", newerLimit)
    }, 30000)
}