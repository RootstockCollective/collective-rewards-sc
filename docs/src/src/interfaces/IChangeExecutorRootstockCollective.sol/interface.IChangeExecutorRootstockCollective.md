# IChangeExecutorRootstockCollective

<<<<<<< HEAD
[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/93d5161844768d71b8f7420d54b86b3a341b2a7b/src/interfaces/IChangeExecutorRootstockCollective.sol)
=======
[Git Source](https://github.com/rsksmart/collective-rewards-sc/blob/4458056df04f5875676ab19eeb61c095640acd7a/src/interfaces/IChangeExecutorRootstockCollective.sol)

> > > > > > > e514e20 (docs: automated docgen by GitHub Action)

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
