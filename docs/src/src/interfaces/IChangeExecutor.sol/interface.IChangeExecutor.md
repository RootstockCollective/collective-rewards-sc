# IChangeExecutor

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/65787984373194e94a67c67ddefd555e11be2eaa/src/interfaces/IChangeExecutor.sol)

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
