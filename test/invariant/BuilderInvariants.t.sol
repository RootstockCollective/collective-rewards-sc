// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseInvariants } from "./BaseInvariants.sol";

contract BuilderInvariants is BaseInvariants {
    /**
     * SCENARIO: a builder kycRevoked, dewhitelisted or revoked is halted
     */
    function invariant_HaltedGauge() public useTime {
        for (uint256 i = 0; i < builders.length; i++) {
            address _builder = builders[i];
            (, bool _kycApproved, bool _whitelisted,, bool _revoked,,) = backersManager.builderState(_builder);
            address _gauge = address(backersManager.builderToGauge(_builder));

            bool _expectedIsHalted = !_kycApproved || !_whitelisted || _revoked;

            assertEq(backersManager.isGaugeHalted(_gauge), _gauge != address(0) && _expectedIsHalted);

            assertEq(backersManager.isGaugeRewarded(_gauge), _gauge != address(0) && !_expectedIsHalted);
        }
    }
}
