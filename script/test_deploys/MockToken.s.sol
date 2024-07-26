// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { ERC20Mock, DEFAULT_NAME, DEFAULT_SYMBOL } from "test/mock/ERC20Mock.sol";

contract Deploy is Broadcaster {
    function run() public returns (ERC20Mock mockToken) {
        mockToken = run(vm.envOr("MOCK_TOKEN_COUNTER", uint256(0)));
    }

    function run(uint256 mockTokenCounter) public broadcast returns (ERC20Mock mockToken) {
        string memory name = DEFAULT_NAME;
        string memory symbol = DEFAULT_SYMBOL;

        if (mockTokenCounter > 0) {
            string memory counterString = Strings.toString(mockTokenCounter);
            name = string.concat(name, "_", counterString);
            symbol = string.concat(symbol, "_", counterString);
        }

        mockToken = new ERC20Mock(name, symbol);
    }
}
