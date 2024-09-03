# SimplifiedRewardDistributor

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/b66d083f8b28b436755b9a1020cbe3fd028cd794/src/mvp/SimplifiedRewardDistributor.sol)

**Inherits:** [Governed](/src/governance/Governed.sol/abstract.Governed.md), ReentrancyGuardUpgradeable

Simplified version for the MVP. Accumulates all the rewards and distribute them equally to all the builders for each
epoch

## State Variables

### rewardToken

address of the token rewarded to builders

```solidity
IERC20 public rewardToken;
```

### builderRewardReceiver

map of builders reward receiver

```solidity
mapping(address builder => address payable rewardReceiver) public builderRewardReceiver;
```

### \_whitelistedBuilders

```solidity
EnumerableSet.AddressSet internal _whitelistedBuilders;
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
function initialize(address changeExecutor_, address rewardToken_) external initializer;
```

**Parameters**

| Name              | Type      | Description                               |
| ----------------- | --------- | ----------------------------------------- |
| `changeExecutor_` | `address` | See Governed doc                          |
| `rewardToken_`    | `address` | address of the token rewarded to builders |

### whitelistBuilder

whitelist builder

_reverts if is builder is already whitelisted_

```solidity
function whitelistBuilder(address builder_, address payable rewardReceiver_) external onlyGovernorOrAuthorizedChanger;
```

**Parameters**

| Name              | Type              | Description                            |
| ----------------- | ----------------- | -------------------------------------- |
| `builder_`        | `address`         | address of the builder                 |
| `rewardReceiver_` | `address payable` | address of the builder reward receiver |

### removeWhitelistedBuilder

remove builder from whitelist

_reverts if is builder is not whitelisted_

```solidity
function removeWhitelistedBuilder(address builder_) external onlyGovernorOrAuthorizedChanger;
```

**Parameters**

| Name       | Type      | Description            |
| ---------- | --------- | ---------------------- |
| `builder_` | `address` | address of the builder |

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

### getWhitelistedBuildersLength

get length of whitelisted builders array

```solidity
function getWhitelistedBuildersLength() external view returns (uint256);
```

### getWhitelistedBuilder

get whitelisted builder from array

```solidity
function getWhitelistedBuilder(uint256 index_) external view returns (address);
```

### isWhitelisted

return true is builder is whitelisted

```solidity
function isWhitelisted(address builder_) external view returns (bool);
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