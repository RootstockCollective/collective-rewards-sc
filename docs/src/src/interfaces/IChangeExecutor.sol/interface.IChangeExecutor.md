# IChangeExecutor

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/336f2f19e2ee0dc1ad64351e346590307b83d362/src/interfaces/IChangeExecutor.sol)

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
