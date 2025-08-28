# RewardDistributorRootstockCollective
[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/dddd380a18864fe36c9ec409abd3170e82ca6a46/src/RewardDistributorRootstockCollective.sol)

**Inherits:**
[UpgradeableRootstockCollective](/src/governance/UpgradeableRootstockCollective.sol/abstract.UpgradeableRootstockCollective.md)

Accumulates all the rewards to be distributed for each cycle


## State Variables
### rifToken
address of rif token rewarded to builder and backers


```solidity
IERC20 public rifToken;
```


### backersManager
BackersManagerRootstockCollective contract address


```solidity
BackersManagerRootstockCollective public backersManager;
```


### defaultRifAmount
default RIF amount to be distributed per cycle


```solidity
uint256 public defaultRifAmount;
```


### defaultNativeAmount
default native amount to be distributed per cycle


```solidity
uint256 public defaultNativeAmount;
```


### lastFundedCycleStart

```solidity
uint256 public lastFundedCycleStart;
```


### usdrifToken
address of the usdrif token rewarded to builder and backers


```solidity
IERC20 public usdrifToken;
```


### defaultUsdrifAmount
default USDRIF amount to be distributed per cycle


```solidity
uint256 public defaultUsdrifAmount;
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

### onlyOncePerCycle


```solidity
modifier onlyOncePerCycle();
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

*reverts if is not called by foundation treasury address*


```solidity
function sendRewards(
    uint256 amountRif_,
    uint256 amountUsdrif_,
    uint256 amountNative_
)
    external
    payable
    onlyFoundationTreasury;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amountRif_`|`uint256`|amount of ERC20 rif token to send|
|`amountUsdrif_`|`uint256`|amount of ERC20 usdrif token to send|
|`amountNative_`|`uint256`|amount of Native token to send|


### sendRewardsAndStartDistribution

sends rewards to backersManager contract and starts the distribution to the gauges

*reverts if is not called by foundation treasury address
reverts if is not in the distribution window*


```solidity
function sendRewardsAndStartDistribution(
    uint256 amountRif_,
    uint256 amountUsdrif_,
    uint256 amountNative_
)
    external
    payable
    onlyFoundationTreasury;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amountRif_`|`uint256`|amount of ERC20 rif token to send|
|`amountUsdrif_`|`uint256`|amount of ERC20 usdrif token to send|
|`amountNative_`|`uint256`|amount of Native token to send|


### setDefaultRewardAmount

sets the default reward amounts

*reverts if is not called by foundation treasury address*


```solidity
function setDefaultRewardAmount(
    uint256 rifTokenAmount_,
    uint256 usdrifTokenAmount_,
    uint256 nativeAmount_
)
    external
    payable
    onlyFoundationTreasury;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rifTokenAmount_`|`uint256`|default amount of ERC20 rif token to send|
|`usdrifTokenAmount_`|`uint256`|default amount of ERC20 usdrif token to send|
|`nativeAmount_`|`uint256`|default amount of Native token to send|


### sendRewardsWithDefaultAmount

sends rewards to backersManager contract with default amounts

*reverts if is called more than once per cycle*


```solidity
function sendRewardsWithDefaultAmount() external payable onlyOncePerCycle;
```

### sendRewardsAndStartDistributionWithDefaultAmount

sends rewards to backersManager contract with default amounts and starts the distribution

*reverts if is called more than once per cycle*


```solidity
function sendRewardsAndStartDistributionWithDefaultAmount() external payable onlyOncePerCycle;
```

### _sendRewards

internal function to send rewards to backersManager contract


```solidity
function _sendRewards(uint256 amountRif_, uint256 amountUsdrif_, uint256 amountNative_) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amountRif_`|`uint256`|amount of ERC20 rif token to send|
|`amountUsdrif_`|`uint256`|amount of ERC20 usdrif token to send|
|`amountNative_`|`uint256`|amount of Native token to send|


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

### CycleAlreadyFunded

```solidity
error CycleAlreadyFunded();
```

