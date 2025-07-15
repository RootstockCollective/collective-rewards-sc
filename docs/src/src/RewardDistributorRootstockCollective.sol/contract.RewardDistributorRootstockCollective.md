# RewardDistributorRootstockCollective
[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/d3eba7c5de1f4bd94fc8d9063bc035b452fb6c5d/src/RewardDistributorRootstockCollective.sol)

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


### defaultRewardnativeTokensAmount
default reward native tokens amount


```solidity
uint256 public defaultRewardnativeTokensAmount;
```


### __gap
*This empty reserved space is put in place to allow future versions to add new
variables without shifting down storage in the inheritance chain.
See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps*


```solidity
uint256[50] private __gap;
```


## Functions
### onlyFoundationTreasury


```solidity
modifier onlyFoundationTreasury();
```

### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor();
```

### initialize

contract initializer

*initializeCollectiveRewardsAddresses() must be called ASAP after this initialization*


```solidity
function initialize(IGovernanceManagerRootstockCollective governanceManager_) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`governanceManager_`|`IGovernanceManagerRootstockCollective`|contract with permissioned roles|


### initializeCollectiveRewardsAddresses

CollectiveRewards addresses initializer

*used to solve circular dependency, backersManager is initialized with this contract address
it must be called ASAP after the initialize.*


```solidity
function initializeCollectiveRewardsAddresses(address backersManager_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`backersManager_`|`address`|BackersManagerRootstockCollective contract address|


### sendRewards

sends rewards to backersManager contract to be distributed to the gauges

*reverts if is not called by foundation treasury address
reverts if rewards balance is insufficient*


```solidity
function sendRewards(uint256 amountRif_, uint256 amountNative_) external payable onlyFoundationTreasury;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amountRif_`|`uint256`|amount of ERC20 reward token to send|
|`amountNative_`|`uint256`|amount of native tokens reward token to send|


### sendRewardsAndStartDistribution

sends rewards to backersManager contract and starts the distribution to the gauges

*reverts if is not called by foundation treasury address
reverts if rewards balance is insufficient
reverts if is not in the distribution window*


```solidity
function sendRewardsAndStartDistribution(
    uint256 amountRif_,
    uint256 amountNative_
)
    external
    payable
    onlyFoundationTreasury;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amountRif_`|`uint256`|amount of ERC20 reward token to send|
|`amountNative_`|`uint256`|amount of native tokens reward token to send|


### setDefaultRewardAmount

sets the default reward amounts

*reverts if is not called by foundation treasury address*


```solidity
function setDefaultRewardAmount(
    uint256 tokenAmount_,
    uint256 nativeTokensAmount_
)
    external
    payable
    onlyFoundationTreasury;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenAmount_`|`uint256`|default amount of ERC20 reward token to send|
|`nativeTokensAmount_`|`uint256`|default amount of native tokens reward token to send|


### sendRewardsWithDefaultAmount

sends rewards to backersManager contract with default amounts

*reverts if is not called by foundation treasury address*


```solidity
function sendRewardsWithDefaultAmount() external payable onlyFoundationTreasury;
```

### sendRewardsAndStartDistributionWithDefaultAmount

sends rewards to backersManager contract with default amounts and starts the distribution

*reverts if is not called by foundation treasury address*


```solidity
function sendRewardsAndStartDistributionWithDefaultAmount() external payable onlyFoundationTreasury;
```

### _sendRewards

internal function to send rewards to backersManager contract


```solidity
function _sendRewards(uint256 amountRif_, uint256 amountNative_) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amountRif_`|`uint256`|amount of ERC20 reward token to send|
|`amountNative_`|`uint256`|amount of native tokens reward token to send|


### receive

receives native tokens to distribute for rewards


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

