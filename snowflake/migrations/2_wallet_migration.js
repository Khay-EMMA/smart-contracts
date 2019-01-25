const FactoryContract = artifacts.require("./ProtectedWalletFactory.sol");

module.exports = async (deployer) => {
    await deployer.deploy(FactoryContract, "0x47aC2F343926868e892Ba53a9D09e98bf6124460", "0x387Ce3020e13B0a334Bb3EB25DdCb73c133f1D7A")
    console.log(FactoryContract.address)
}