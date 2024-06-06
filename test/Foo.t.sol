// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";

import { Foo } from "../src/Foo.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract FooTest is Test {
    Foo internal foo;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        // Instantiate the contract-under-test.
        foo = new Foo();
    }

    /// @dev Basic test. Run it with `forge test -vvv` to see the console log.
    function test_Example() external view {
        console2.log("Hello World");
        uint256 x = 42;
        assertEq(foo.id(x), x, "value mismatch");
    }

    /// @dev Fuzz test that provides random values for an unsigned integer, but which rejects zero as an input.
    /// If you need more sophisticated input validation, you should use the `bound` utility instead.
    /// See https://twitter.com/PaulRBerg/status/1622558791685242880
    function testFuzz_Example(uint256 x) external view {
        vm.assume(x != 0); // or x = bound(x, 1, 100)
        assertEq(foo.id(x), x, "value mismatch");
    }
}
