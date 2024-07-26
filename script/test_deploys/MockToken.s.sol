// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { ERC20Mock } from "test/mock/ERC20Mock.sol";

contract Deploy is Broadcaster {
    function run() public returns (ERC20Mock mockToken) {
        mockToken = run(vm.envOr("MOCK_TOKEN_COUNTER", uint256(0)));
    }

    function run(uint256 mockTokenCounter) public broadcast returns (ERC20Mock mockToken) {
        mockToken = new ERC20Mock(mockTokenCounter);
    }
}
