// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { BaseInvariants } from "./BaseInvariants.sol";

contract BuilderInvariants is BaseInvariants {
    /**
     * SCENARIO: a builder kycRevoked, community banned or revoked is halted
     */
    function invariant_HaltedGauge() public useTime {
        for (uint256 i = 0; i < builders.length; i++) {
            address _builder = builders[i];
            (, bool _kycApproved, bool _communityApproved,, bool _revoked,,) = builderRegistry.builderState(_builder);
            address _gauge = address(builderRegistry.builderToGauge(_builder));

            bool _expectedIsHalted = !_kycApproved || !_communityApproved || _revoked;

            assertEq(builderRegistry.isGaugeHalted(_gauge), _gauge != address(0) && _expectedIsHalted);

            assertEq(builderRegistry.isGaugeRewarded(_gauge), _gauge != address(0) && !_expectedIsHalted);
        }
    }
}
