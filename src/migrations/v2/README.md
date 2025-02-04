# Migration v2

Our goal is to deploy the latest **TOK smart contracts** to the mainnet. **Smart Contracts V2** introduce breaking changes, requiring a specific sequence of steps to successfully upgrade and migrate from **V1** to **V2**.

One of the key changes is the separation of the `BuilderRegistry` and `BackersManager` contracts, aimed at reducing the previously large contract size.

We refer to **V1** as the current live smart contracts and **V2** as the new version being deployed.

## **Steps to Execute the Migration**

### **1. Deploy the Migration Contracts**  
- Run `MigrationV2.s.sol` to:  
  - Deploy the **MigrationV2** contract.  
  - Deploy the latest **Gauges** and **BuilderRegistry** contracts.  
  - Set up the **MigrationV2** contract with all the required configuration.

### **2. Validate Migration Initialization**  
- Run the **pre-migration script** to ensure the migration contract has been correctly initialized OR/AND verify manually in the scan

### **3. Set `MigrationV2` as the Upgrader**  
- In the [**Live Governance Manager**](https://rootstock.blockscout.com/address/0x7749f092834E4446466C1A14CcC8edD526A5C1fB?tab=read_write_proxy):  
  - Assign the deployed **MigrationV2** contract address as the **`upgrader`**.  
  - This grants the contract the necessary permissions to perform the migration.

### **4. Execute the Migration**  
- Run `MigrationV2.run()`, which will perform [these steps](https://www.notion.so/V2-deployment-184c132873f9805cb90bceff4d6501fc?pvs=21).  

**This transaction will:**  
1. **Upgrade** the `BackersManager` contract to the latest implementation.  
2. **Migrate** all builders' data to the new `BuilderRegistry`.  
3. **Upgrade** all existing gauges to the latest implementation.  
4. **Reset** the `upgrader` back to the original governance address.

### **5. Validate Post-Migration Data**  
- Run the **post-migration script** to:  
  - Confirm that all **V1 builder data** has been successfully migrated to **V2**.  
  - Ensure the frontend can connect seamlessly to the new set of contracts.
        
## Fork Tests

Fork tests are run against a snapshot of the RSK Testnet/Mainnet at a specific block. These
tests ensure that v2 contract deployments behave as expected once deployed on the RSK blockchain and interact correctly
with existing live components.

Flows covered:

- `BackerManager` Upgrade is successful
- `BuilderRegistry` Deploy & migration is successful
- `Gauges` Upgrade is successful

**IMPORTANT**: If the tests require interactions with newly deployed components on the live network after the fork was
created, a new fork must be created to include those components. This is because the fork rpc url points to a specific mainnet block number.

## Running Fork Tests

Environment:

- Mainnet: `.env.30.fork`

To run the tests:

1. Select the previous environment file and apply it:

   ```sh
   direnv allow
   ```

2. Execute the test command:

   ```sh
   bun run test:fork
   ```

## Fork Environment Variables

- **`RPC_URL_FORK`**: The fork RPC URL for the RSK network. Create a virtual TestNet on Tenderly for the desired network
  and copy the generated RPC URL. The fork will point to the latest block at the time it was created.
- **`BACKERS_MANAGER_ADDRESS`**: Address of the currently live backers manager.

## License

This project is licensed under MIT.
