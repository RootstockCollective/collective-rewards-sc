// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { ERC20Mock, DEFAULT_NAME, DEFAULT_SYMBOL } from "test/mock/ERC20Mock.sol";

contract Deploy is Broadcaster {
    function run() public returns (ERC20Mock) {
        return run(vm.envOr("MOCK_TOKEN_COUNTER", uint256(0)));
    }

    function run(uint256 mockTokenCounter_) public broadcast returns (ERC20Mock) {
        string memory _name = DEFAULT_NAME;
        string memory _symbol = DEFAULT_SYMBOL;

        if (mockTokenCounter_ > 0) {
            string memory _counterString = Strings.toString(mockTokenCounter_);
            _name = string.concat(_name, "_", _counterString);
            _symbol = string.concat(_symbol, "_", _counterString);
        }

        if (vm.envOr("NO_DD", false)) {
            return new ERC20Mock(_name, _symbol);
        }
        return new ERC20Mock{ salt: _salt }(_name, _symbol);
    }
}
