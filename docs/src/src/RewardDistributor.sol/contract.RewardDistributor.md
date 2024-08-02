# RewardDistributor

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/8d997aa4a4ea93bf6baa71a4d68fb991aefa6dc7/src/RewardDistributor.sol)

Accumulates all the rewards to be distributed for each epoch

## State Variables

### foundationTreasury

foundation treasury address

```solidity
address public immutable foundationTreasury;
```

### rewardToken

address of the token rewarded to builder and sponsors

```solidity
IERC20 public immutable rewardToken;
```

### sponsorsManager

SponsorsManager contract address

```solidity
SponsorsManager public immutable sponsorsManager;
```

### rewardTokenAmountPerEpoch

tracks amount of reward tokens distributed per epoch

```solidity
mapping(uint256 epochTimestampStart => uint256 amount) public rewardTokenAmountPerEpoch;
```

## Functions

### onlyFoundationTreasury

```solidity
modifier onlyFoundationTreasury();
```

### constructor

constructor

```solidity
constructor(address foundationTreasury_, address rewardToken_, address sponsorsManager_);
```

**Parameters**

| Name                  | Type      | Description                                           |
| --------------------- | --------- | ----------------------------------------------------- |
| `foundationTreasury_` | `address` | foundation treasury address                           |
| `rewardToken_`        | `address` | address of the token rewarded to builder and sponsors |
| `sponsorsManager_`    | `address` | SponsorsManager contract address                      |

### sendRewardToken

sends reward tokens to sponsorsManager contract to be distributed to the gauges

_reverts if is not called by foundation treasury address reverts if reward token balance is insufficient_

```solidity
function sendRewardToken(uint256 amount_) external onlyFoundationTreasury;
```

### sendRewardTokenAndStartDistribution

sends reward tokens to sponsorsManager contract and starts the distribution to the gauges

_reverts if is not called by foundation treasury address reverts if reward token balance is insufficient reverts if is
not in the distribution window_

```solidity
function sendRewardTokenAndStartDistribution(uint256 amount_) external onlyFoundationTreasury;
```

### \_sendRewardToken

internal function to send reward tokens to sponsorsManager contract

```solidity
function _sendRewardToken(uint256 amount_) internal;
```

## Errors

### NotFoundationTreasury

```solidity
error NotFoundationTreasury();
```
