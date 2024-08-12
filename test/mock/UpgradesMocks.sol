// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { SponsorsManager } from "../../src/SponsorsManager.sol";
import { RewardDistributor } from "../../src/RewardDistributor.sol";
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
 * @title SponsorsManagerUpgradeMock
 * @dev Only for upgradeability testing purposes. Extends SponsorsManager adding a new variable.
 */
contract SponsorsManagerUpgradeMock is SponsorsManager, UpgradeableMock {
    function getCustomMockValue() external view override returns (uint256) {
        return newVariable + gauges.length;
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
 * @title ChangeExecutorUpgradeMock
 * @dev Only for upgradeability testing purposes. Extends ChangeExecutor adding a new variable.
 */
contract ChangeExecutorUpgradeMock is ChangeExecutor, UpgradeableMock {
    function getCustomMockValue() external view override returns (uint256) {
        return newVariable + uint256(uint160(governor));
    }
}
