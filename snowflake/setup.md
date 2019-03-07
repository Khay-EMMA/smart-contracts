## Setting up the Chainlinked Wallet

1. Follow these steps to run a rinkeby node https://docs.chain.link/docs/run-an-ethereum-client, make sure to select rinkeby for each step when following the instructions

2. Follow these steps to run a chainlink node with docker https://docs.chain.link/docs/running-a-chainlink-node, again make sure you are selecting rinkeby for each step

3. Copy the flattenedOracle.sol contract from the chainlink directory into remix, copy the Oracle address from the protectedWallet.sol contract in the main project directory, select the run tab on remix, select the Oracle contract for deployment, and paste the Oracle address into the "At Address" field on remix.

4. The Oracle contract interface should now be available in the deployed contracts section of remix.  Now, navigate to localhost:6689 in your browser, use the credentials you set when configuring your chainlink node to login, select the configuration tab on the top bar, copy the value for the "account address", then navigate back to remix.  Now, paste the account address you just copied as the first parameter for the setFulfillmentPermission function, and set the second parameter to true.

5.  Next, from your metamask wallet, fund your chainlink node account address with some ether.

6.  Navigate back to your chainlink gui at localhost:6689 and select the "bridges" tab at the top, click "New Bridge"

7.  In the bridge name field type chainlinked2fa, in the bridge url field  paste the following url: https://wd3yvpd7g3.execute-api.us-east-1.amazonaws.com/default/hydro-adapter

8. In the confirmations field enter 4

9. Now, navigate to the "Jobs" tab in the chainlink gui.  Select "New Job"  and paste the following JSON blob into the JSON field:

```{
	"initiators": [
		{
			"type": "runlog",
			"params": {
				"address": "0x0000000000000000000000000000000000000000"
			}
		}
	],
	"tasks": [
		{
			"ID": 1,
			"CreatedAt": "2019-02-27T18:39:44.596931223Z",
			"UpdatedAt": "2019-02-27T19:08:56.949697434Z",
			"DeletedAt": null,
			"type": "chainlinked2fa",
			"confirmations": 0,
			"params": {}
		},
		{
			"ID": 2,
			"CreatedAt": "2019-02-27T18:39:44.601403868Z",
			"UpdatedAt": "2019-02-27T19:08:56.952996989Z",
			"DeletedAt": null,
			"type": "copy",
			"confirmations": 0,
			"params": {
				"copyPath": [
					"verified"
				]
			}
		},
		{
			"ID": 3,
			"CreatedAt": "2019-02-27T18:39:44.601554911Z",
			"UpdatedAt": "2019-02-27T19:08:56.953100614Z",
			"DeletedAt": null,
			"type": "ethbool",
			"confirmations": 0,
			"params": {}
		},
		{
			"ID": 4,
			"CreatedAt": "2019-02-27T18:39:44.601631397Z",
			"UpdatedAt": "2019-02-27T19:08:56.953192181Z",
			"DeletedAt": null,
			"type": "ethtx",
			"confirmations": 0,
			"params": {}
		}
	],
	"startAt": null,
	"endAt": null
}```

10. Confirm the job addition, and copy the associated ID of the new job spec.  The ID should look something like f26b8184a106449c9a81ccdae1ef0b5c.  Now, head to the protected wallet smart contract, and for each of the chainlink job identifies EXCEPT the HYDRO_ID_JOB, paste in the new job id.  For example, bytes32 LIMIT_JOB should now be set equal to bytes32("YOUR_JOB_ID");

11. Now, you're ready to deploy the updated contracts.  Navigate to the snowflake directory and run `truffle migrate --network rinkeby_infura`.  This part might take a few minutes to complete.

12.  After the contracts have been successfully deployed, the deployment script should log the factory contract address.  Copy the factory contract address and navigate to the dashboard react code.  Replace the following four addresses with the address of your deployed contract address.  1.  The name of the folder that contains the code for the chainlink wallet frontend 2. the address of the protected wallet factory in index.js 3. The address on line 96 in DAppStore.js 4. The address on line 53 in WalletFactory.js

13.  Now you're ready to use the wallet! Spin up the dashboard and give it a shot.
