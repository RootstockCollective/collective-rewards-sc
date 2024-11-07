# BuilderRegistryRootstockCollective

[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/0c4368dc418c200f21d2a798619d1dd68234c5c1/src/BuilderRegistryRootstockCollective.sol)

**Inherits:**
[CycleTimeKeeperRootstockCollective](/src/CycleTimeKeeperRootstockCollective.sol/abstract.CycleTimeKeeperRootstockCollective.md),
ERC165Upgradeable

Keeps registers of the builders

## State Variables

### \_MAX_REWARD_PERCENTAGE

```solidity
uint256 internal constant _MAX_REWARD_PERCENTAGE = UtilsLib._PRECISION;
```

### rewardDistributor

reward distributor address. If a builder is KYC revoked their unclaimed rewards will sent back here

```solidity
address public rewardDistributor;
```

### builderState

map of builders state

```solidity
mapping(address builder => BuilderState state) public builderState;
```

### builderRewardReceiver

map of builders reward receiver

```solidity
mapping(address builder => address rewardReceiver) public builderRewardReceiver;
```

### builderRewardPercentage

map of builders reward percentage data

```solidity
mapping(address builder => RewardPercentageData rewardPercentageData) public builderRewardPercentage;
```

### \_gauges

array of all the operational gauges

```solidity
EnumerableSet.AddressSet internal _gauges;
```

### \_haltedGauges

array of all the halted gauges

```solidity
EnumerableSet.AddressSet internal _haltedGauges;
```

### gaugeFactory

gauge factory contract address

```solidity
GaugeFactoryRootstockCollective public gaugeFactory;
```

### builderToGauge

gauge contract for a builder

```solidity
mapping(address builder => GaugeRootstockCollective gauge) public builderToGauge;
```

### gaugeToBuilder

builder address for a gauge contract

```solidity
mapping(GaugeRootstockCollective gauge => address builder) public gaugeToBuilder;
```

### haltedGaugeLastPeriodFinish

map of last period finish for halted gauges

```solidity
mapping(GaugeRootstockCollective gauge => uint256 lastPeriodFinish) public haltedGaugeLastPeriodFinish;
```

### rewardPercentageCooldown

time that must elapse for a new reward percentage from a builder to be applied

```solidity
uint128 public rewardPercentageCooldown;
```

### \_\_gap

_This empty reserved space is put in place to allow future versions to add new variables without shifting down storage
in the inheritance chain. See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps_

```solidity
uint256[50] private __gap;
```

## Functions

### onlyKycApprover

```solidity
modifier onlyKycApprover();
```

### \_\_BuilderRegistryRootstockCollective_init

contract initializer

```solidity
function __BuilderRegistryRootstockCollective_init(
    IGovernanceManagerRootstockCollective governanceManager_,
    address gaugeFactory_,
    address rewardDistributor_,
    uint32 cycleDuration_,
    uint24 cycleStartOffset_,
    uint128 rewardPercentageCooldown_
)
    internal
    onlyInitializing;
```

**Parameters**

| Name                        | Type                                    | Description                                                                       |
| --------------------------- | --------------------------------------- | --------------------------------------------------------------------------------- |
| `governanceManager_`        | `IGovernanceManagerRootstockCollective` | contract with permissioned roles                                                  |
| `gaugeFactory_`             | `address`                               | address of the GaugeFactoryRootstockCollective contract                           |
| `rewardDistributor_`        | `address`                               | address of the rewardDistributor contract                                         |
| `cycleDuration_`            | `uint32`                                | Collective Rewards cycle time duration                                            |
| `cycleStartOffset_`         | `uint24`                                | offset to add to the first cycle, used to set an specific day to start the cycles |
| `rewardPercentageCooldown_` | `uint128`                               | time that must elapse for a new reward percentage from a builder to be applied    |

### activateBuilder

activates builder for the first time, setting the reward receiver and the reward percentage Sets activate flag to true.
It cannot be switched to false anymore

_reverts if it is not called by the owner address reverts if it is already activated_

```solidity
function activateBuilder(
    address builder_,
    address rewardReceiver_,
    uint64 rewardPercentage_
)
    external
    onlyKycApprover;
```

**Parameters**

| Name                | Type      | Description                            |
| ------------------- | --------- | -------------------------------------- |
| `builder_`          | `address` | address of the builder                 |
| `rewardReceiver_`   | `address` | address of the builder reward receiver |
| `rewardPercentage_` | `uint64`  | reward percentage(100% == 1 ether)     |

### approveBuilderKYC

approves builder's KYC after a revocation

_reverts if it is not called by the owner address reverts if it is not activated reverts if it is already KYC approved
reverts if it does not have a gauge associated_

```solidity
function approveBuilderKYC(address builder_) external onlyKycApprover;
```

**Parameters**

| Name       | Type      | Description            |
| ---------- | --------- | ---------------------- |
| `builder_` | `address` | address of the builder |

### revokeBuilderKYC

revokes builder's KYC and sent builder unclaimed rewards to rewardDistributor contract

_reverts if it is not called by the owner address reverts if it is not KYC approved_

```solidity
function revokeBuilderKYC(address builder_) external onlyKycApprover;
```

**Parameters**

| Name       | Type      | Description            |
| ---------- | --------- | ---------------------- |
| `builder_` | `address` | address of the builder |

### whitelistBuilder

whitelist builder and create its gauge

_reverts if it is not called by the governor address or authorized changer reverts if is already whitelisted reverts if
it has a gauge associated_

```solidity
function whitelistBuilder(address builder_) external onlyValidChanger returns (GaugeRootstockCollective gauge_);
```

**Parameters**

| Name       | Type      | Description            |
| ---------- | --------- | ---------------------- |
| `builder_` | `address` | address of the builder |

**Returns**

| Name     | Type                       | Description    |
| -------- | -------------------------- | -------------- |
| `gauge_` | `GaugeRootstockCollective` | gauge contract |

### dewhitelistBuilder

de-whitelist builder

_reverts if it is not called by the governor address or authorized changer reverts if it does not have a gauge
associated reverts if it is not whitelisted_

```solidity
function dewhitelistBuilder(address builder_) external onlyValidChanger;
```

**Parameters**

| Name       | Type      | Description            |
| ---------- | --------- | ---------------------- |
| `builder_` | `address` | address of the builder |

### pauseBuilder

pause builder

_reverts if it is not called by the owner address_

```solidity
function pauseBuilder(address builder_, bytes20 reason_) external onlyKycApprover;
```

**Parameters**

| Name       | Type      | Description            |
| ---------- | --------- | ---------------------- |
| `builder_` | `address` | address of the builder |
| `reason_`  | `bytes20` | reason for the pause   |

### unpauseBuilder

unpause builder

_reverts if it is not called by the owner address reverts if it is not paused_

```solidity
function unpauseBuilder(address builder_) external onlyKycApprover;
```

**Parameters**

| Name       | Type      | Description            |
| ---------- | --------- | ---------------------- |
| `builder_` | `address` | address of the builder |

### permitBuilder

permit builder

_reverts if it does not have a gauge associated reverts if it is not KYC approved reverts if it is not whitelisted
reverts if it is not revoked reverts if it is executed in distribution period because changing the totalPotentialReward
produce a miscalculation of rewards_

```solidity
function permitBuilder(uint64 rewardPercentage_) external;
```

**Parameters**

| Name                | Type     | Description                        |
| ------------------- | -------- | ---------------------------------- |
| `rewardPercentage_` | `uint64` | reward percentage(100% == 1 ether) |

### revokeBuilder

revoke builder

_reverts if it does not have a gauge associated reverts if it is not KYC approved reverts if it is not whitelisted
reverts if it is already revoked reverts if it is executed in distribution period because changing the
totalPotentialReward produce a miscalculation of rewards_

```solidity
function revokeBuilder() external;
```

### setBuilderRewardPercentage

set a builder reward percentage

_reverts if builder is not operational_

```solidity
function setBuilderRewardPercentage(uint64 rewardPercentage_) external;
```

**Parameters**

| Name                | Type     | Description                        |
| ------------------- | -------- | ---------------------------------- |
| `rewardPercentage_` | `uint64` | reward percentage(100% == 1 ether) |

### getRewardPercentageToApply

returns reward percentage to apply. If there is a new one and cooldown time has expired, apply that one; otherwise,
apply the previous one

```solidity
function getRewardPercentageToApply(address builder_) public view returns (uint64);
```

**Parameters**

| Name       | Type      | Description            |
| ---------- | --------- | ---------------------- |
| `builder_` | `address` | address of the builder |

### isBuilderOperational

return true if builder is operational kycApproved == true && whitelisted == true && paused == false

```solidity
function isBuilderOperational(address builder_) public view returns (bool);
```

### isBuilderPaused

return true if builder is paused

```solidity
function isBuilderPaused(address builder_) public view returns (bool);
```

### isGaugeOperational

return true if gauge is operational kycApproved == true && whitelisted == true && paused == false

```solidity
function isGaugeOperational(GaugeRootstockCollective gauge_) public view returns (bool);
```

### getGaugesLength

get length of gauges array

```solidity
function getGaugesLength() public view returns (uint256);
```

### getGaugeAt

get gauge from array at a given index

```solidity
function getGaugeAt(uint256 index_) public view returns (address);
```

### isGaugeRewarded

return true is gauge is rewarded

```solidity
function isGaugeRewarded(address gauge_) public view returns (bool);
```

### getHaltedGaugesLength

get length of halted gauges array

```solidity
function getHaltedGaugesLength() public view returns (uint256);
```

### getHaltedGaugeAt

get halted gauge from array at a given index

```solidity
function getHaltedGaugeAt(uint256 index_) public view returns (address);
```

### isGaugeHalted

return true is gauge is halted

```solidity
function isGaugeHalted(address gauge_) public view returns (bool);
```

### \_createGauge

creates a new gauge for a builder

```solidity
function _createGauge(address builder_) internal returns (GaugeRootstockCollective gauge_);
```

**Parameters**

| Name       | Type      | Description                               |
| ---------- | --------- | ----------------------------------------- |
| `builder_` | `address` | builder address who can claim the rewards |

**Returns**

| Name     | Type                       | Description    |
| -------- | -------------------------- | -------------- |
| `gauge_` | `GaugeRootstockCollective` | gauge contract |

### \_validateGauge

reverts if builder was not activated or approved by the community

```solidity
function _validateGauge(GaugeRootstockCollective gauge_) internal view;
```

### \_haltGauge

halts a gauge moving it from the active array to the halted one

```solidity
function _haltGauge(GaugeRootstockCollective gauge_) internal;
```

**Parameters**

| Name     | Type                       | Description                 |
| -------- | -------------------------- | --------------------------- |
| `gauge_` | `GaugeRootstockCollective` | gauge contract to be halted |

### \_resumeGauge

resumes a gauge moving it from the halted array to the active one

_BackersManagerRootstockCollective override this function to restore its shares_

```solidity
function _resumeGauge(GaugeRootstockCollective gauge_) internal;
```

**Parameters**

| Name     | Type                       | Description                  |
| -------- | -------------------------- | ---------------------------- |
| `gauge_` | `GaugeRootstockCollective` | gauge contract to be resumed |

### \_canBeResumed

returns true if gauge can be resumed

_kycApproved == true && whitelisted == true && revoked == false_

```solidity
function _canBeResumed(GaugeRootstockCollective gauge_) internal view returns (bool);
```

**Parameters**

| Name     | Type                       | Description                  |
| -------- | -------------------------- | ---------------------------- |
| `gauge_` | `GaugeRootstockCollective` | gauge contract to be resumed |

### \_rewardTokenApprove

BackersManagerRootstockCollective override this function to modify gauge rewardToken allowance

```solidity
function _rewardTokenApprove(address gauge_, uint256 value_) internal virtual;
```

**Parameters**

| Name     | Type      | Description                            |
| -------- | --------- | -------------------------------------- |
| `gauge_` | `address` | gauge contract to approve rewardTokens |
| `value_` | `uint256` | amount of rewardTokens to approve      |

### \_haltGaugeShares

BackersManagerRootstockCollective override this function to remove its shares

```solidity
function _haltGaugeShares(GaugeRootstockCollective gauge_) internal virtual;
```

**Parameters**

| Name     | Type                       | Description                 |
| -------- | -------------------------- | --------------------------- |
| `gauge_` | `GaugeRootstockCollective` | gauge contract to be halted |

### \_resumeGaugeShares

BackersManagerRootstockCollective override this function to restore its shares

```solidity
function _resumeGaugeShares(GaugeRootstockCollective gauge_) internal virtual;
```

**Parameters**

| Name     | Type                       | Description                  |
| -------- | -------------------------- | ---------------------------- |
| `gauge_` | `GaugeRootstockCollective` | gauge contract to be resumed |

## Events

### BuilderActivated

```solidity
event BuilderActivated(address indexed builder_, address rewardReceiver_, uint64 rewardPercentage_);
```

### KYCApproved

```solidity
event KYCApproved(address indexed builder_);
```

### KYCRevoked

```solidity
event KYCRevoked(address indexed builder_);
```

### Whitelisted

```solidity
event Whitelisted(address indexed builder_);
```

### Dewhitelisted

```solidity
event Dewhitelisted(address indexed builder_);
```

### Paused

```solidity
event Paused(address indexed builder_, bytes20 reason_);
```

### Unpaused

```solidity
event Unpaused(address indexed builder_);
```

### Revoked

```solidity
event Revoked(address indexed builder_);
```

### Permitted

```solidity
event Permitted(address indexed builder_, uint256 rewardPercentage_, uint256 cooldown_);
```

### BuilderRewardPercentageUpdateScheduled

```solidity
event BuilderRewardPercentageUpdateScheduled(address indexed builder_, uint256 rewardPercentage_, uint256 cooldown_);
```

### GaugeCreated

```solidity
event GaugeCreated(address indexed builder_, address indexed gauge_, address creator_);
```

## Errors

### AlreadyActivated

```solidity
error AlreadyActivated();
```

### AlreadyKYCApproved

```solidity
error AlreadyKYCApproved();
```

### AlreadyWhitelisted

```solidity
error AlreadyWhitelisted();
```

### AlreadyRevoked

```solidity
error AlreadyRevoked();
```

### NotActivated

```solidity
error NotActivated();
```

### NotKYCApproved

```solidity
error NotKYCApproved();
```

### NotWhitelisted

```solidity
error NotWhitelisted();
```

### NotPaused

```solidity
error NotPaused();
```

### NotRevoked

```solidity
error NotRevoked();
```

### IsRevoked

```solidity
error IsRevoked();
```

### CannotRevoke

```solidity
error CannotRevoke();
```

### NotOperational

```solidity
error NotOperational();
```

### InvalidBuilderRewardPercentage

```solidity
error InvalidBuilderRewardPercentage();
```

### BuilderAlreadyExists

```solidity
error BuilderAlreadyExists();
```

### BuilderDoesNotExist

```solidity
error BuilderDoesNotExist();
```

### GaugeDoesNotExist

```solidity
error GaugeDoesNotExist();
```

## Structs

### BuilderState

```solidity
struct BuilderState {
    bool activated;
    bool kycApproved;
    bool whitelisted;
    bool paused;
    bool revoked;
    bytes7 reserved;
    bytes20 pausedReason;
}
```

### RewardPercentageData

```solidity
struct RewardPercentageData {
    uint64 previous;
    uint64 next;
    uint128 cooldownEndTime;
}
```