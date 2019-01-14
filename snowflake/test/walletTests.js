let common = require('./common.js');
const { sign, verifyIdentity } = require('./utilities');

const ProtectedWalletFactory = artifacts.require('./ProtectedWalletFactory.sol');
const ProtectedWallet = artifacts.require('./ProtectedWallet.sol');

let instances
let user
let ein
let walletAddr
let wallet
contract('Testing protected wallet contracts', function (accounts) {
  const owner = {
    public: accounts[0]
  }

  const users = [
    {
      hydroID: 'abc',
      address: accounts[1],
      recoveryAddress: accounts[1],
      private: '0x6bf410ff825d07346c110c5836b33ec76e7d1ee051283937392180b732aa3aff'
    }
  ]

  it('common contracts deployed', async () => {
    instances = await common.initialize(owner.public, [])
  })

  it('Identity can be created', async function () {
    user = users[0]
    const timestamp = Math.round(new Date() / 1000) - 1
    const permissionString = web3.utils.soliditySha3(
      '0x19', '0x00', instances.IdentityRegistry.address,
      'I authorize the creation of an Identity on my behalf.',
      user.recoveryAddress,
      user.address,
      { t: 'address[]', v: [instances.Snowflake.address] },
      { t: 'address[]', v: [] },
      timestamp
    )

    const permission = await sign(permissionString, user.address, user.private)

    await instances.Snowflake.createIdentityDelegated(
      user.recoveryAddress, user.address, [], user.hydroID, permission.v, permission.r, permission.s, timestamp
    )

    user.identity = web3.utils.toBN(1)

    await verifyIdentity(user.identity, instances.IdentityRegistry, {
      recoveryAddress:     user.recoveryAddress,
      associatedAddresses: [user.address],
      providers:           [instances.Snowflake.address],
      resolvers:           [instances.ClientRaindrop.address]
    })
  })

  it("Can deposit hydro tokens", async () => {
    const amount = web3.utils.toBN(400e18).mul(web3.utils.toBN(2));
    await instances.HydroToken.approveAndCall(
      instances.Snowflake.address, amount, web3.eth.abi.encodeParameter('uint256', user.identity.toString()),
      { from: accounts[0] }
      )
    const snowflakeBalance = await instances.Snowflake.deposits(user.identity)
    assert.isTrue(snowflakeBalance.eq(amount), 'Balances update failed')
  })

  describe("Testing wallet factory resolver", async () => {
    
    it("Testing wallet factory deployment", async () => {
      instances.ProtectedWalletFactory = await ProtectedWalletFactory.new(instances.Snowflake.address, instances.ClientRaindrop.address);
    })

    it('Testing wallet creation on addition', async () => {
      const allowance = web3.utils.toBN(1e18);
      const oneTimePass = web3.utils.soliditySha3("hehe")
      await instances.Snowflake.addResolver(instances.ProtectedWalletFactory.address, true, allowance, oneTimePass, { from: user.address })
    })

    it('Testing that wallet creation for user ein', async () => {
      walletAddr = await instances.ProtectedWalletFactory.getWalletByAddress(user.address);
      wallet = await ProtectedWallet.at(walletAddr);
      assert.isOk(walletAddr, "could not locate valid wallet")
    })

    it("Cannot create multiple wallets at the same time", async () => {
      await instances.ProtectedWalletFactory.generateNewWallet(1, web3.utils.soliditySha3("nope"), { from: user.address })
        .then(() => assert.fail)
        .catch(error => assert.include(error.message, "Ein must have deleted"))
    })
  })

  describe("Testing protected wallet resolver", async () => {
    it("Testing for correct daily limit", async () => {
      const expectedDailyLimit = web3.utils.toBN(100).mul(web3.utils.toBN(1e18));
      const contractLimit = await wallet.getDailyLimit()
      assert.isTrue(contractLimit.eq(expectedDailyLimit))
    })
    
    it("Testing wallet resolver on addition function", async () => {
      await instances.Snowflake.addResolver(wallet.address, true, web3.utils.toBN(0), "0x00", { from: user.address })
      ein = await instances.IdentityRegistry.getEIN(user.address)
    })

    it("Testing for correct password initialization", async () => {
      const expectedHash = web3.utils.soliditySha3(wallet.address, web3.utils.soliditySha3("hehe"))
      const storedHash = await wallet.getOneTimePassHash();
      assert.isTrue(expectedHash == storedHash)
    })

    it("Testing ability to adjust resolver allowances", async () => {
      const allowance = web3.utils.toBN(4000).mul(web3.utils.toBN(1e18));
      await instances.Snowflake.changeResolverAllowances([wallet.address], [allowance], { from: user.address })
      const adjustedAllowance = await instances.Snowflake.resolverAllowances(ein, wallet.address)
      assert.isOk(adjustedAllowance)
    })

    it("Testing deposits from snowflake", async () => {
      const depositAmount = web3.utils.toBN(10e18)
      await wallet.depositFromSnowflake(depositAmount, { from: user.address })
      const hydroBalance = await wallet.getHydroBalance()
      assert.isTrue(hydroBalance.eq(depositAmount))
    })

    it("Testing withdrawal to an associated address", async () => {
      const amount = web3.utils.toBN(10e18)
      await wallet.withdrawToAddress(amount, { from: user.address });
      const hydroBalance = await wallet.getHydroBalance()
      assert.isTrue(hydroBalance.eq(web3.utils.toBN(0)))
    })

    it("Testing direct deposits from address", async () => {
      const amount = web3.utils.toBN(10e18)
      await instances.HydroToken.approveAndCall(wallet.address, amount, "0x00", { from: user.address })
      const balance = await wallet.getHydroBalance()
      const hydroBalance = await wallet.getBalance()
      assert.isTrue(hydroBalance.eq(balance))
      assert.isTrue(balance.eq(amount))
    })

    it("Makes a substantial deposit and attempts to withdraw over daily limit", async () => {
      const amount = web3.utils.toBN(200).mul(web3.utils.toBN(1e18))
      await wallet.depositFromSnowflake(amount, { from: user.address })
    })

    it("Withdrawals exceeding limit throw", async () => {
      const amount = web3.utils.toBN(91e18)
      await wallet.withdrawToSnowflake(amount, { from: user.address})
        .then(() => assert.fail)
        .catch(error => assert.include(error.message, "Can only withdraw up to daily limit"))
    })

    it("Testing withdrawal to snowflake (ein)", async () => {
      const amount = web3.utils.toBN(10e18)
      const oldBal = await wallet.getHydroBalance()

      await wallet.withdrawToSnowflake(amount, { from: user.address })
      const newBal = await wallet.getHydroBalance()
      assert.isTrue(newBal.eq(oldBal.sub(amount)))
    })

    it("Testing that the daily withdrawal resets each day", async () => {
      const deposit = web3.utils.toBN(200).mul(web3.utils.toBN(1e18))
      const withdraw = web3.utils.toBN(95).mul(web3.utils.toBN(1e18))
      await wallet.depositFromSnowflake(deposit, { from: user.address })

      common.timeTravel(48601)

      await wallet.withdrawToSnowflake(withdraw, { from: user.address })
    })

    it("Testing commit/reveal scheme", async () => {
      const amount = web3.utils.toBN(10e18)
      await wallet.depositFromSnowflake(amount, { from: user.address })
      
      const commitHash = web3.utils.soliditySha3(user.address, "hehe")
      await wallet.commitHash(commitHash, { from: user.address })
      const commitExists = await wallet.checkIfCommitExists(commitHash)
      assert.isTrue(commitExists)

      await wallet.revealAndRecover(commitHash, user.address, "hehe", { from: user.address })
    })

    it("Can create a new protected wallet after reocovery phase", async () => {
      await instances.ProtectedWalletFactory.generateNewWallet(1, web3.utils.soliditySha3("test"), { from: user.address })
      const newWallet = await instances.ProtectedWalletFactory.getWalletByEIN(1)
      assert.isOk(newWallet)
      console.log(web3.utils.toBN(10e15).mul(web3.utils.toBN(10e15)))
    })

  })
})