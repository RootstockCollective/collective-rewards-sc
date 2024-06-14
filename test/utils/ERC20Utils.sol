// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Test } from "forge-std/src/Test.sol";

contract ERC20Utils is Test {
    function mintToken(address _token, address _account, uint256 _amount) public {
        deal(address(_token), _account, _amount, true);
    }

    function mintTokens(address _token, address[] memory _accounts, uint256[] memory _amounts) public {
        for (uint256 i = 0; i < _amounts.length; i++) {
            deal(address(_token), _accounts[i], _amounts[i], true);
        }
    }
}
