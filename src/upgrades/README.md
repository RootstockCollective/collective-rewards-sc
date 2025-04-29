# Upgrade v3

Our goal is to deploy the latest **Collective Rewards smart contracts** to the mainnet. We refer to **V2** as the current live smart contracts and **V3** as the new version being deployed.

The changes are scattered across 5 upgradeable smart contracts, and all of them need to be upgraded:
- BackersManagerRootstockCollective
- BuilderRegistryRootstockCollective
- GovernanceManagerRootstockCollective
- GaugeRootstockCollective
- RewardDistributorRootstockCollective

These contract upgrades are performed atomically within a single transaction. 
However, some setup steps need to performed prior to execute the upgrade.

## **Steps to Execute the Upgrade**

### **1. Deploy the Upgrade Contracts**  
- Run `upgrades/UpgradeV3.s.sol` to:  
  - Deploy v3 contracts modified in v3
    - The addresses of the deployments will later be used to upgrade the proxys'
  - Deploy **UpgradeV3** contract
    - This requires construction data to be passed to properly setup the UpgradeV3 execution

### **2. Set `UpgradeV3` as the Upgrader**  
- In the [**Live Governance Manager**](https://rootstock.blockscout.com/address/0x7749f092834E4446466C1A14CcC8edD526A5C1fB?tab=read_write_proxy)
  - Assign the deployed **UpgradeV3** contract address as the **`upgrader`**.  
  - This grants the contract the necessary permissions to perform the upgrade.

### **3. Execute the Upgrade**  
- Execute transaction `UpgradeV3.run()` from any wallet (permissionless method)

**This transaction will:**  
1. **Upgrade** `BackersManager` contract to the latest implementation, and initialize v3 data
1. **Upgrade** `BuilderRegistry` contract to the latest implementation.
3. **Upgrade** `GovernanceManager`contract to the latest implementation.
3. **Upgrade** `RewardDistributor`contract to the latest implementation.
3. **Upgrade** `GaugeBeacon` to point to the latest gauges implementation.  
4. **Reset** the `upgrader` back to the original in the governance address.

## Fork Tests

Fork tests run with the RSK Testnet/Mainnet network RPC, allowing the tests to run on top of the live blockchain data. 
These tests ensure that the upgrade flow will behave properly when running on the live network.

### Run tests
- Select env: `direnv allow`
- Run upgrade tests: `bun run test:fork`

## License

This project is licensed under MIT.
