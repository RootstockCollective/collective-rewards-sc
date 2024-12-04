# RewardDistributorRootstockCollective

[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/6d0eca4e2c61e833bcb70c54d8668e5644ba180e/src/RewardDistributorRootstockCollective.sol)

**Inherits:**
[UpgradeableRootstockCollective](/src/governance/UpgradeableRootstockCollective.sol/abstract.UpgradeableRootstockCollective.md)

Accumulates all the rewards to be distributed for each cycle

## State Variables

### rewardToken

address of the token rewarded to builder and backers

```solidity
IERC20 public rewardToken;
```

### backersManager

BackersManagerRootstockCollective contract address

```solidity
BackersManagerRootstockCollective public backersManager;
```

### defaultRewardTokenAmount

default reward token amount

```solidity
uint256 public defaultRewardTokenAmount;
```

### defaultRewardCoinbaseAmount

default reward coinbase amount

```solidity
uint256 public defaultRewardCoinbaseAmount;
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

_initializeCollectiveRewardsAddresses() must be called ASAP after this initialization_

```solidity
function initialize(IGovernanceManagerRootstockCollective governanceManager_) external initializer;
```

**Parameters**

| Name                 | Type                                    | Description                      |
| -------------------- | --------------------------------------- | -------------------------------- |
| `governanceManager_` | `IGovernanceManagerRootstockCollective` | contract with permissioned roles |

### initializeCollectiveRewardsAddresses

CollectiveRewards addresses initializer

_used to solve circular dependency, backersManager is initialized with this contract address it must be called ASAP
after the initialize._

```solidity
function initializeCollectiveRewardsAddresses(address backersManager_) external;
```

**Parameters**

| Name              | Type      | Description                                        |
| ----------------- | --------- | -------------------------------------------------- |
| `backersManager_` | `address` | BackersManagerRootstockCollective contract address |

### sendRewards

sends rewards to backersManager contract to be distributed to the gauges

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

sends rewards to backersManager contract and starts the distribution to the gauges

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

### setDefaultRewardAmount

sets the default reward amounts

_reverts if is not called by foundation treasury address_

```solidity
function setDefaultRewardAmount(
    uint256 tokenAmount_,
    uint256 coinbaseAmount_
)
    external
    payable
    onlyFoundationTreasury;
```

**Parameters**

| Name              | Type      | Description                                     |
| ----------------- | --------- | ----------------------------------------------- |
| `tokenAmount_`    | `uint256` | default amount of ERC20 reward token to send    |
| `coinbaseAmount_` | `uint256` | default amount of Coinbase reward token to send |

### sendRewardsWithDefaultAmount

sends rewards to backersManager contract with default amounts

_reverts if is not called by foundation treasury address_

```solidity
function sendRewardsWithDefaultAmount() external payable onlyFoundationTreasury;
```

### sendRewardsAndStartDistributionWithDefaultAmount

sends rewards to backersManager contract with default amounts and starts the distribution

_reverts if is not called by foundation treasury address_

```solidity
function sendRewardsAndStartDistributionWithDefaultAmount() external payable onlyFoundationTreasury;
```

### \_sendRewards

internal function to send rewards to backersManager contract

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

### CollectiveRewardsAddressesAlreadyInitialized

```solidity
error CollectiveRewardsAddressesAlreadyInitialized();
```
