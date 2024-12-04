# GaugeRootstockCollective

[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/6d0eca4e2c61e833bcb70c54d8668e5644ba180e/src/gauge/GaugeRootstockCollective.sol)

**Inherits:** ReentrancyGuardUpgradeable

For each project proposal a Gauge contract will be deployed. It receives all the rewards obtained for that project and
allows the builder and voters to claim them.

## State Variables

### rewardToken

address of the token rewarded to builder and voters

```solidity
address public rewardToken;
```

### backersManager

BackersManagerRootstockCollective contract address

```solidity
IBackersManagerRootstockCollective public backersManager;
```

### totalAllocation

total amount of stakingToken allocated for rewards

```solidity
uint256 public totalAllocation;
```

### rewardShares

cycle rewards shares, optimistically tracking the time weighted votes allocations for this gauge

```solidity
uint256 public rewardShares;
```

### allocationOf

amount of stakingToken allocated by a backer

```solidity
mapping(address backer => uint256 allocation) public allocationOf;
```

### rewardData

rewards data to each token

_address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address_

```solidity
mapping(address rewardToken => RewardData rewardData) public rewardData;
```

### \_\_gap

_This empty reserved space is put in place to allow future versions to add new variables without shifting down storage
in the inheritance chain. See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps_

```solidity
uint256[50] private __gap;
```

## Functions

### onlyBackersManager

```solidity
modifier onlyBackersManager();
```

### minIncentiveAmount

prevents spamming of incentives mechanism with low values to introduce errors

_100 should cover any potential rounding errors_

```solidity
modifier minIncentiveAmount(uint256 amount_);
```

### constructor

```solidity
constructor();
```

### initialize

contract initializer

```solidity
function initialize(address rewardToken_, address backersManager_) external initializer;
```

**Parameters**

| Name              | Type      | Description                                               |
| ----------------- | --------- | --------------------------------------------------------- |
| `rewardToken_`    | `address` | address of the token rewarded to builder and voters       |
| `backersManager_` | `address` | address of the BackersManagerRootstockCollective contract |

### rewardRate

gets reward rate

```solidity
function rewardRate(address rewardToken_) public view returns (uint256);
```

**Parameters**

| Name           | Type      | Description                                                                                                         |
| -------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_` | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |

### rewardPerTokenStored

gets reward per token stored

```solidity
function rewardPerTokenStored(address rewardToken_) public view returns (uint256);
```

**Parameters**

| Name           | Type      | Description                                                                                                         |
| -------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_` | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |

### rewardMissing

gets reward missing

```solidity
function rewardMissing(address rewardToken_) public view returns (uint256);
```

**Parameters**

| Name           | Type      | Description                                                                                                         |
| -------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_` | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |

### lastUpdateTime

gets last update time

```solidity
function lastUpdateTime(address rewardToken_) public view returns (uint256);
```

**Parameters**

| Name           | Type      | Description                                                                                                         |
| -------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_` | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |

### builderRewards

gets builder rewards

```solidity
function builderRewards(address rewardToken_) public view returns (uint256);
```

**Parameters**

| Name           | Type      | Description                                                                                                         |
| -------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_` | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |

### backerRewardPerTokenPaid

gets backer reward per token paid

```solidity
function backerRewardPerTokenPaid(address rewardToken_, address backer_) public view returns (uint256);
```

**Parameters**

| Name           | Type      | Description                                                                                                         |
| -------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_` | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |
| `backer_`      | `address` |                                                                                                                     |

### estimatedBackerRewards

gets the estimated amount of rewardToken left to earn for a backer in current cycle

```solidity
function estimatedBackerRewards(address rewardToken_, address backer_) external view returns (uint256);
```

**Parameters**

| Name           | Type      | Description                                                                                                         |
| -------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_` | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |
| `backer_`      | `address` | address of the backer                                                                                               |

### rewards

gets amount of rewardToken earned for a backer

```solidity
function rewards(address rewardToken_, address backer_) public view returns (uint256);
```

**Parameters**

| Name           | Type      | Description                                                                                                         |
| -------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_` | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |
| `backer_`      | `address` | address of the backer                                                                                               |

### lastTimeRewardApplicable

gets the last time the reward is applicable, now or when the cycle finished

```solidity
function lastTimeRewardApplicable() public view returns (uint256);
```

**Returns**

| Name     | Type      | Description                                                                |
| -------- | --------- | -------------------------------------------------------------------------- |
| `<none>` | `uint256` | lastTimeRewardApplicable minimum between current timestamp or periodFinish |

### rewardPerToken

gets the current reward rate per unit of stakingToken allocated

```solidity
function rewardPerToken(address rewardToken_) public view returns (uint256);
```

**Parameters**

| Name           | Type      | Description                                                                                                         |
| -------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_` | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |

**Returns**

| Name     | Type      | Description                                          |
| -------- | --------- | ---------------------------------------------------- |
| `<none>` | `uint256` | rewardPerToken rewardToken:stakingToken ratio [PREC] |

### left

gets total amount of rewards to distribute for the current rewards period

```solidity
function left(address rewardToken_) external view returns (uint256);
```

**Parameters**

| Name           | Type      | Description                                                                                                         |
| -------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_` | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |

### earned

gets `backer_` rewards missing to claim

```solidity
function earned(address rewardToken_, address backer_) public view returns (uint256);
```

**Parameters**

| Name           | Type      | Description                                                                                                         |
| -------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_` | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |
| `backer_`      | `address` | address who earned the rewards                                                                                      |

### claimBackerReward

claim rewards for a `backer_` address

_reverts if is not called by the `backer_` or the backersManager\_

```solidity
function claimBackerReward(address backer_) public;
```

**Parameters**

| Name      | Type      | Description                      |
| --------- | --------- | -------------------------------- |
| `backer_` | `address` | address who receives the rewards |

### claimBackerReward

claim rewards for a `backer_` address

_reverts if is not called by the `backer_` or the backersManager\_

```solidity
function claimBackerReward(address rewardToken_, address backer_) public;
```

**Parameters**

| Name           | Type      | Description                                                                                                         |
| -------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_` | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |
| `backer_`      | `address` | address who receives the rewards                                                                                    |

### claimBuilderReward

claim rewards for a builder

_reverts if is not called by the builder or reward receiver reverts if builder is not operational_

_rewards are transferred to the builder reward receiver_

```solidity
function claimBuilderReward() public;
```

### claimBuilderReward

claim rewards for a builder

_reverts if is not called by the builder or reward receiver_

_rewards are transferred to the builder reward receiver_

```solidity
function claimBuilderReward(address rewardToken_) public;
```

**Parameters**

| Name           | Type      | Description                                                                                                         |
| -------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_` | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |

### moveBuilderUnclaimedRewards

moves builder rewards to another address It is triggered only when the builder is KYC revoked

_reverts if caller is not the backersManager contract_

```solidity
function moveBuilderUnclaimedRewards(address to_) external onlyBackersManager;
```

**Parameters**

| Name  | Type      | Description                      |
| ----- | --------- | -------------------------------- |
| `to_` | `address` | address who receives the rewards |

### allocate

allocates stakingTokens

_reverts if caller is not the backersManager contract_

```solidity
function allocate(
    address backer_,
    uint256 allocation_,
    uint256 timeUntilNextCycle_
)
    external
    onlyBackersManager
    returns (uint256 allocationDeviation_, uint256 rewardSharesDeviation_, bool isNegative_);
```

**Parameters**

| Name                  | Type      | Description                          |
| --------------------- | --------- | ------------------------------------ |
| `backer_`             | `address` | address of user who allocates tokens |
| `allocation_`         | `uint256` | amount of tokens to allocate         |
| `timeUntilNextCycle_` | `uint256` | time until next cycle                |

**Returns**

| Name                     | Type      | Description                                             |
| ------------------------ | --------- | ------------------------------------------------------- |
| `allocationDeviation_`   | `uint256` | deviation between current allocation and the new one    |
| `rewardSharesDeviation_` | `uint256` | deviation between current reward shares and the new one |
| `isNegative_`            | `bool`    | true if new allocation is lesser than the current one   |

### incentivizeWithRewardToken

transfers reward tokens to this contract to incentivize backers

_reverts if Gauge is halted reverts if distribution for the cycle has not finished_

```solidity
function incentivizeWithRewardToken(uint256 amount_) external minIncentiveAmount(amount_);
```

**Parameters**

| Name      | Type      | Description             |
| --------- | --------- | ----------------------- |
| `amount_` | `uint256` | amount of reward tokens |

### incentivizeWithCoinbase

transfers coinbase to this contract to incentivize backers

_reverts if Gauge is halted reverts if distribution for the cycle has not finished_

```solidity
function incentivizeWithCoinbase() external payable minIncentiveAmount(msg.value);
```

### notifyRewardAmountAndUpdateShares

called on the reward distribution. Transfers reward tokens from backerManger to this contract

_reverts if caller is not the backersManager contract_

```solidity
function notifyRewardAmountAndUpdateShares(
    uint256 amountERC20_,
    uint256 backerRewardPercentage_,
    uint256 periodFinish_,
    uint256 cycleStart_,
    uint256 cycleDuration_
)
    external
    payable
    onlyBackersManager
    returns (uint256 newGaugeRewardShares_);
```

**Parameters**

| Name                      | Type      | Description                              |
| ------------------------- | --------- | ---------------------------------------- |
| `amountERC20_`            | `uint256` | amount of ERC20 rewards                  |
| `backerRewardPercentage_` | `uint256` | backers reward percentage                |
| `periodFinish_`           | `uint256` | timestamp end of current rewards period  |
| `cycleStart_`             | `uint256` | Collective Rewards cycle start timestamp |
| `cycleDuration_`          | `uint256` | Collective Rewards cycle time duration   |

**Returns**

| Name                    | Type      | Description                                            |
| ----------------------- | --------- | ------------------------------------------------------ |
| `newGaugeRewardShares_` | `uint256` | new gauge rewardShares, updated after the distribution |

### \_lastTimeRewardApplicable

gets the last time the reward is applicable, now or when the cycle finished

```solidity
function _lastTimeRewardApplicable(uint256 periodFinish_) internal view returns (uint256);
```

**Parameters**

| Name            | Type      | Description                             |
| --------------- | --------- | --------------------------------------- |
| `periodFinish_` | `uint256` | timestamp end of current rewards period |

**Returns**

| Name     | Type      | Description                                                                |
| -------- | --------- | -------------------------------------------------------------------------- |
| `<none>` | `uint256` | lastTimeRewardApplicable minimum between current timestamp or periodFinish |

### \_rewardPerToken

gets the current reward rate per unit of stakingToken allocated

```solidity
function _rewardPerToken(address rewardToken_, uint256 periodFinish_) internal view returns (uint256);
```

**Parameters**

| Name            | Type      | Description                                                                                                         |
| --------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_`  | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |
| `periodFinish_` | `uint256` | timestamp end of current rewards period                                                                             |

**Returns**

| Name     | Type      | Description                                          |
| -------- | --------- | ---------------------------------------------------- |
| `<none>` | `uint256` | rewardPerToken rewardToken:stakingToken ratio [PREC] |

### \_earned

gets `backer_` rewards missing to claim

```solidity
function _earned(address rewardToken_, address backer_, uint256 periodFinish_) internal view returns (uint256);
```

**Parameters**

| Name            | Type      | Description                                                                                                         |
| --------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_`  | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |
| `backer_`       | `address` | address who earned the rewards                                                                                      |
| `periodFinish_` | `uint256` | timestamp end of current rewards period                                                                             |

### \_left

gets total amount of rewards to distribute for the current rewards period

```solidity
function _left(address rewardToken_) internal view returns (uint256);
```

**Parameters**

| Name           | Type      | Description                                                                                                         |
| -------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_` | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |

### \_notifyRewardAmount

transfers reward tokens to this contract

```solidity
function _notifyRewardAmount(
    address rewardToken_,
    uint256 builderAmount_,
    uint256 backersAmount_,
    uint256 periodFinish_,
    uint256 timeUntilNextCycle_
)
    internal;
```

**Parameters**

| Name                  | Type      | Description                                                                                                         |
| --------------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_`        | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |
| `builderAmount_`      | `uint256` | amount of rewards for the builder                                                                                   |
| `backersAmount_`      | `uint256` | amount of rewards for the backers                                                                                   |
| `periodFinish_`       | `uint256` | timestamp end of current rewards period                                                                             |
| `timeUntilNextCycle_` | `uint256` | time until next cycle                                                                                               |

### \_updateRewards

update rewards variables when a backer interacts

```solidity
function _updateRewards(address rewardToken_, address backer_, uint256 periodFinish_) internal;
```

**Parameters**

| Name            | Type      | Description                                                                                                         |
| --------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_`  | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |
| `backer_`       | `address` | address of the backers                                                                                              |
| `periodFinish_` | `uint256` | timestamp end of current rewards period                                                                             |

### \_updateRewardMissing

update reward missing variable

```solidity
function _updateRewardMissing(address rewardToken_, uint256 periodFinish_) internal;
```

**Parameters**

| Name            | Type      | Description                                                                                                         |
| --------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_`  | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |
| `periodFinish_` | `uint256` | timestamp end of current rewards period                                                                             |

### \_transferRewardToken

transfers reward token

```solidity
function _transferRewardToken(address rewardToken_, address to_, uint256 amount_) internal nonReentrant;
```

**Parameters**

| Name           | Type      | Description                                                                                                         |
| -------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_` | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |
| `to_`          | `address` | address who receives the tokens                                                                                     |
| `amount_`      | `uint256` | amount of tokens to send                                                                                            |

### \_moveBuilderUnclaimedRewards

moves builder rewards to another address

```solidity
function _moveBuilderUnclaimedRewards(address rewardToken_, address to_) internal;
```

**Parameters**

| Name           | Type      | Description                                                                                                         |
| -------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_` | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |
| `to_`          | `address` | address who receives the rewards                                                                                    |

## Events

### BackerRewardsClaimed

```solidity
event BackerRewardsClaimed(address indexed rewardToken_, address indexed backer_, uint256 amount_);
```

### BuilderRewardsClaimed

```solidity
event BuilderRewardsClaimed(address indexed rewardToken_, address indexed builder_, uint256 amount_);
```

### NewAllocation

```solidity
event NewAllocation(address indexed backer_, uint256 allocation_);
```

### NotifyReward

```solidity
event NotifyReward(address indexed rewardToken_, uint256 builderAmount_, uint256 backersAmount_);
```

## Errors

### NotAuthorized

```solidity
error NotAuthorized();
```

### NotBackersManager

```solidity
error NotBackersManager();
```

### BuilderRewardsLocked

```solidity
error BuilderRewardsLocked();
```

### GaugeHalted

```solidity
error GaugeHalted();
```

### BeforeDistribution

```solidity
error BeforeDistribution();
```

### NotEnoughAmount

```solidity
error NotEnoughAmount();
```

## Structs

### RewardData

```solidity
struct RewardData {
    uint256 rewardRate;
    uint256 rewardPerTokenStored;
    uint256 rewardMissing;
    uint256 lastUpdateTime;
    uint256 builderRewards;
    mapping(address backer => uint256 rewardPerTokenPaid) backerRewardPerTokenPaid;
    mapping(address backer => uint256 rewards) rewards;
}
```
