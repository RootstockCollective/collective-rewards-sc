# Gauge

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/8ec40d87be9e0ccefea4a86603917ab71f394728/src/gauge/Gauge.sol)

**Inherits:** ReentrancyGuardUpgradeable

For each project proposal a Gauge contract will be deployed. It receives all the rewards obtained for that project and
allows the builder and voters to claim them.

## State Variables

### rewardToken

address of the token rewarded to builder and voters

```solidity
address public rewardToken;
```

### sponsorsManager

SponsorsManager contract address

```solidity
ISponsorsManager public sponsorsManager;
```

### totalAllocation

total amount of stakingToken allocated for rewards

```solidity
uint256 public totalAllocation;
```

### rewardShares

epoch rewards shares, optimistically tracking the time weighted votes allocations for this gauge

```solidity
uint256 public rewardShares;
```

### allocationOf

amount of stakingToken allocated by a sponsor

```solidity
mapping(address sponsor => uint256 allocation) public allocationOf;
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

### onlySponsorsManager

```solidity
modifier onlySponsorsManager();
```

### constructor

```solidity
constructor();
```

### initialize

contract initializer

```solidity
function initialize(address rewardToken_, address sponsorsManager_) external initializer;
```

**Parameters**

| Name               | Type      | Description                                         |
| ------------------ | --------- | --------------------------------------------------- |
| `rewardToken_`     | `address` | address of the token rewarded to builder and voters |
| `sponsorsManager_` | `address` | address of the SponsorsManager contract             |

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

### sponsorRewardPerTokenPaid

gets sponsor reward per token paid

```solidity
function sponsorRewardPerTokenPaid(address rewardToken_, address sponsor_) public view returns (uint256);
```

**Parameters**

| Name           | Type      | Description                                                                                                         |
| -------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_` | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |
| `sponsor_`     | `address` |                                                                                                                     |

### rewards

gets amount of rewardToken earned for a sponsor

```solidity
function rewards(address rewardToken_, address sponsor_) public view returns (uint256);
```

**Parameters**

| Name           | Type      | Description                                                                                                         |
| -------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_` | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |
| `sponsor_`     | `address` | address of the sponsor                                                                                              |

### lastTimeRewardApplicable

gets the last time the reward is applicable, now or when the epoch finished

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

gets `sponsor_` rewards missing to claim

```solidity
function earned(address rewardToken_, address sponsor_) public view returns (uint256);
```

**Parameters**

| Name           | Type      | Description                                                                                                         |
| -------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_` | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |
| `sponsor_`     | `address` | address who earned the rewards                                                                                      |

### claimSponsorReward

claim rewards for a `sponsor_` address

_reverts if is not called by the `sponsor_` or the sponsorsManager\_

```solidity
function claimSponsorReward(address sponsor_) public;
```

**Parameters**

| Name       | Type      | Description                      |
| ---------- | --------- | -------------------------------- |
| `sponsor_` | `address` | address who receives the rewards |

### claimSponsorReward

claim rewards for a `sponsor_` address

_reverts if is not called by the `sponsor_` or the sponsorsManager\_

```solidity
function claimSponsorReward(address rewardToken_, address sponsor_) public;
```

**Parameters**

| Name           | Type      | Description                                                                                                         |
| -------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_` | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |
| `sponsor_`     | `address` | address who receives the rewards                                                                                    |

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

### allocate

allocates stakingTokens

_reverts if caller is not the sponsorsManager contract_

```solidity
function allocate(
    address sponsor_,
    uint256 allocation_
)
    external
    onlySponsorsManager
    returns (uint256 allocationDeviation_, bool isNegative_);
```

**Parameters**

| Name          | Type      | Description                          |
| ------------- | --------- | ------------------------------------ |
| `sponsor_`    | `address` | address of user who allocates tokens |
| `allocation_` | `uint256` | amount of tokens to allocate         |

**Returns**

| Name                   | Type      | Description                                           |
| ---------------------- | --------- | ----------------------------------------------------- |
| `allocationDeviation_` | `uint256` | deviation between current allocation and the new one  |
| `isNegative_`          | `bool`    | true if new allocation is lesser than the current one |

### notifyRewardAmount

transfers reward tokens to this contract

```solidity
function notifyRewardAmount(address rewardToken_, uint256 builderAmount_, uint256 sponsorsAmount_) external payable;
```

**Parameters**

| Name              | Type      | Description                                                                                                         |
| ----------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_`    | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |
| `builderAmount_`  | `uint256` | amount of rewards for the builder                                                                                   |
| `sponsorsAmount_` | `uint256` | amount of rewards for the sponsors                                                                                  |

### notifyRewardAmountAndUpdateShares

called on the reward distribution. Transfers reward tokens from sponsorManger to this contract

_reverts if caller is not the sponsorsManager contract_

```solidity
function notifyRewardAmountAndUpdateShares(
    uint256 amountERC20_,
    uint256 builderKickback_
)
    external
    payable
    onlySponsorsManager
    returns (uint256 newGaugeRewardShares_);
```

**Parameters**

| Name               | Type      | Description                 |
| ------------------ | --------- | --------------------------- |
| `amountERC20_`     | `uint256` | amount of ERC20 rewards     |
| `builderKickback_` | `uint256` | builder kickback percetange |

**Returns**

| Name                    | Type      | Description                                            |
| ----------------------- | --------- | ------------------------------------------------------ |
| `newGaugeRewardShares_` | `uint256` | new gauge rewardShares, updated after the distribution |

### \_notifyRewardAmount

transfers reward tokens to this contract

```solidity
function _notifyRewardAmount(address rewardToken_, uint256 builderAmount_, uint256 sponsorsAmount_) internal;
```

**Parameters**

| Name              | Type      | Description                                                                                                         |
| ----------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_`    | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |
| `builderAmount_`  | `uint256` | amount of rewards for the builder                                                                                   |
| `sponsorsAmount_` | `uint256` | amount of rewards for the sponsors                                                                                  |

### \_updateRewards

update rewards variables when a sponsor interacts

```solidity
function _updateRewards(address rewardToken_, address sponsor_) internal;
```

**Parameters**

| Name           | Type      | Description                                                                                                         |
| -------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_` | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |
| `sponsor_`     | `address` | address of the sponsors                                                                                             |

### \_updateRewardMissing

update reward missing variable

```solidity
function _updateRewardMissing(address rewardToken_) internal;
```

**Parameters**

| Name           | Type      | Description                                                                                                         |
| -------------- | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_` | `address` | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |

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

## Events

### SponsorRewardsClaimed

```solidity
event SponsorRewardsClaimed(address indexed rewardToken_, address indexed sponsor_, uint256 amount_);
```

### BuilderRewardsClaimed

```solidity
event BuilderRewardsClaimed(address indexed rewardToken_, address indexed builder_, uint256 amount_);
```

### NewAllocation

```solidity
event NewAllocation(address indexed sponsor_, uint256 allocation_);
```

### NotifyReward

```solidity
event NotifyReward(address indexed rewardToken_, uint256 builderAmount_, uint256 sponsorsAmount_);
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

### InvalidRewardAmount

```solidity
error InvalidRewardAmount();
```

### BuilderRewardsLocked

```solidity
error BuilderRewardsLocked();
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
    mapping(address sponsor => uint256 rewardPerTokenPaid) sponsorRewardPerTokenPaid;
    mapping(address sponsor => uint256 rewards) rewards;
}
```
