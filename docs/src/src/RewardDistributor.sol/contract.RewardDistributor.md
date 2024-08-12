# RewardDistributor

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/fe856b39980e775913dd2a8ffaa77a3ad156e2b5/src/RewardDistributor.sol)

**Inherits:** [Governed](/src/governance/Governed.sol/abstract.Governed.md)

Accumulates all the rewards to be distributed for each epoch

## State Variables

### foundationTreasury

foundation treasury address

```solidity
address public foundationTreasury;
```

### rewardToken

address of the token rewarded to builder and supporters

```solidity
IERC20 public rewardToken;
```

### supportHub

SupportHub contract address

```solidity
SupportHub public supportHub;
```

### rewardTokenAmountPerEpoch

tracks amount of reward tokens distributed per epoch

```solidity
mapping(uint256 epochTimestampStart => uint256 amount) public rewardTokenAmountPerEpoch;
```

### \_\_gap

_This empty reserved space is put in place to allow future versions to add new variables without shifting down storage
in the inheritance chain. See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps_

```solidity
uint256[50] private __gap;
```

## Functions

### onlyFoundationTreasury

```solidity
modifier onlyFoundationTreasury();
```

### constructor

```solidity
constructor();
```

### initialize

contract initializer

```solidity
function initialize(address changeExecutor_, address foundationTreasury_, address supportHub_) external initializer;
```

**Parameters**

| Name                  | Type      | Description                 |
| --------------------- | --------- | --------------------------- |
| `changeExecutor_`     | `address` | See Governed doc            |
| `foundationTreasury_` | `address` | foundation treasury address |
| `supportHub_`         | `address` | SupportHub contract address |

### sendRewardToken

sends reward tokens to supportHub contract to be distributed to the builder gauges

_reverts if is not called by foundation treasury address reverts if reward token balance is insufficient_

```solidity
function sendRewardToken(uint256 amount_) external onlyFoundationTreasury;
```

### sendRewardTokenAndStartDistribution

sends reward tokens to supportHub contract and starts the distribution to the builder gauges

_reverts if is not called by foundation treasury address reverts if reward token balance is insufficient reverts if is
not in the distribution window_

```solidity
function sendRewardTokenAndStartDistribution(uint256 amount_) external onlyFoundationTreasury;
```

### \_sendRewardToken

internal function to send reward tokens to supportHub contract

```solidity
function _sendRewardToken(uint256 amount_) internal;
```

## Errors

### NotFoundationTreasury

```solidity
error NotFoundationTreasury();
```
