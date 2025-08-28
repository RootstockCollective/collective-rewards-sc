# IChangeContractRootstockCollective
[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/dddd380a18864fe36c9ec409abd3170e82ca6a46/src/interfaces/IChangeContractRootstockCollective.sol)

This interface is the one used by the governance system.

*If you plan to do some changes to a system governed by this project you should write a contract
that does those changes, like a recipe. This contract MUST not have ANY kind of public or external function
that modifies the state of this ChangeContract, otherwise you could run into front-running issues when the
governance
system is fully in place.*


## Functions
### execute

Override this function with a recipe of the changes to be done when this ChangeContract
is executed


```solidity
function execute() external;
```

