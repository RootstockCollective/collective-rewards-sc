// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IChangeContractRootstockCollective } from "../interfaces/IChangeContractRootstockCollective";
import { IGovernanceManager } from "src/interfaces/IGovernanceManager.sol";

/**
 * @title ChangeExecutorRootstockCollective
 * @notice This contract is used to handle changes on the project when multiple function calls
 *  or validation are required.
 *  All the governed protected function can be executed when are called through this contract but only can be performed
 *  by the Governor.
 */
contract ChangeExecutorRootstockCollective is ReentrancyGuardUpgradeable, UUPSUpgradeable {
    modifier onlyGovernor() {
        _governanceManager.validateGovernor(msg.sender);
        _;
    }
    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------

    /// @notice changer contract address to be executed
    IGovernanceManager internal _governanceManager;

    // -----------------------------
    // ------- Initializer ---------
    // -----------------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice contract initializer
     * @param governanceManager_ contract with permissioned roles
     */
    function initialize(IGovernanceManager governanceManager_) external initializer {
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        _governanceManager = governanceManager_;
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice Function to be called to make the changes in changeContract
     * @dev reverts if is not called by the Governor
     * @param changeContract_ Address of the contract that will execute the changes
     */
    function executeChange(IChangeContractRootstockCollective changeContract_) external nonReentrant onlyGovernor {
        _executeChange(changeContract_);
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @notice Function to be called to make the changes in changeContract
     * @dev reverts if is not called by the Governor
     * @param changeContract_ Address of the contract that will execute the changes
     */
    function _executeChange(IChangeContractRootstockCollective changeContract_) internal {
        _governanceManager.updateChanger(address(changeContract_));
        changeContract_.execute();
        _governanceManager.updateChanger(address(0));
    }

    /**
     * @inheritdoc UUPSUpgradeable
     * @dev checks that the upgrade is currently authorized by governance
     * @param newImplementation_ new implementation contract address
     */
    /* solhint-disable-next-line func-state-mutability */
    function _authorizeUpgrade(address newImplementation_) internal override onlyGovernor { }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */

    // Purposely left unused to save some state space to allow for future upgrades
    // slither-disable-next-line unused-state
    uint256[50] private __gap;
}
