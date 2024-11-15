// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BackersManagerRootstockCollective } from "../../src/BackersManagerRootstockCollective.sol";
import { RewardDistributorRootstockCollective } from "../../src/RewardDistributorRootstockCollective.sol";
import { GaugeRootstockCollective } from "src/gauge/GaugeRootstockCollective.sol";
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
 * @title BackersManagerRootstockCollectiveUpgradeMock
 * @dev Only for upgradeability testing purposes. Extends BackersManagerRootstockCollective adding a new variable.
 */
contract BackersManagerRootstockCollectiveUpgradeMock is BackersManagerRootstockCollective, UpgradeableMock {
    function getCustomMockValue() external view override returns (uint256) {
        return newVariable + getGaugesLength();
    }
}

/**
 * @title RewardDistributorRootstockCollectiveUpgradeMock
 * @dev Only for upgradeability testing purposes. Extends RewardDistributorRootstockCollective adding a new variable.
 */
contract RewardDistributorRootstockCollectiveUpgradeMock is RewardDistributorRootstockCollective, UpgradeableMock {
    function getCustomMockValue() external view override returns (uint256) {
        return newVariable + uint256(uint160(governanceManager.foundationTreasury()));
    }
}

/**
 * @title GaugeUpgradeMock
 * @dev Only for upgradeability testing purposes. Extends GaugeRootstockCollective adding a new variable.
 */
contract GaugeUpgradeMock is GaugeRootstockCollective, UpgradeableMock {
    function getCustomMockValue() external view override returns (uint256) {
        return newVariable + uint256(uint160(address(backersManager)));
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
