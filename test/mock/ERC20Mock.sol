// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { MockERC20 } from "forge-std/src/mocks/MockERC20.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract ERC20Mock is MockERC20 {
    constructor(uint256 mockTokenCounter) MockERC20() {
        string memory name = "ERC20Mock";
        string memory symbol = "E20M";

        if (mockTokenCounter > 0) {
            string memory counterString = Strings.toString(mockTokenCounter);
            name = string.concat(name, "_", counterString);
            symbol = string.concat(symbol, "_", counterString);
        }
        initialize("ERC20Mock", "E20M", 18);
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}
