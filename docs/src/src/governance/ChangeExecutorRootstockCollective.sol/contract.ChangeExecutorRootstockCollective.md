# ChangeExecutorRootstockCollective

<<<<<<< HEAD <<<<<<< HEAD
[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/93d5161844768d71b8f7420d54b86b3a341b2a7b/src/governance/ChangeExecutorRootstockCollective.sol)
=======
[Git Source](https://github.com/rsksmart/collective-rewards-sc/blob/4458056df04f5875676ab19eeb61c095640acd7a/src/governance/ChangeExecutorRootstockCollective.sol)

> > > > > > > # e514e20 (docs: automated docgen by GitHub Action)
> > > > > > >
> > > > > > > [Git Source](https://github.com/rsksmart/collective-rewards-sc/blob/07de5fea7631b345ab1f8d59e79b48cb3bd6e6d2/src/governance/ChangeExecutorRootstockCollective.sol)
> > > > > > > 4dd012a (docs: automated docgen by GitHub Action)

**Inherits:** ReentrancyGuardUpgradeable, UUPSUpgradeable, [Governed](/src/governance/Governed.sol/abstract.Governed.md)

This contract is used to handle changes on the project when multiple function calls or validation are required. All the
governed protected function can be executed when are called through this contract but only can be performed by the
Governor.

## State Variables

### \_governor

governor address

```solidity
address internal _governor;
```

### \_currentChangeContract

changer contract address to be executed

```solidity
address private _currentChangeContract;
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
function initialize(address governor_) external initializer;
```

**Parameters**

| Name        | Type      | Description               |
| ----------- | --------- | ------------------------- |
| `governor_` | `address` | governor contract address |

### governor

maintains Governed interface. Returns governed address

```solidity
function governor() public view override returns (address);
```

### executeChange

Function to be called to make the changes in changeContract

_reverts if is not called by the Governor_

```solidity
function executeChange(IChangeContractRootstockCollective changeContract_) external;
```

**Parameters**

| Name              | Type                                 | Description                                           |
| ----------------- | ------------------------------------ | ----------------------------------------------------- |
| `changeContract_` | `IChangeContractRootstockCollective` | Address of the contract that will execute the changes |

### isAuthorizedChanger

Returns true if the changer\_ address is currently authorized to make changes within the system

```solidity
function isAuthorizedChanger(address changer_) external view virtual returns (bool);
```

**Parameters**

| Name       | Type      | Description                                 |
| ---------- | --------- | ------------------------------------------- |
| `changer_` | `address` | Address of the contract that will be tested |

### \_executeChange

Function to be called to make the changes in changeContract

_reverts if is not called by the Governor_

```solidity
function _executeChange(IChangeContractRootstockCollective changeContract_) internal nonReentrant onlyGovernor;
```

**Parameters**

| Name              | Type                                 | Description                                           |
| ----------------- | ------------------------------------ | ----------------------------------------------------- |
| `changeContract_` | `IChangeContractRootstockCollective` | Address of the contract that will execute the changes |

### \_isAuthorizedChanger

Returns true if the changer\_ address is currently authorized to make changes within the system

```solidity
function _isAuthorizedChanger(address changer_) internal view returns (bool);
```

**Parameters**

| Name       | Type      | Description                                 |
| ---------- | --------- | ------------------------------------------- |
| `changer_` | `address` | Address of the contract that will be tested |

### \_enableChangeContract

Authorize the changeContract address to make changes

```solidity
function _enableChangeContract(IChangeContractRootstockCollective changeContract_) internal;
```

**Parameters**

| Name              | Type                                 | Description                                     |
| ----------------- | ------------------------------------ | ----------------------------------------------- |
| `changeContract_` | `IChangeContractRootstockCollective` | Address of the contract that will be authorized |

### \_disableChangeContract

UNAuthorize the currentChangeContract address to make changes

```solidity
function _disableChangeContract() internal;
```

### \_authorizeUpgrade

_checks that the upgrade is currently authorized by governance_

```solidity
function _authorizeUpgrade(address newImplementation_) internal override onlyGovernor;
```

**Parameters**

| Name                 | Type      | Description                         |
| -------------------- | --------- | ----------------------------------- |
| `newImplementation_` | `address` | new implementation contract address |
