// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title IBoosterRootstockCollective
 */
interface IBoosterRootstockCollective {
    function ownerOf(uint256 tokenId_) external returns (address owner_);
}
