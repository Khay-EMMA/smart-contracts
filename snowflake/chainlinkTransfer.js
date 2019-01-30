const ProtectedWallet = artifacts.require("./ProtectedWallet.sol");

module.exports = async () => {
    const wallet = ProtectedWallet.at("0x08F81Ed78d0AE50cD861228BF2deF0b114497808")
}