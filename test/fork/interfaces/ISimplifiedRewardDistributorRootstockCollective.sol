// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ISimplifiedRewardDistributorRootstockCollective {
    // Custom Errors
    error WhitelistStatusWithoutUpdate();

    // Events
    event Whitelisted(address indexed builder_);
    event Unwhitelisted(address indexed builder_);
    event RewardDistributed(
        address indexed rewardToken_, address indexed builder_, address indexed rewardReceiver_, uint256 amount_
    );

    // External Functions
    function initialize(address changeExecutor_, address rewardToken_) external;

    function whitelistBuilder(address builder_, address payable rewardReceiver_) external;

    function removeWhitelistedBuilder(address builder_) external;

    function distribute() external payable;

    function distributeRewardToken() external;

    function distributeCoinbase() external payable;

    function getWhitelistedBuildersLength() external view returns (uint256);

    function getWhitelistedBuilder(uint256 index_) external view returns (address);

    function getWhitelistedBuildersArray() external view returns (address[] memory);

    function isWhitelisted(address builder_) external view returns (bool);

    function builderRewardReceiver(address builder_) external view returns (address payable);

    // Receive function to accept coinbase
    receive() external payable;
}
