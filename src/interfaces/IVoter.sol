// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

interface IVoter {
    error AlreadyVotedOrDeposited();
    error DistributeWindow();
    error FactoryPathNotApproved();
    error GaugeAlreadyKilled();
    error GaugeAlreadyRevived();
    error GaugeExists();
    error GaugeDoesNotExist(address _builder);
    error GaugeNotAlive(address _gauge);
    error InactiveManagedNFT();
    error MaximumVotingNumberTooLow();
    error NotEnoughVotingPower();
    error NonZeroVotes();
    error NotGovernor();
    error NotEmergencyCouncil();
    error NotMinter();
    error NotWhitelistedNFT();
    error NotWhitelistedToken();
    error SameValue();
    error SpecialVotingWindow();
    error TooManyPools();
    error UnequalLengths();
    error ZeroBalance();
    error ZeroAddress();

    event GaugeCreated(address indexed gaugeFactory, address builder, address gauge, address creator);
    event GaugeKilled(address indexed gauge);
    event GaugeRevived(address indexed gauge);
    event Voted(address indexed voter, address indexed builder, uint256 totalWeight, uint256 timestamp);
    event Abstained(address indexed voter, address indexed builder, uint256 totalWeight, uint256 timestamp);
    event NotifyReward(address indexed sender, address indexed reward, uint256 amount);
    event DistributeReward(address indexed sender, address indexed gauge, uint256 amount);

    /// @notice The builder token use to stake for voting
    function builderToken() external view returns (address);

    /// @notice Address of Minter.sol
    function minter() external view returns (address);

    /// @notice Standard OZ IGovernor using ve for vote weights.
    function governor() external view returns (address);

    /// @notice Custom Epoch Governor using ve for vote weights.
    function epochGovernor() external view returns (address);

    /// @notice credibly neutral party similar to Curve's Emergency DAO
    function emergencyCouncil() external view returns (address);

    /// @notice Gauge factory use for gauges
    function gaugeFactory() external view returns (address);

    /// @dev Total Voting Weights
    function totalWeight() external view returns (uint256);

    /// @dev Most number of pools one voter can vote for at once
    function maxVotingNum() external view returns (uint256);

    // mappings
    /// @dev Pool => Gauge
    function gauges(address pool) external view returns (address);

    /// @dev Nft => Timestamp of last vote (ensures single vote per epoch)
    function lastVoted(address sender) external view returns (uint256);

    /// @dev Gauge => Liveness status
    function isAlive(address gauge) external view returns (bool);

    /// @dev Gauge => Amount claimable
    function claimable(address gauge) external view returns (uint256);

    /// @notice Number of pools with a Gauge
    function length() external view returns (uint256);

    /// @notice Called by Minter to distribute weekly emissions rewards for disbursement amongst gauges.
    /// @dev Assumes totalWeight != 0 (Will never be zero as long as users are voting).
    ///      Throws if not called by minter.
    /// @param _amount Amount of rewards to distribute.
    function notifyRewardAmount(uint256 _amount) external;

    /// @dev Utility to distribute to gauges of pools in range _start to _finish.
    /// @param _start   Starting index of gauges to distribute to.
    /// @param _finish  Ending index of gauges to distribute to.
    function distribute(uint256 _start, uint256 _finish) external;

    /// @dev Utility to distribute to gauges of pools in array.
    /// @param _gauges Array of gauges to distribute to.
    function distribute(address[] memory _gauges) external;
    /* 
    /// @notice Called by users to update voting balances in voting rewards contracts.
    /// @param _tokenId Id of veNFT whose balance you wish to update.
    function poke(uint256 _tokenId) external; */

    /// @notice Called by users to vote for pools. Votes distributed proportionally based on weights.
    ///         Can only vote or deposit into a managed NFT once per epoch.
    ///         Can only vote for gauges that have not been killed.
    /// @dev Weights are distributed proportional to the sum of the weights in the array.
    ///      Throws if length of _builderVote and _weights do not match.
    /// @param _builderVote Array of pools you are voting for.
    /// @param _weights     Weights of pools.
    function vote(address[] calldata _builderVote, uint256[] calldata _weights) external;

    /// @notice Called by users to reset voting state. Required if you wish to make changes to
    ///         veNFT state (e.g. merge, split, deposit into managed etc).
    ///         Cannot reset in the same epoch that you voted in.
    ///         Can vote or deposit into a managed NFT again after reset.
    function reset() external;

    /// @notice Claim emissions from gauges.
    /// @param _gauges Array of gauges to collect emissions from.
    function claimRewards(address[] memory _gauges) external;

    /// @notice Set new governor.
    /// @dev Throws if not called by governor.
    /// @param _governor .
    function setGovernor(address _governor) external;

    /// @notice Set new epoch based governor.
    /// @dev Throws if not called by governor.
    /// @param _epochGovernor .
    function setEpochGovernor(address _epochGovernor) external;

    /// @notice Set new emergency council.
    /// @dev Throws if not called by emergency council.
    /// @param _emergencyCouncil .
    function setEmergencyCouncil(address _emergencyCouncil) external;

    /// @notice Set maximum number of gauges that can be voted for.
    /// @dev Throws if not called by governor.
    ///      Throws if _maxVotingNum is too low.
    ///      Throws if the values are the same.
    /// @param _maxVotingNum .
    function setMaxVotingNum(uint256 _maxVotingNum) external;

    /// @notice Create a new gauge (unpermissioned).
    /// @dev Governor can create a new gauge for a pool with any address.
    /// @param _builderApp .
    function createGauge(address _builderApp) external returns (address);

    /// @notice Kills a gauge. The gauge will not receive any new emissions and cannot be deposited into.
    ///         Can still withdraw from gauge.
    /// @dev Throws if not called by emergency council.
    ///      Throws if gauge already killed.
    /// @param _gauge .
    function killGauge(address _gauge) external;

    /// @notice Revives a killed gauge. Gauge will can receive emissions and deposits again.
    /// @dev Throws if not called by emergency council.
    ///      Throws if gauge is not killed.
    /// @param _gauge .
    function reviveGauge(address _gauge) external;

    /// @dev Update claims to emissions for an array of gauges.
    /// @param _gauges Array of gauges to update emissions for.
    function updateFor(address[] memory _gauges) external;

    /// @dev Update claims to emissions for gauges based on their pool id as stored in Voter.
    /// @param _start   Starting index of pools.
    /// @param _end     Ending index of pools.
    function updateFor(uint256 _start, uint256 _end) external;

    /// @dev Update claims to emissions for single gauge
    /// @param _gauge .
    function updateFor(address _gauge) external;
}
