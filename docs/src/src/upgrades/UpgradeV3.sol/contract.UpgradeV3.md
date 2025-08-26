# UpgradeV3
[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/dddd380a18864fe36c9ec409abd3170e82ca6a46/src/upgrades/UpgradeV3.sol)

Migrate the mainnet live contracts to V3


## State Variables
### backersManagerProxy

```solidity
BackersManagerRootstockCollective public backersManagerProxy;
```


### backersManagerImplV3

```solidity
BackersManagerRootstockCollective public backersManagerImplV3;
```


### builderRegistryProxy

```solidity
BuilderRegistryRootstockCollective public builderRegistryProxy;
```


### builderRegistryImplV3

```solidity
BuilderRegistryRootstockCollective public builderRegistryImplV3;
```


### governanceManagerProxy

```solidity
GovernanceManagerRootstockCollective public governanceManagerProxy;
```


### governanceManagerImplV3

```solidity
GovernanceManagerRootstockCollective public governanceManagerImplV3;
```


### gaugeBeacon

```solidity
GaugeBeaconRootstockCollective public gaugeBeacon;
```


### gaugeImplV3

```solidity
GaugeRootstockCollective public gaugeImplV3;
```


### rewardDistributorProxy

```solidity
RewardDistributorRootstockCollective public rewardDistributorProxy;
```


### rewardDistributorImplV3

```solidity
RewardDistributorRootstockCollective public rewardDistributorImplV3;
```


### upgrader

```solidity
address public upgrader;
```


### configurator

```solidity
address public configurator;
```


### usdrifToken

```solidity
address public usdrifToken;
```


### MAX_DISTRIBUTIONS_PER_BATCH

```solidity
uint256 public constant MAX_DISTRIBUTIONS_PER_BATCH = 20;
```


## Functions
### constructor


```solidity
constructor(
    BackersManagerRootstockCollective backersManagerProxy_,
    BackersManagerRootstockCollective backersManagerImplV3_,
    BuilderRegistryRootstockCollective builderRegistryImplV3_,
    GovernanceManagerRootstockCollective governanceManagerImplV3_,
    GaugeRootstockCollective gaugeImplV3_,
    RewardDistributorRootstockCollective rewardDistributorProxy_,
    RewardDistributorRootstockCollective rewardDistributorImplV3_,
    address configurator_,
    address usdrifToken_
);
```

### run


```solidity
function run() public;
```

### resetUpgrader

Resets the upgrader role back to the original address

*reverts if not called by the original upgrader*

*Prevents this contract from being permanently stuck with the upgrader role if upgrades are no longer needed*


```solidity
function resetUpgrader() public;
```

### _upgradeBackersManager


```solidity
function _upgradeBackersManager() internal;
```

### _upgradeGovernanceManager


```solidity
function _upgradeGovernanceManager() internal;
```

### _upgradeBuilderRegistry


```solidity
function _upgradeBuilderRegistry() internal;
```

### _upgradeGauges


```solidity
function _upgradeGauges() internal;
```

### _upgradeRewardDistributor


```solidity
function _upgradeRewardDistributor() internal;
```

### _resetUpgrader


```solidity
function _resetUpgrader() internal;
```

## Errors
### NotUpgrader

```solidity
error NotUpgrader();
```

