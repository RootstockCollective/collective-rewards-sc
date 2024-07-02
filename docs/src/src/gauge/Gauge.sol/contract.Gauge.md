# Gauge

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/14cb3d6c0a3b4e9b40a07d5427da7713e285f5ef/src/gauge/Gauge.sol)

For each project proposal a Gauge contract will be deployed. It receives all the rewards obtained for that project and
allows the builder and voters to claim them.

## State Variables

### rewardToken

address of the token rewarded to builder and voters

```solidity
IERC20 public immutable rewardToken;
```

### sponsorsManager

```solidity
address public immutable sponsorsManager;
```

### totalAllocation

total amount of stakingToken allocated for rewards

```solidity
uint256 public totalAllocation;
```

### rewardRate

current reward rate of rewardToken to distribute per second

```solidity
uint256 public rewardRate;
```

### rewardPerTokenStored

most recent stored value of rewardPerToken

```solidity
uint256 public rewardPerTokenStored;
```

### rewardMissing

missing rewards where there is not allocation

```solidity
uint256 public rewardMissing;
```

### lastUpdateTime

most recent timestamp contract has updated state

```solidity
uint256 public lastUpdateTime;
```

### periodFinish

```solidity
uint256 public periodFinish;
```

### allocationOf

amount of stakingToken allocated by a sponsor

```solidity
mapping(address sponsor => uint256 allocation) public allocationOf;
```

### sponsorRewardPerTokenPaid

cached rewardPerTokenStored for a sponsor based on their most recent action

```solidity
mapping(address sponsor => uint256 rewardPerTokenPaid) public sponsorRewardPerTokenPaid;
```

### rewards

cached amount of rewardToken earned for a sponsor

```solidity
mapping(address sponsor => uint256 rewards) public rewards;
```

### rewardRateByEpoch

view to see rewardRate given the timestamp of the start of the epoch

```solidity
mapping(uint256 epoch => uint256 rewardRate) public rewardRateByEpoch;
```

### totalAllocationByEpoch

view to see the totalAllocation given the timestamp of the start of the epoch

```solidity
mapping(uint256 epoch => uint256 totalSupply) public totalAllocationByEpoch;
```

## Functions

### onlySponsorsManager

```solidity
modifier onlySponsorsManager();
```

### constructor

constructor

```solidity
constructor(address rewardToken_, address sponsorsManager_);
```

**Parameters**

| Name               | Type      | Description                                         |
| ------------------ | --------- | --------------------------------------------------- |
| `rewardToken_`     | `address` | address of the token rewarded to builder and voters |
| `sponsorsManager_` | `address` | address of the SponsorsManager contract             |

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

### getSponsorReward

gets rewards for an `sponsor_` address

_reverts if is not called by the `sponsor_` or the sponsorsManager\_

```solidity
function getSponsorReward(address sponsor_) external;
```

**Parameters**

| Name       | Type      | Description                      |
| ---------- | --------- | -------------------------------- |
| `sponsor_` | `address` | address who receives the rewards |

### earned

gets `sponsor_` rewards missing to claim

```solidity
function earned(address sponsor_) public view returns (uint256);
```

### allocate

allocates stakingTokens

_reverts if caller si not the sponsorsManager contract_

```solidity
function allocate(address sponsor_, uint256 allocation_) external onlySponsorsManager;
```

**Parameters**

| Name          | Type      | Description                          |
| ------------- | --------- | ------------------------------------ |
| `sponsor_`    | `address` | address of user who allocates tokens |
| `allocation_` | `uint256` | amount of tokens to allocate         |

### deallocate

deallocates stakingTokens

_reverts if caller si not the sponsorsManager contract_

```solidity
function deallocate(address sponsor_, uint256 allocation_) external onlySponsorsManager;
```

**Parameters**

| Name          | Type      | Description                            |
| ------------- | --------- | -------------------------------------- |
| `sponsor_`    | `address` | address of user who deallocates tokens |
| `allocation_` | `uint256` | amount of tokens to deallocate         |

### notifyRewardAmount

called on the reward distribution. Transfers reward tokens from sponsorManger to this contract

_reverts if caller si not the sponsorsManager contract_

```solidity
function notifyRewardAmount(uint256 amount_) external onlySponsorsManager;
```

**Parameters**

| Name      | Type      | Description                           |
| --------- | --------- | ------------------------------------- |
| `amount_` | `uint256` | amount of reward tokens to distribute |

### \_updateRewards

```solidity
function _updateRewards(address sponsor_) internal;
```

## Events

### SponsorRewardsClaimed

```solidity
event SponsorRewardsClaimed(address indexed sponsor_, uint256 amount_);
```

### Allocated

```solidity
event Allocated(address indexed from, address indexed sponsor_, uint256 allocation_);
```

### Deallocated

```solidity
event Deallocated(address indexed sponsor_, uint256 allocation_);
```

### NotifyReward

```solidity
event NotifyReward(uint256 amount_);
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

### ZeroRewardRate

```solidity
error ZeroRewardRate();
```

### RewardRateTooHigh

```solidity
error RewardRateTooHigh();
```