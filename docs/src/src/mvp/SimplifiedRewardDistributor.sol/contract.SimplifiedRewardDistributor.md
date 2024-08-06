# SimplifiedRewardDistributor

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/38b1618c77e8418aee572d46a56dd13f602978fe/src/mvp/SimplifiedRewardDistributor.sol)

**Inherits:** [SimplifiedBuilderRegistry](/src/mvp/SimplifiedBuilderRegistry.sol/abstract.SimplifiedBuilderRegistry.md),
ReentrancyGuardUpgradeable

Simplified version for the MVP. Accumulates all the rewards and distribute them equally to all the builders for each
epoch

## State Variables

### rewardToken

address of the token rewarded to builders

```solidity
IERC20 public rewardToken;
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

### initialize

contract initializer

```solidity
function initialize(address changeExecutor_, address rewardToken_, address kycApprover_) external initializer;
```

**Parameters**

| Name              | Type      | Description                                                                                  |
| ----------------- | --------- | -------------------------------------------------------------------------------------------- |
| `changeExecutor_` | `address` | See Governed doc                                                                             |
| `rewardToken_`    | `address` | address of the token rewarded to builders                                                    |
| `kycApprover_`    | `address` | account responsible of approving Builder's Know you Costumer policies and Legal requirements |

### distribute

distributes all the reward tokens and coinbase equally to all the whitelisted builders

```solidity
function distribute() external payable;
```

### distributeRewardToken

distributes all the reward tokens equally to all the whitelisted builders

```solidity
function distributeRewardToken() external;
```

### distributeCoinbase

distributes all the coinbase rewards equally to all the whitelisted builders

```solidity
function distributeCoinbase() external payable;
```

### \_distribute

distributes reward tokens and coinbase equally to all the whitelisted builders

_reverts if there is not enough reward token or coinbase balance_

```solidity
function _distribute(uint256 rewardTokenAmount_, uint256 coinbaseAmount_) internal nonReentrant;
```

**Parameters**

| Name                 | Type      | Description                                                |
| -------------------- | --------- | ---------------------------------------------------------- |
| `rewardTokenAmount_` | `uint256` | amount of reward token to distribute                       |
| `coinbaseAmount_`    | `uint256` | total amount of coinbase to be distribute between builders |

### receive

receives coinbase to distribute for rewards

```solidity
receive() external payable;
```
