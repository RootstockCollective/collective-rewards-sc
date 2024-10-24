// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Governed, IChangeExecutor } from "./Governed.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title Governed
 * @notice Base contract to be inherited by governed contracts
 * @dev This contract is not usable on its own since it does not have any _productive useful_ behavior
 * The only purpose of this contract is to define some useful modifiers and functions to be used on the
 * governance aspect of the child contract
 */
abstract contract Upgradeable is UUPSUpgradeable, Governed {
    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------

    /// @notice governor contract address
    address internal _governor;

    // -----------------------------
    // ------- Initializer ---------
    // -----------------------------

    /**
     * @notice contract initializer
     * @param changeExecutor_ ChangeExecutor contract address
     */
    function __Upgradeable_init(address changeExecutor_) internal onlyInitializing {
        __UUPSUpgradeable_init();
        changeExecutor = IChangeExecutor(changeExecutor_);
        _governor = IChangeExecutor(changeExecutor_).governor();
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice maintains Governed interface. Returns governed address
     */
    function governor() public view override returns (address) {
        return _governor;
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @inheritdoc UUPSUpgradeable
     * @dev checks that the changer that will do the upgrade is currently authorized by governance to makes
     * changes within the system
     * @param newImplementation_ new implementation contract address
     */
    /* solhint-disable-next-line no-empty-blocks */
    function _authorizeUpgrade(address newImplementation_) internal override onlyGovernorOrAuthorizedChanger { }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */

    // Purposely left unused to save some state space to allow for future upgrades
    // slither-disable-next-line unused-state
    uint256[50] private __gap;
}
