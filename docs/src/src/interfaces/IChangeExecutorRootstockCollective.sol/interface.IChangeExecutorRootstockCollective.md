# IChangeExecutorRootstockCollective

[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/8bd29e5db4bf3fe742eaa77d7d0078590ca8f07f/src/interfaces/IChangeExecutorRootstockCollective.sol)

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
