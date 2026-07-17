# Upgrade v3

V3 has been **executed on mainnet and testnet**. This document is kept as a historical reference for the upgrade that was performed.

The changes were scattered across 5 upgradeable smart contracts, and all of them were upgraded:
- BackersManagerRootstockCollective
- BuilderRegistryRootstockCollective
- GovernanceManagerRootstockCollective
- GaugeRootstockCollective
- RewardDistributorRootstockCollective

These contract upgrades were performed atomically within a single transaction.

## Steps That Were Executed

### **1. Deploy the Upgrade Contracts**
- Ran `script/upgrades/UpgradeV3.s.sol` to:
  - Deploy v3 implementation contracts
  - Deploy the **UpgradeV3** orchestrator contract

### **2. Set `UpgradeV3` as the Upgrader**
- In the [**Live Governance Manager**](https://rootstock.blockscout.com/address/0x7749f092834E4446466C1A14CcC8edD526A5C1fB?tab=read_write_proxy)
  - Assigned the deployed **UpgradeV3** contract address as the **`upgrader`**.

### **3. Execute the Upgrade**
- Executed `UpgradeV3.run()` (permissionless)

**That transaction:**
1. **Upgraded** `BackersManager` and initialized v3 data
2. **Upgraded** `BuilderRegistry`
3. **Upgraded** `GovernanceManager`
4. **Upgraded** `RewardDistributor`
5. **Upgraded** `GaugeBeacon` to the latest gauge implementation
6. **Reset** the `upgrader` back to the original address

Deployed addresses are recorded in `deployments/<context>/contract_addresses.json`.

## License

This project is licensed under MIT.
