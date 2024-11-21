// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStRIFTokenV02 is IERC20 {
    function initialize(IERC20 rifToken, address initialOwner) external;
    function initializeV2() external;
    function version() external pure returns (uint64);
    function transferAndDelegate(address to, uint256 value) external;
    function transferFromAndDelegate(address from, address to, uint256 value) external;
    function depositAndDelegate(address to, uint256 value) external;
    function setCollectiveRewardsAddress(address collectiveRewardsAddress) external;
    function setCollectiveRewardsErrorSkipFlag(bool shouldBeSkipped) external;
    function decimals() external view returns (uint8);
    function withdrawTo(address account, uint256 value) external returns (bool);
    function nonces(address owner) external view returns (uint256);

    error STRIFStakedInCollectiveRewardsCanWithdraw(bool canWithdraw);
    error STRIFSupportsERC165(bool _supports);
    error STRIFSupportsICollectiveRewardsCheck(bool _supports);
    error CollectiveRewardsErrored(string reason);
    error CollectiveRewardsErroredBytes(bytes reason);

    event STRIFCollectiveRewardsErrorSkipChangedTo(bool shouldBeSkipped);
    event CollectiveRewardsAddressHasBeenChanged(address collectiveRewardsAddress);
}
