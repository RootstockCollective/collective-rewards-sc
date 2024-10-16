# RewardDistributor

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/e0365450ae51e86dafe26a54f2dc19dfc48e2141/src/RewardDistributor.sol)

**Inherits:** [Upgradeable](/src/governance/Upgradeable.sol/abstract.Upgradeable.md)

Accumulates all the rewards to be distributed for each epoch

## State Variables

### foundationTreasury

foundation treasury address

```solidity
address public foundationTreasury;
```

### rewardToken

address of the token rewarded to builder and sponsors

```solidity
IERC20 public rewardToken;
```

### sponsorsManager

SponsorsManager contract address

```solidity
SponsorsManager public sponsorsManager;
```

### rewardTokenAmountPerEpoch

tracks amount of reward tokens distributed per epoch

```solidity
mapping(uint256 epochTimestampStart => uint256 amount) public rewardTokenAmountPerEpoch;
```

### rewardCoinbaseAmountPerEpoch

tracks amount of coinbase distributed per epoch

```solidity
mapping(uint256 epochTimestampStart => uint256 amount) public rewardCoinbaseAmountPerEpoch;
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

_initializeBIMAddresses() must be called ASAP after this initialization_

```solidity
function initialize(address changeExecutor_, address foundationTreasury_) external initializer;
```

**Parameters**

| Name                  | Type      | Description                 |
| --------------------- | --------- | --------------------------- |
| `changeExecutor_`     | `address` | See Governed doc            |
| `foundationTreasury_` | `address` | foundation treasury address |

### initializeBIMAddresses

BIM addresses initializer

_used to solve circular dependency, sponsorsManager is initialized with this contract address it must be called ASAP
after the initialize._

```solidity
function initializeBIMAddresses(address sponsorsManager_) external;
```

**Parameters**

| Name               | Type      | Description                      |
| ------------------ | --------- | -------------------------------- |
| `sponsorsManager_` | `address` | SponsorsManager contract address |

### sendRewards

sends rewards to sponsorsManager contract to be distributed to the gauges

_reverts if is not called by foundation treasury address reverts if rewards balance is insufficient_

```solidity
function sendRewards(uint256 amountERC20_, uint256 amountCoinbase_) external payable onlyFoundationTreasury;
```

**Parameters**

| Name              | Type      | Description                             |
| ----------------- | --------- | --------------------------------------- |
| `amountERC20_`    | `uint256` | amount of ERC20 reward token to send    |
| `amountCoinbase_` | `uint256` | amount of Coinbase reward token to send |

### sendRewardsAndStartDistribution

sends rewards to sponsorsManager contract and starts the distribution to the gauges

_reverts if is not called by foundation treasury address reverts if rewards balance is insufficient reverts if is not in
the distribution window_

```solidity
function sendRewardsAndStartDistribution(
    uint256 amountERC20_,
    uint256 amountCoinbase_
)
    external
    payable
    onlyFoundationTreasury;
```

**Parameters**

| Name              | Type      | Description                             |
| ----------------- | --------- | --------------------------------------- |
| `amountERC20_`    | `uint256` | amount of ERC20 reward token to send    |
| `amountCoinbase_` | `uint256` | amount of Coinbase reward token to send |

### \_sendRewards

internal function to send rewards to sponsorsManager contract

```solidity
function _sendRewards(uint256 amountERC20_, uint256 amountCoinbase_) internal;
```

**Parameters**

| Name              | Type      | Description                             |
| ----------------- | --------- | --------------------------------------- |
| `amountERC20_`    | `uint256` | amount of ERC20 reward token to send    |
| `amountCoinbase_` | `uint256` | amount of Coinbase reward token to send |

### receive

receives coinbase to distribute for rewards

```solidity
receive() external payable;
```

## Errors

### NotFoundationTreasury

```solidity
error NotFoundationTreasury();
```

### BIMAddressesAlreadyInitialized

```solidity
error BIMAddressesAlreadyInitialized();
```
