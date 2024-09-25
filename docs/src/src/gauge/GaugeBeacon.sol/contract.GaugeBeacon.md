# GaugeBeacon

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/1055faa4ca92d30ddb8e7825f3f21882bdff7522/src/gauge/GaugeBeacon.sol)

**Inherits:** UpgradeableBeacon, [Governed](/src/governance/Governed.sol/abstract.Governed.md)

## Functions

### constructor

constructor

```solidity
constructor(
    address changeExecutor_,
    address gaugeImplementation_
)
    UpgradeableBeacon(gaugeImplementation_, IChangeExecutor(changeExecutor_).governor());
```

**Parameters**

| Name                   | Type      | Description                                 |
| ---------------------- | --------- | ------------------------------------------- |
| `changeExecutor_`      | `address` | ChangeExecutor contract address             |
| `gaugeImplementation_` | `address` | address of the Gauge initial implementation |

### governor

maintains Governed interface. Returns governed address

```solidity
function governor() public view override returns (address);
```

### \_checkOwner

The owner is the governor but we need more flexibility to allow changes. So, ownable protected functions can be executed
also by an authorized changer executed by the governor

_Due we cannot override UpgradeableBeacon.sol to remove the OnlyOwner modifier on upgradeTo function we need to override
this function to allow upgrade the beacon by a changer_

```solidity
function _checkOwner() internal view override onlyGovernorOrAuthorizedChanger;
```
