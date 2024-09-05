# IChangeContract

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/3e514139c84a54a595e7a364c0a91d5be2874fd7/src/interfaces/IChangeContract.sol)

This interface is the one used by the governance system.

_If you plan to do some changes to a system governed by this project you should write a contract that does those
changes, like a recipe. This contract MUST not have ANY kind of public or external function that modifies the state of
this ChangeContract, otherwise you could run into front-running issues when the governance system is fully in place._

## Functions

### execute

Override this function with a recipe of the changes to be done when this ChangeContract is executed

```solidity
function execute() external;
```
