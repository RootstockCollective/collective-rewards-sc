# CycleTimeKeeperRootstockCollective

[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/0c4368dc418c200f21d2a798619d1dd68234c5c1/src/CycleTimeKeeperRootstockCollective.sol)

**Inherits:**
[UpgradeableRootstockCollective](/src/governance/UpgradeableRootstockCollective.sol/abstract.UpgradeableRootstockCollective.md)

## State Variables

### \_DISTRIBUTION_WINDOW

```solidity
uint256 internal constant _DISTRIBUTION_WINDOW = 1 hours;
```

### cycleData

cycle data

```solidity
CycleData public cycleData;
```

### \_\_gap

_This empty reserved space is put in place to allow future versions to add new variables without shifting down storage
in the inheritance chain. See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps_

```solidity
uint256[50] private __gap;
```

## Functions

### constructor

```solidity
constructor();
```

### \_\_CycleTimeKeeperRootstockCollective_init

contract initializer

_the first cycle will end in cycleDuration* + cycleStartOffset* seconds to to ensure that it lasts at least as long as
the desired period_

```solidity
function __CycleTimeKeeperRootstockCollective_init(
    IGovernanceManagerRootstockCollective governanceManager_,
    uint32 cycleDuration_,
    uint24 cycleStartOffset_
)
    internal
    onlyInitializing;
```

**Parameters**

| Name                 | Type                                    | Description                                                                       |
| -------------------- | --------------------------------------- | --------------------------------------------------------------------------------- |
| `governanceManager_` | `IGovernanceManagerRootstockCollective` | contract with permissioned roles                                                  |
| `cycleDuration_`     | `uint32`                                | Collective Rewards cycle time duration                                            |
| `cycleStartOffset_`  | `uint24`                                | offset to add to the first cycle, used to set an specific day to start the cycles |

### setCycleDuration

schedule a new cycle duration. It will be applied for the next cycle

_reverts if is too short. It must be greater than 2 time the distribution window_

```solidity
function setCycleDuration(uint32 newCycleDuration_, uint24 cycleStartOffset_) external onlyValidChanger;
```

**Parameters**

| Name                | Type     | Description                                                                       |
| ------------------- | -------- | --------------------------------------------------------------------------------- |
| `newCycleDuration_` | `uint32` | new cycle duration                                                                |
| `cycleStartOffset_` | `uint24` | offset to add to the first cycle, used to set an specific day to start the cycles |

### cycleStart

gets when an cycle starts based on given `timestamp_`

```solidity
function cycleStart(uint256 timestamp_) public view returns (uint256);
```

**Parameters**

| Name         | Type      | Description            |
| ------------ | --------- | ---------------------- |
| `timestamp_` | `uint256` | timestamp to calculate |

**Returns**

| Name     | Type      | Description                                |
| -------- | --------- | ------------------------------------------ |
| `<none>` | `uint256` | cycleStart timestamp when the cycle starts |

### cycleNext

gets when an cycle ends or the next one starts based on given `timestamp_`

```solidity
function cycleNext(uint256 timestamp_) public view returns (uint256);
```

**Parameters**

| Name         | Type      | Description            |
| ------------ | --------- | ---------------------- |
| `timestamp_` | `uint256` | timestamp to calculate |

**Returns**

| Name     | Type      | Description                                                |
| -------- | --------- | ---------------------------------------------------------- |
| `<none>` | `uint256` | cycleNext timestamp when the cycle ends or the next starts |

### endDistributionWindow

gets when an cycle distribution ends based on given `timestamp_`

```solidity
function endDistributionWindow(uint256 timestamp_) public view returns (uint256);
```

**Parameters**

| Name         | Type      | Description            |
| ------------ | --------- | ---------------------- |
| `timestamp_` | `uint256` | timestamp to calculate |

**Returns**

| Name     | Type      | Description                                                      |
| -------- | --------- | ---------------------------------------------------------------- |
| `<none>` | `uint256` | endDistributionWindow timestamp when the cycle distribution ends |

### timeUntilNextCycle

gets time left until the next cycle based on given `timestamp_`

```solidity
function timeUntilNextCycle(uint256 timestamp_) public view returns (uint256);
```

**Parameters**

| Name         | Type      | Description            |
| ------------ | --------- | ---------------------- |
| `timestamp_` | `uint256` | timestamp to calculate |

**Returns**

| Name     | Type      | Description                                        |
| -------- | --------- | -------------------------------------------------- |
| `<none>` | `uint256` | timeUntilNextCycle amount of time until next cycle |

### getCycleStartAndDuration

returns cycle start and duration If there is a new one and cooldown time has expired, apply that one; otherwise, apply
the previous one

```solidity
function getCycleStartAndDuration() public view returns (uint256, uint256);
```

## Events

### NewCycleDurationScheduled

```solidity
event NewCycleDurationScheduled(uint256 newCycleDuration_, uint256 cooldownEndTime_);
```

## Errors

### CycleDurationTooShort

```solidity
error CycleDurationTooShort();
```

### CycleDurationsAreNotMultiples

```solidity
error CycleDurationsAreNotMultiples();
```

### CycleDurationNotHourBasis

```solidity
error CycleDurationNotHourBasis();
```

## Structs

### CycleData

```solidity
struct CycleData {
    uint32 previousDuration;
    uint32 nextDuration;
    uint64 previousStart;
    uint64 nextStart;
    uint24 offset;
}
```
