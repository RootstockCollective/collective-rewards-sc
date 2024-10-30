# IChangeExecutorRootstockCollective

[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/eae48ddb77cb2599eb8b47e67086c59f8ff057a6/src/mvp/IChangeExecutorRootstockCollective.sol)

This interface is check if a changer is authotized by the governance system

## Functions

### governor

returns governor address

```solidity
function governor() external view returns (address);
```

### isAuthorizedChanger

Returns true if the changer\_ address is currently authorized to make changes within the system

```solidity
function isAuthorizedChanger(address changer_) external view returns (bool);
```

**Parameters**

| Name       | Type      | Description                                 |
| ---------- | --------- | ------------------------------------------- |
| `changer_` | `address` | Address of the contract that will be tested |
