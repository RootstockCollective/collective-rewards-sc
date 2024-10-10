# EpochTimeKeeper

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/045ebe9238731fc66a0a58ce2ad5e824fd8a5a50/src/EpochTimeKeeper.sol)

**Inherits:** [Upgradeable](/src/governance/Upgradeable.sol/abstract.Upgradeable.md)

## State Variables

### \_DISTRIBUTION_WINDOW

```solidity
uint256 internal constant _DISTRIBUTION_WINDOW = 1 hours;
```

### epochData

epoch data

```solidity
EpochData public epochData;
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

### \_\_EpochTimeKeeper_init

contract initializer

_the first epoch will end in epochDuration* + epochStartOffset* seconds to to ensure that it lasts at least as long as
the desired period_

```solidity
function __EpochTimeKeeper_init(
    address changeExecutor_,
    uint32 epochDuration_,
    uint24 epochStartOffset_
)
    internal
    onlyInitializing;
```

**Parameters**

| Name                | Type      | Description                                                                       |
| ------------------- | --------- | --------------------------------------------------------------------------------- |
| `changeExecutor_`   | `address` | See Governed doc                                                                  |
| `epochDuration_`    | `uint32`  | epoch time duration                                                               |
| `epochStartOffset_` | `uint24`  | offset to add to the first epoch, used to set an specific day to start the epochs |

### setEpochDuration

schedule a new epoch duration. It will be applied for the next epoch

_reverts if is too short. It must be greater than 2 time the distribution window_

```solidity
function setEpochDuration(
    uint32 newEpochDuration_,
    uint24 epochStartOffset_
)
    external
    onlyGovernorOrAuthorizedChanger;
```

**Parameters**

| Name                | Type     | Description                                                                       |
| ------------------- | -------- | --------------------------------------------------------------------------------- |
| `newEpochDuration_` | `uint32` | new epoch duration                                                                |
| `epochStartOffset_` | `uint24` | offset to add to the first epoch, used to set an specific day to start the epochs |

### epochStart

gets when an epoch starts based on given `timestamp_`

```solidity
function epochStart(uint256 timestamp_) public view returns (uint256);
```

**Parameters**

| Name         | Type      | Description            |
| ------------ | --------- | ---------------------- |
| `timestamp_` | `uint256` | timestamp to calculate |

**Returns**

| Name     | Type      | Description                                |
| -------- | --------- | ------------------------------------------ |
| `<none>` | `uint256` | epochStart timestamp when the epoch starts |

### epochNext

gets when an epoch ends or the next one starts based on given `timestamp_`

```solidity
function epochNext(uint256 timestamp_) public view returns (uint256);
```

**Parameters**

| Name         | Type      | Description            |
| ------------ | --------- | ---------------------- |
| `timestamp_` | `uint256` | timestamp to calculate |

**Returns**

| Name     | Type      | Description                                                |
| -------- | --------- | ---------------------------------------------------------- |
| `<none>` | `uint256` | epochNext timestamp when the epoch ends or the next starts |

### endDistributionWindow

gets when an epoch distribution ends based on given `timestamp_`

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
| `<none>` | `uint256` | endDistributionWindow timestamp when the epoch distribution ends |

### timeUntilNextEpoch

gets time left until the next epoch based on given `timestamp_`

```solidity
function timeUntilNextEpoch(uint256 timestamp_) public view returns (uint256);
```

**Parameters**

| Name         | Type      | Description            |
| ------------ | --------- | ---------------------- |
| `timestamp_` | `uint256` | timestamp to calculate |

**Returns**

| Name     | Type      | Description                                        |
| -------- | --------- | -------------------------------------------------- |
| `<none>` | `uint256` | timeUntilNextEpoch amount of time until next epoch |

### getEpochStartAndDuration

returns epoch start and duration If there is a new one and cooldown time has expired, apply that one; otherwise, apply
the previous one

```solidity
function getEpochStartAndDuration() public view returns (uint256, uint256);
```

## Events

### NewEpochDurationScheduled

```solidity
event NewEpochDurationScheduled(uint256 newEpochDuration_, uint256 cooldownEndTime_);
```

## Errors

### EpochDurationTooShort

```solidity
error EpochDurationTooShort();
```

### EpochDurationsAreNotMultiples

```solidity
error EpochDurationsAreNotMultiples();
```

### EpochDurationNotHourBasis

```solidity
error EpochDurationNotHourBasis();
```

## Structs

### EpochData

```solidity
struct EpochData {
    uint32 previousDuration;
    uint32 nextDuration;
    uint64 previousStart;
    uint64 nextStart;
    uint24 offset;
}
```
