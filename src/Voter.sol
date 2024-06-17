// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IGauge } from "./interfaces/gauges/IGauge.sol";
import { IGaugeFactory } from "./interfaces/factories/IGaugeFactory.sol";
import { GaugeFactory } from "./factories/GaugeFactory.sol";
/* import {IMinter} from "./interfaces/IMinter.sol";
import {IReward} from "./interfaces/IReward.sol"; */
import { IVoter } from "./interfaces/IVoter.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { TimeLibrary } from "./libraries/TimeLibrary.sol";

/// @title Velodrome V2 Voter
/// @author velodrome.finance, @franciscotobar, @antomor
/// @notice Manage votes, emission distribution, and gauge creation within the Velodrome ecosystem.
///         Also provides support for depositing and withdrawing from managed veNFTs.
contract Voter is IVoter, ReentrancyGuard {
    using SafeERC20 for IERC20;
    /// @inheritdoc IVoter

    address public immutable builderToken;
    /// @notice Base token of ve contract
    address internal immutable rewardToken;
    /// @notice Rewards are released over 7 days
    uint256 internal constant DURATION = 7 days;
    /// @inheritdoc IVoter
    address public minter;
    /// @inheritdoc IVoter
    address public governor;
    /// @inheritdoc IVoter
    address public epochGovernor;
    /// @inheritdoc IVoter
    address public emergencyCouncil;
    /// @inheritdoc IVoter
    address public gaugeFactory;

    /// @inheritdoc IVoter
    uint256 public totalWeight;
    /// @inheritdoc IVoter
    uint256 public maxVotingNum;
    uint256 internal constant MIN_MAXVOTINGNUM = 10;

    /// @dev All builders viable for incentives
    address[] public builders;
    /// @inheritdoc IVoter
    mapping(address => address) public gauges;
    /// @inheritdoc IVoter
    mapping(address => uint256) public lastVoted;
    /// @dev voter => List of builders voted for by voter
    mapping(address => address[]) public voterBuilders;
    /// @dev voter => builders => Is already voted
    mapping(address => mapping(address => bool)) public voterBuildersVoted;
    /// @inheritdoc IVoter
    mapping(address => bool) public isAlive;
    /// @dev Accumulated distributions per vote
    uint256 internal index;
    /// @dev Gauge => Accum ulated gauge distributions
    mapping(address => uint256) internal supplyIndex;
    /// @inheritdoc IVoter
    mapping(address => uint256) public claimable;

    constructor(address _builderToken, address _rewardToken) {
        builderToken = _builderToken;
        rewardToken = _rewardToken;
        address _sender = msg.sender;
        minter = _sender;
        governor = _sender;
        epochGovernor = _sender;
        emergencyCouncil = _sender;
        maxVotingNum = 30;
        gaugeFactory = address(new GaugeFactory());
    }

    function epochStart(uint256 _timestamp) external pure returns (uint256) {
        return TimeLibrary.epochStart(_timestamp);
    }

    function epochNext(uint256 _timestamp) external pure returns (uint256) {
        return TimeLibrary.epochNext(_timestamp);
    }

    function epochVoteStart(uint256 _timestamp) external pure returns (uint256) {
        return TimeLibrary.epochVoteStart(_timestamp);
    }

    function epochVoteEnd(uint256 _timestamp) external pure returns (uint256) {
        return TimeLibrary.epochVoteEnd(_timestamp);
    }

    /// @dev requires initialization with at least rewardToken
    function initialize(address _minter) external {
        if (msg.sender != minter) revert NotMinter();
        minter = _minter;
    }

    /// @inheritdoc IVoter
    function setGovernor(address _governor) public {
        if (msg.sender != governor) revert NotGovernor();
        if (_governor == address(0)) revert ZeroAddress();
        governor = _governor;
    }

    /// @inheritdoc IVoter
    function setEpochGovernor(address _epochGovernor) public {
        if (msg.sender != governor) revert NotGovernor();
        if (_epochGovernor == address(0)) revert ZeroAddress();
        epochGovernor = _epochGovernor;
    }

    /// @inheritdoc IVoter
    function setEmergencyCouncil(address _council) public {
        if (msg.sender != emergencyCouncil) revert NotEmergencyCouncil();
        if (_council == address(0)) revert ZeroAddress();
        emergencyCouncil = _council;
    }

    /// @inheritdoc IVoter
    function setMaxVotingNum(uint256 _maxVotingNum) external {
        if (msg.sender != governor) revert NotGovernor();
        if (_maxVotingNum < MIN_MAXVOTINGNUM) revert MaximumVotingNumberTooLow();
        if (_maxVotingNum == maxVotingNum) revert SameValue();
        maxVotingNum = _maxVotingNum;
    }

    /// @inheritdoc IVoter
    function reset() external nonReentrant {
        _reset(msg.sender);
    }

    function _reset(address _voter) internal {
        address[] storage _builderVote = voterBuilders[_voter];
        uint256 _builderVoteCnt = _builderVote.length;
        uint256 _totalWeight = 0;

        for (uint256 i = 0; i < _builderVoteCnt; i++) {
            address _builder = _builderVote[i];
            address _gauge = gauges[_builder];
            uint256 _votes = IGauge(_gauge).balanceOf(_voter);
            IGauge(_gauge).withdraw(_votes, _voter);
            _totalWeight += _votes;
            voterBuildersVoted[_voter][_builder] = false;
            emit Abstained(msg.sender, _builder, _votes, block.timestamp);
        }
        totalWeight -= _totalWeight;
        delete voterBuilders[_voter];
    }

    /*  /// @inheritdoc IVoter
    function poke(uint256 _tokenId) external nonReentrant {
        if (block.timestamp <= TimeLibrary.epochVoteStart(block.timestamp)) revert DistributeWindow();
        _poke(_tokenId);
    }

    function _poke(uint256 _tokenId) internal {
        address[] memory _poolVote = poolVote[_tokenId];
        uint256 _poolCnt = _poolVote.length;
        uint256[] memory _weights = new uint256[](_poolCnt);

        for (uint256 i = 0; i < _poolCnt; i++) {
            _weights[i] = votes[_tokenId][_poolVote[i]];
        }
        _vote(_tokenId, _weight, _poolVote, _weights);
    } */

    function _vote(address _voter, address[] memory _builderVote, uint256[] memory _weights) internal {
        uint256 _builderCnt = _builderVote.length;
        uint256 _totalWeight = 0;

        for (uint256 i = 0; i < _builderCnt; i++) {
            _totalWeight += _weights[i];
        }

        uint256 _weight = IERC20(builderToken).balanceOf(_voter);
        if (_totalWeight > _weight) revert NotEnoughVotingPower();
        IERC20(builderToken).safeTransferFrom(_voter, address(this), _totalWeight);

        for (uint256 i = 0; i < _builderCnt; i++) {
            address _builder = _builderVote[i];
            address _gauge = gauges[_builder];
            if (_gauge == address(0)) revert GaugeDoesNotExist(_builder);
            if (!isAlive[_gauge]) revert GaugeNotAlive(_gauge);
            if (_weights[i] == 0) revert ZeroBalance();
            if (!voterBuildersVoted[_voter][_builder]) {
                voterBuildersVoted[_voter][_builder] = true;
                voterBuilders[_voter].push(_builder);
            }
            IGauge(_gauge).deposit(_weights[i], _voter);
            emit Voted(_voter, _builder, _weights[i], block.timestamp);
        }
        totalWeight += _totalWeight;
    }

    /// @inheritdoc IVoter
    function vote(address[] calldata _builderVote, uint256[] calldata _weights) external nonReentrant {
        address _voter = msg.sender;
        if (_builderVote.length != _weights.length) revert UnequalLengths();
        if (_builderVote.length > maxVotingNum) revert TooManyPools();
        uint256 _timestamp = block.timestamp;
        lastVoted[_voter] = _timestamp;
        _vote(_voter, _builderVote, _weights);
    }

    /// @inheritdoc IVoter
    function createGauge(address _builder) external nonReentrant returns (address) {
        if (gauges[_builder] != address(0)) revert GaugeExists();

        address _gauge = IGaugeFactory(gaugeFactory).createGauge(builderToken, rewardToken);

        IERC20(builderToken).approve(_gauge, type(uint256).max);

        gauges[_builder] = _gauge;
        isAlive[_gauge] = true;
        builders.push(_builder);

        emit GaugeCreated(gaugeFactory, _builder, _gauge, msg.sender);
        return _gauge;
    }

    /// @inheritdoc IVoter
    function killGauge(address _gauge) external {
        if (msg.sender != emergencyCouncil) revert NotEmergencyCouncil();
        if (!isAlive[_gauge]) revert GaugeAlreadyKilled();
        // Return claimable back to minter
        uint256 _claimable = claimable[_gauge];
        if (_claimable > 0) {
            IERC20(rewardToken).safeTransfer(minter, _claimable);
        }
        isAlive[_gauge] = false;
        emit GaugeKilled(_gauge);
    }

    /// @inheritdoc IVoter
    function reviveGauge(address _gauge) external {
        if (msg.sender != emergencyCouncil) revert NotEmergencyCouncil();
        if (isAlive[_gauge]) revert GaugeAlreadyRevived();
        isAlive[_gauge] = true;
        emit GaugeRevived(_gauge);
    }

    /// @inheritdoc IVoter
    function length() external view returns (uint256) {
        return builders.length;
    }

    /// @inheritdoc IVoter
    function notifyRewardAmount(uint256 _amount) external {
        address sender = msg.sender;
        if (sender != minter) revert NotMinter();
        IERC20(rewardToken).safeTransferFrom(sender, address(this), _amount); // transfer the distribution in
        uint256 _ratio = (_amount * 1e18) / Math.max(totalWeight, 1); // 1e18 adjustment is removed during claim
        if (_ratio > 0) {
            index += _ratio;
        }
        emit NotifyReward(sender, rewardToken, _amount);
    }

    /// @inheritdoc IVoter
    function updateFor(address[] memory _gauges) external {
        uint256 _length = _gauges.length;
        for (uint256 i = 0; i < _length; i++) {
            _updateFor(_gauges[i]);
        }
    }

    /// @inheritdoc IVoter
    function updateFor(uint256 start, uint256 end) external {
        for (uint256 i = start; i < end; i++) {
            _updateFor(gauges[builders[i]]);
        }
    }

    /// @inheritdoc IVoter
    function updateFor(address _gauge) external {
        _updateFor(_gauge);
    }

    function _updateFor(address _gauge) internal {
        uint256 _supplied = IGauge(_gauge).totalSupply();
        if (_supplied > 0) {
            uint256 _supplyIndex = supplyIndex[_gauge];
            uint256 _index = index; // get global index0 for accumulated distribution
            supplyIndex[_gauge] = _index; // update _gauge current position to global position
            uint256 _delta = _index - _supplyIndex; // see if there is any difference that need to be accrued
            if (_delta > 0) {
                uint256 _share = (_supplied * _delta) / 1e18; // add accrued difference for each supplied token

                if (isAlive[_gauge]) {
                    claimable[_gauge] += _share;
                } else {
                    IERC20(rewardToken).safeTransfer(minter, _share);
                    // send rewards back to Minter so they're not stuck in Voter
                }
            }
        } else {
            supplyIndex[_gauge] = index; // new users are set to the default global state
        }
    }

    /// @inheritdoc IVoter
    function claimRewards(address[] memory _gauges) external {
        uint256 _length = _gauges.length;
        for (uint256 i = 0; i < _length; i++) {
            IGauge(_gauges[i]).getReward(msg.sender);
        }
    }

    function _distribute(address _gauge) internal {
        address sender = msg.sender;
        _updateFor(_gauge);
        uint256 _claimable = claimable[_gauge];
        if (_claimable > IGauge(_gauge).left() && _claimable > DURATION) {
            claimable[_gauge] = 0;
            IERC20(rewardToken).approve(_gauge, _claimable);
            IGauge(_gauge).notifyRewardAmount(_claimable);
            IERC20(rewardToken).approve(_gauge, 0);
            emit DistributeReward(sender, _gauge, _claimable);
        }
    }

    /// @inheritdoc IVoter
    function distribute(uint256 _start, uint256 _finish) external nonReentrant {
        for (uint256 x = _start; x < _finish; x++) {
            _distribute(gauges[builders[x]]);
        }
    }

    /// @inheritdoc IVoter
    function distribute(address[] memory _gauges) external nonReentrant {
        uint256 _length = _gauges.length;
        for (uint256 x = 0; x < _length; x++) {
            _distribute(_gauges[x]);
        }
    }
}
