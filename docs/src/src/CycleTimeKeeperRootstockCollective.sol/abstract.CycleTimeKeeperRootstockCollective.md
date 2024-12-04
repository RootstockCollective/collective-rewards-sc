# CycleTimeKeeperRootstockCollective

[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/6d0eca4e2c61e833bcb70c54d8668e5644ba180e/src/CycleTimeKeeperRootstockCollective.sol)

**Inherits:**
[UpgradeableRootstockCollective](/src/governance/UpgradeableRootstockCollective.sol/abstract.UpgradeableRootstockCollective.md)

## State Variables

### cycleData

cycle data

```solidity
CycleData public cycleData;
```

### distributionDuration

```solidity
uint32 public distributionDuration;
```

### \_\_gap

_This empty reserved space is put in place to allow future versions to add new variables without shifting down storage
in the inheritance chain. See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps_

```solidity
uint256[50] private __gap;
```

## Functions

### onlyValidChangerOrFoundation

```solidity
modifier onlyValidChangerOrFoundation();
```

### onlyFoundation

```solidity
modifier onlyFoundation();
```

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
    uint24 cycleStartOffset_,
    uint32 distributionDuration_
)
    internal
    onlyInitializing;
```

**Parameters**

| Name                    | Type                                    | Description                                                                       |
| ----------------------- | --------------------------------------- | --------------------------------------------------------------------------------- |
| `governanceManager_`    | `IGovernanceManagerRootstockCollective` | contract with permissioned roles                                                  |
| `cycleDuration_`        | `uint32`                                | Collective Rewards cycle time duration                                            |
| `cycleStartOffset_`     | `uint24`                                | offset to add to the first cycle, used to set an specific day to start the cycles |
| `distributionDuration_` | `uint32`                                | duration of the distribution window                                               |

### setCycleDuration

schedule a new cycle duration. It will be applied for the next cycle

_reverts if is too short. It must be greater than 2 time the distribution window_

_only callable by an authorized changer or the foundation_

```solidity
function setCycleDuration(uint32 newCycleDuration_, uint24 cycleStartOffset_) external onlyValidChangerOrFoundation;
```

**Parameters**

| Name                | Type     | Description                                                                       |
| ------------------- | -------- | --------------------------------------------------------------------------------- |
| `newCycleDuration_` | `uint32` | new cycle duration                                                                |
| `cycleStartOffset_` | `uint24` | offset to add to the first cycle, used to set an specific day to start the cycles |

### setDistributionDuration

set the duration of the distribution window

_reverts if is too short. It must be greater than 0_

_reverts if the new distribution is greater than half of the cycle duration_

_reverts if the distribution window is modified during the distribution window_

_only callable by the foundation_

```solidity
function setDistributionDuration(uint32 newDistributionDuration_) external onlyFoundation;
```

**Parameters**

| Name                       | Type     | Description                      |
| -------------------------- | -------- | -------------------------------- |
| `newDistributionDuration_` | `uint32` | new distribution window duration |

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

### \_isValidDistributionToCycleRatio

checks if the distribution and cycle duration are valid

```solidity
function _isValidDistributionToCycleRatio(
    uint32 distributionDuration_,
    uint32 cycleDuration_
)
    internal
    pure
    returns (bool);
```

**Parameters**

| Name                    | Type     | Description                         |
| ----------------------- | -------- | ----------------------------------- |
| `distributionDuration_` | `uint32` | duration of the distribution window |
| `cycleDuration_`        | `uint32` | cycle time duration                 |

**Returns**

| Name     | Type   | Description                                                               |
| -------- | ------ | ------------------------------------------------------------------------- |
| `<none>` | `bool` | true if the distribution duration is less than half of the cycle duration |

## Events

### NewCycleDurationScheduled

```solidity
event NewCycleDurationScheduled(uint256 newCycleDuration_, uint256 cooldownEndTime_);
```

### NewDistributionDuration

```solidity
event NewDistributionDuration(uint256 newDistributionDuration_, address by_);
```

## Errors

### NotValidChangerOrFoundation

```solidity
error NotValidChangerOrFoundation();
```

### CycleDurationTooShort

```solidity
error CycleDurationTooShort();
```

### DistributionDurationTooShort

```solidity
error DistributionDurationTooShort();
```

### DistributionDurationTooLong

```solidity
error DistributionDurationTooLong();
```

### DistributionModifiedDuringDistributionWindow

```solidity
error DistributionModifiedDuringDistributionWindow();
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
