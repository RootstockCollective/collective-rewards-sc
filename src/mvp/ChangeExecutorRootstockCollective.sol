// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Governed } from "./Governed.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IChangeContractRootstockCollective } from "src/interfaces/IChangeContractRootstockCollective.sol";

/**
 * @title ChangeExecutorRootstockCollective
 * @notice This contract is used to handle changes on the project when multiple function calls
 *  or validation are required.
 *  All the governed protected function can be executed when are called through this contract but only can be performed
 *  by the Governor.
 */
contract ChangeExecutorRootstockCollective is ReentrancyGuardUpgradeable, UUPSUpgradeable, Governed {
    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------

    /// @notice governor address
    address internal _governor;
    /// @notice changer contract address to be executed
    address private _currentChangeContract;

    // -----------------------------
    // ------- Initializer ---------
    // -----------------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice contract initializer
     * @param governor_ governor contract address
     */
    function initialize(address governor_) external initializer {
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        _governor = governor_;
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

    /**
     * @notice Function to be called to make the changes in changeContract
     * @dev reverts if is not called by the Governor
     * @param changeContract_ Address of the contract that will execute the changes
     */
    function executeChange(IChangeContractRootstockCollective changeContract_) external {
        _executeChange(changeContract_);
    }

    /**
     * @notice Returns true if the changer_ address is currently authorized to make
     * changes within the system
     * @param changer_ Address of the contract that will be tested
     */
    function isAuthorizedChanger(address changer_) external view virtual returns (bool) {
        return _isAuthorizedChanger(changer_);
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @notice Function to be called to make the changes in changeContract
     * @dev reverts if is not called by the Governor
     * @param changeContract_ Address of the contract that will execute the changes
     */
    function _executeChange(IChangeContractRootstockCollective changeContract_) internal nonReentrant onlyGovernor {
        _enableChangeContract(changeContract_);
        changeContract_.execute();
        _disableChangeContract();
    }

    /**
     * @notice Returns true if the changer_ address is currently authorized to make
     * changes within the system
     * @param changer_ Address of the contract that will be tested
     */
    function _isAuthorizedChanger(address changer_) internal view returns (bool) {
        return _currentChangeContract == changer_;
    }

    /**
     * @notice Authorize the changeContract address to make changes
     * @param changeContract_ Address of the contract that will be authorized
     */
    function _enableChangeContract(IChangeContractRootstockCollective changeContract_) internal {
        _currentChangeContract = address(changeContract_);
    }

    /**
     * @notice UNAuthorize the currentChangeContract address to make changes
     */
    function _disableChangeContract() internal {
        _currentChangeContract = address(0x0);
    }

    /**
     * @inheritdoc UUPSUpgradeable
     * @dev checks that the upgrade is currently authorized by governance
     * @param newImplementation_ new implementation contract address
     */
    /* solhint-disable-next-line no-empty-blocks */
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
