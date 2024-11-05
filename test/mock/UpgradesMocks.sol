// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { SponsorsManagerRootstockCollective } from "../../src/SponsorsManagerRootstockCollective.sol";
import { RewardDistributor } from "../../src/RewardDistributor.sol";
import { GaugeRootstockCollective } from "src/gauge/GaugeRootstockCollective.sol";
import { ChangeExecutorRootstockCollective } from "src/mvp/ChangeExecutorRootstockCollective.sol";
import { SimplifiedRewardDistributorRootstockCollective } from
    "src/mvp/SimplifiedRewardDistributorRootstockCollective.sol";
import { GovernanceManagerRootstockCollective } from "src/governance/GovernanceManagerRootstockCollective.sol";

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
 * @title SponsorsManagerRootstockCollectiveUpgradeMock
 * @dev Only for upgradeability testing purposes. Extends SponsorsManagerRootstockCollective adding a new variable.
 */
contract SponsorsManagerRootstockCollectiveUpgradeMock is SponsorsManagerRootstockCollective, UpgradeableMock {
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
contract GaugeUpgradeMock is GaugeRootstockCollective, UpgradeableMock {
    function getCustomMockValue() external view override returns (uint256) {
        return newVariable + uint256(uint160(address(sponsorsManager)));
    }
}

/**
 * @title GovernanceManagerRootstockCollectiveUpgradeMock
 * @dev Only for upgradeability testing purposes. Extends GovernanceManagerRootstockCollective adding a new variable.
 */
contract GovernanceManagerRootstockCollectiveUpgradeMock is GovernanceManagerRootstockCollective, UpgradeableMock {
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
