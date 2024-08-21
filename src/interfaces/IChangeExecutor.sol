// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

/**
 * @title IChangeExecutor
 *   @notice This interface is check if a changer is authotized by the governance system
 */
interface IChangeExecutor {
    /**
     * @notice returns governor address
     */
    function governor() external view returns (address);

    /**
     * @notice Returns true if the changer_ address is currently authorized to make
     * changes within the system
     * @param changer_ Address of the contract that will be tested
     */
    function isAuthorizedChanger(address changer_) external view returns (bool);
}
