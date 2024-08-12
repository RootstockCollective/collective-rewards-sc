# BuilderGauge

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/c4d78ff998298ce9e3dffdd99f32430a3c5ed3af/src/builder/BuilderGauge.sol)

For each project proposal a BuilderGauge contract will be deployed. It receives all the rewards obtained for that
project and allows the builder and supportrs to claim them.

## State Variables

### builder

builder address

```solidity
address public immutable builder;
```

### rewardToken

address of the token rewarded to builder and supportrs

```solidity
IERC20 public immutable rewardToken;
```

### supportHub

SupportHub contract address

```solidity
SupportHub public immutable supportHub;
```

### totalAllocation

total amount of stakingToken allocated for rewards

```solidity
uint256 public totalAllocation;
```

### rewardRate

current reward rate of rewardToken to distribute per second [PREC]

```solidity
uint256 public rewardRate;
```

### rewardPerTokenStored

most recent stored value of rewardPerToken [PREC]

```solidity
uint256 public rewardPerTokenStored;
```

### rewardMissing

missing rewards where there is not allocation [PREC]

```solidity
uint256 public rewardMissing;
```

### lastUpdateTime

most recent timestamp contract has updated state

```solidity
uint256 public lastUpdateTime;
```

### periodFinish

timestamp end of current rewards period

```solidity
uint256 public periodFinish;
```

### builderRewards

amount of unclaimed token reward earned for the builder

```solidity
uint256 public builderRewards;
```

### allocationOf

amount of stakingToken allocated by a supporter

```solidity
mapping(address supporter => uint256 allocation) public allocationOf;
```

### supporterRewardPerTokenPaid

cached rewardPerTokenStored for a supporter based on their most recent action [PREC]

```solidity
mapping(address supporter => uint256 rewardPerTokenPaid) public supporterRewardPerTokenPaid;
```

### rewards

cached amount of rewardToken earned for a supporter

```solidity
mapping(address supporter => uint256 rewards) public rewards;
```

## Functions

### onlySponsorsManager

```solidity
modifier onlySponsorsManager();
```

### constructor

constructor

```solidity
constructor(address builder_, address rewardToken_, address supportHub_);
```

**Parameters**

| Name           | Type      | Description                                            |
| -------------- | --------- | ------------------------------------------------------ |
| `builder_`     | `address` | address of the builder                                 |
| `rewardToken_` | `address` | address of the token rewarded to builder and supportrs |
| `supportHub_`  | `address` | address of the SupportHub contract                     |

### rewardPerToken

gets the current reward rate per unit of stakingToken allocated

```solidity
function rewardPerToken() public view returns (uint256);
```

**Returns**

| Name     | Type      | Description                                          |
| -------- | --------- | ---------------------------------------------------- |
| `<none>` | `uint256` | rewardPerToken rewardToken:stakingToken ratio [PREC] |

### lastTimeRewardApplicable

gets the last time the reward is applicable, now or when the epoch finished

```solidity
function lastTimeRewardApplicable() public view returns (uint256);
```

**Returns**

| Name     | Type      | Description                                                                |
| -------- | --------- | -------------------------------------------------------------------------- |
| `<none>` | `uint256` | lastTimeRewardApplicable minimum between current timestamp or periodFinish |

### left

gets total amount of rewards to distribute for the current rewards period

```solidity
function left() external view returns (uint256);
```

### claimSponsorReward

claim rewards for a `supporter_` address

_reverts if is not called by the `supporter_` or the supportHub\_

```solidity
function claimSponsorReward(address supporter_) external;
```

**Parameters**

| Name         | Type      | Description                      |
| ------------ | --------- | -------------------------------- |
| `supporter_` | `address` | address who receives the rewards |

### claimBuilderReward

claim rewards for a builder

_reverts if is not called by the builder or reward receiver_

_rewards are transferred to the builder reward receiver_

```solidity
function claimBuilderReward(address builder_) external;
```

### earned

gets `supporter_` rewards missing to claim

```solidity
function earned(address supporter_) public view returns (uint256);
```

**Parameters**

| Name         | Type      | Description                    |
| ------------ | --------- | ------------------------------ |
| `supporter_` | `address` | address who earned the rewards |

### allocate

allocates stakingTokens

_reverts if caller si not the supportHub contract_

```solidity
function allocate(
    address supporter_,
    uint256 allocation_
)
    external
    onlySponsorsManager
    returns (uint256 allocationDeviation, bool isNegative);
```

**Parameters**

| Name          | Type      | Description                          |
| ------------- | --------- | ------------------------------------ |
| `supporter_`  | `address` | address of user who allocates tokens |
| `allocation_` | `uint256` | amount of tokens to allocate         |

**Returns**

| Name                  | Type      | Description                                           |
| --------------------- | --------- | ----------------------------------------------------- |
| `allocationDeviation` | `uint256` | deviation between current allocation and the new one  |
| `isNegative`          | `bool`    | true if new allocation is lesser than the current one |

### notifyRewardAmount

called on the reward distribution. Transfers reward tokens from supporterManger to this contract

_reverts if caller si not the supportHub contract_

```solidity
function notifyRewardAmount(uint256 builderAmount_, uint256 supportersAmount_) external onlySponsorsManager;
```

**Parameters**

| Name                | Type      | Description                          |
| ------------------- | --------- | ------------------------------------ |
| `builderAmount_`    | `uint256` | amount of rewards for the builder    |
| `supportersAmount_` | `uint256` | amount of rewards for the supporters |

### \_updateRewards

```solidity
function _updateRewards(address supporter_) internal;
```

## Events

### SponsorRewardsClaimed

```solidity
event SponsorRewardsClaimed(address indexed supporter_, uint256 amount_);
```

### BuilderRewardsClaimed

```solidity
event BuilderRewardsClaimed(address indexed builder_, uint256 amount_);
```

### SupportAllocated

```solidity
event SupportAllocated(address indexed supporter_, uint256 allocation_);
```

### RewardsReceived

```solidity
event RewardsReceived(uint256 builderAmount_, uint256 supportersAmount_);
```

## Errors

### NotAuthorized

```solidity
error NotAuthorized();
```

### NotSponsorsManager

```solidity
error NotSponsorsManager();
```
