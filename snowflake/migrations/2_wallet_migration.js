const FactoryContract = artifacts.require("./ProtectedWalletFactory.sol");
const SnowflakeContract = artifacts.require("./Snowflake.sol");
const ProtectedWallet = artifacts.require("./ProtectedWallet.sol");
const UniswapVia = artifacts.require("./ProtectedWallet/uniswapVia.sol");

module.exports = async (deployer) => {
  let allowance = web3.utils.toBN(1e18);
  await deployer.deploy(
    FactoryContract,
    "0xB0D5a36733886a4c5597849a05B315626aF5222E",
    "0x387Ce3020e13B0a334Bb3EB25DdCb73c133f1D7A"
  );
  const snowflake = await SnowflakeContract.at(
    "0x47aC2F343926868e892Ba53a9D09e98bf6124460"
  );

  //@params uniswapVia contract, snowflake address,
  await deployer.deploy(
    UniswapVia,
    "0xB0D5a36733886a4c5597849a05B315626aF5222E",
    "0xf5D915570BC477f9B8D6C0E980aA81757A3AaC36"
  );

  const uniVia = await UniswapVia.at(UniswapVia.address);
  console.log("Uniswap via: ", UniswapVia.address);
  const factory = await FactoryContract.at(FactoryContract.address);
  console.log("Factory contract address: ", factory.address);
  /*
    await snowflake.addResolver(FactoryContract.address, true, allowance, "0x00").then(console.log("\n Deploying protected wallet..."))
    let protectedWalletAddr = await factory.getWalletByEIN(4)
    console.log("\n Protected wallet at: ", protectedWalletAddr, "\n")
    const wallet = await ProtectedWallet.at(protectedWalletAddr)
    await snowflake.addResolver(wallet.address, true, 0, "0x00")
    const deposit = web3.utils.toBN(10000).mul(web3.utils.toBN(1e18));
    await snowflake.changeResolverAllowances([wallet.address], [deposit])
    // Deposits hydro from snowflake
    await wallet.depositFromSnowflake(deposit)
    const withdrawal1 = web3.utils.toBN(90).mul(web3.utils.toBN(1e18))
    console.log(" Attempting withdrawal beneath daily limit...")
    await wallet.withdrawToSnowflake(withdrawal1)
    console.log(" Success \n")
    await wallet.resetChainlinkState()
    console.log(" Your wallet at address: ", wallet.address, " Write this address into chainlinktest.js")
    */
};
