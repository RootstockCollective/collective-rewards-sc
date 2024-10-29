// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { SponsorsManager } from "../../src/SponsorsManager.sol";
import { RewardDistributor } from "../../src/RewardDistributor.sol";
import { Gauge } from "../../src/gauge/Gauge.sol";
import { ChangeExecutorRootstockCollective } from "src/mvp/ChangeExecutorRootstockCollective.sol";
import { SimplifiedRewardDistributorRootstockCollective } from "src/mvp/SimplifiedRewardDistributorRootstockCollective.sol";
import { GovernanceManager } from "src/governance/GovernanceManager.sol";

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
        return newVariable + getGaugesLength();
    }
}

/**
 * @title RewardDistributorUpgradeMock
 * @dev Only for upgradeability testing purposes. Extends RewardDistributor adding a new variable.
 */
contract RewardDistributorUpgradeMock is RewardDistributor, UpgradeableMock {
    function getCustomMockValue() external view override returns (uint256) {
        return newVariable + uint256(uint160(governanceManager.foundationTreasury()));
    }
}

/**
 * @title GaugeUpgradeMock
 * @dev Only for upgradeability testing purposes. Extends Gauge adding a new variable.
 */
contract GaugeUpgradeMock is Gauge, UpgradeableMock {
    function getCustomMockValue() external view override returns (uint256) {
        return newVariable + uint256(uint160(address(sponsorsManager)));
    }
}

/**
 * @title GovernanceManagerUpgradeMock
 * @dev Only for upgradeability testing purposes. Extends GovernanceManager adding a new variable.
 */
contract GovernanceManagerUpgradeMock is GovernanceManager, UpgradeableMock {
    function getCustomMockValue() external view override returns (uint256) {
        return newVariable + uint256(uint160(governor));
    }
}

/**
 * @title ChangeExecutorUpgradeMock
 * @dev Only for upgradeability testing purposes. Extends ChangeExecutorRootstockCollective adding a new variable.
 */
contract ChangeExecutorUpgradeMock is ChangeExecutorRootstockCollective, UpgradeableMock {
    function getCustomMockValue() external view override returns (uint256) {
        return newVariable + uint256(uint160(_governor));
    }
}

/**
 * @title SimplifiedRewardDistributorUpgradeMock
 * @dev Only for upgradeability testing purposes. Extends SimplifiedRewardDistributorRootstockCollective adding a new
 * variable.
 */
contract SimplifiedRewardDistributorUpgradeMock is SimplifiedRewardDistributorRootstockCollective, UpgradeableMock {
    function getCustomMockValue() external view override returns (uint256) {
        return newVariable + uint256(uint160(governor()));
    }
}
