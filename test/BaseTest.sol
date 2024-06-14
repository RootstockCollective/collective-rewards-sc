// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Test } from "forge-std/src/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ERC20Utils } from "./utils/ERC20Utils.sol";
import { MockERC20 } from "./utils/MockERC20.sol";

import { Gauge } from "../src/gauges/Gauge.sol";
import { Voter } from "../src/Voter.sol";

contract BaseTest is Test {
    ERC20Utils erc20Utils;

    address builder1;
    IERC20 builderToken;
    IERC20 rewardToken;
    Voter voter;
    Gauge[] gauges;
    address[] builders;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        builders.push(address(1));
        builders.push(address(2));
        builders.push(address(3));

        erc20Utils = new ERC20Utils();
        builderToken = IERC20(new MockERC20("BUILD", "BUILD", 18));
        rewardToken = IERC20(new MockERC20("RIF", "RIF", 18));
        voter = new Voter(address(builderToken), address(rewardToken));
        gauges.push(Gauge(voter.createGauge(builders[0])));
        gauges.push(Gauge(voter.createGauge(builders[1])));
        gauges.push(Gauge(voter.createGauge(builders[2])));
    }
}
