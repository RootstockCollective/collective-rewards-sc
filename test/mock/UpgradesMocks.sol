// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { SupportHub } from "../../src/SupportHub.sol";
import { RewardDistributor } from "../../src/RewardDistributor.sol";
import { BuilderRegistry } from "../../src/BuilderRegistry.sol";
import { ChangeExecutor } from "../../src/governance/ChangeExecutor.sol";

/**
 * @title UpgradeableMock
 * @dev Only for upgradeability testing purposes. Generic contract for initialize a mock and get a custom method.
 */
abstract contract UpgradeableMock {
    uint256 public newVariable;

    function initializeMock(uint256 newVariable_) external {
        newVariable = newVariable_;
    }

    function getCustomMockValue() external view virtual returns (uint256);
}

/**
 * @title SupportHubUpgradeMock
 * @dev Only for upgradeability testing purposes. Extends SupportHub adding a new variable.
 */
contract SupportHubUpgradeMock is SupportHub, UpgradeableMock {
    function getCustomMockValue() external view override returns (uint256) {
        return newVariable + builderGauges.length;
    }
}

/**
 * @title RewardDistributorUpgradeMock
 * @dev Only for upgradeability testing purposes. Extends RewardDistributor adding a new variable.
 */
contract RewardDistributorUpgradeMock is RewardDistributor, UpgradeableMock {
    function getCustomMockValue() external view override returns (uint256) {
        return newVariable + uint256(uint160(foundationTreasury));
    }
}

/**
 * @title BuilderRegistryUpgradeMock
 * @dev Only for upgradeability testing purposes. Extends BuilderRegistry adding a new variable.
 */
contract BuilderRegistryUpgradeMock is BuilderRegistry, UpgradeableMock {
    function getCustomMockValue() external view override returns (uint256) {
        return newVariable + uint256(uint160(governor));
    }
}

/**
 * @title ChangeExecutorUpgradeMock
 * @dev Only for upgradeability testing purposes. Extends ChangeExecutor adding a new variable.
 */
contract ChangeExecutorUpgradeMock is ChangeExecutor, UpgradeableMock {
    function getCustomMockValue() external view override returns (uint256) {
        return newVariable + uint256(uint160(governor));
    }
}
