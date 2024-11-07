# GaugeBeaconRootstockCollective

[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/0c4368dc418c200f21d2a798619d1dd68234c5c1/src/gauge/GaugeBeaconRootstockCollective.sol)

**Inherits:** UpgradeableBeacon

## State Variables

### governanceManager

```solidity
IGovernanceManagerRootstockCollective public governanceManager;
```

## Functions

### constructor

constructor

```solidity
constructor(
    IGovernanceManagerRootstockCollective governanceManager_,
    address gaugeImplementation_
)
    UpgradeableBeacon(gaugeImplementation_, governanceManager_.governor());
```

**Parameters**

| Name                   | Type                                    | Description                                 |
| ---------------------- | --------------------------------------- | ------------------------------------------- |
| `governanceManager_`   | `IGovernanceManagerRootstockCollective` | contract with permissioned roles            |
| `gaugeImplementation_` | `address`                               | address of the Gauge initial implementation |

### \_checkOwner

The owner is the governor but we need more flexibility to allow changes. So, ownable protected functions can be executed
also by an authorized changer executed by the governor

_Due we cannot override UpgradeableBeacon.sol to remove the OnlyOwner modifier on upgradeTo function we need to override
this function to allow upgrade the beacon by a changer_

```solidity
function _checkOwner() internal view override;
```
