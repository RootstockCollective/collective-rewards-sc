// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script } from "forge-std/src/Script.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { GaugeRootstockCollective } from "src/gauge/GaugeRootstockCollective.sol";
import { GaugeFactoryRootstockCollective } from "src/gauge/GaugeFactoryRootstockCollective.sol";
import { MigrationV2Utils } from "./MigrationV2Utils.sol";

using EnumerableSet for EnumerableSet.AddressSet;

struct BuilderState {
    bool activated;
    bool kycApproved;
    bool communityApproved;
    bool paused;
    bool revoked;
    bytes7 reserved;
    bytes20 pausedReason;
}

struct RewardPercentageData {
    uint64 previous;
    uint64 next;
    uint128 cooldownEndTime;
}

struct BuilderRegistryData {
    address rewardDistributor;
    mapping(address builder => BuilderState state) builderState;
    mapping(address builder => address rewardReceiver) builderRewardReceiver;
    mapping(address builder => address rewardReceiverReplacement) builderRewardReceiverReplacement;
    mapping(address builder => bool hasRewardReceiverPendingApproval) hasBuilderRewardReceiverPendingApproval;
    mapping(address builder => RewardPercentageData rewardPercentageData) backerRewardPercentage;
    EnumerableSet.AddressSet gauges;
    EnumerableSet.AddressSet haltedGauges;
    GaugeFactoryRootstockCollective gaugeFactory;
    mapping(address builder => GaugeRootstockCollective gauge) builderToGauge;
    mapping(GaugeRootstockCollective gauge => address builder) gaugeToBuilder;
    mapping(GaugeRootstockCollective gauge => uint256 lastPeriodFinish) haltedGaugeLastPeriodFinish;
    uint128 rewardPercentageCooldown;
    address[] builders;
}

contract BuilderRegistrySnapshot is Script, MigrationV2Utils {
    BuilderRegistryData internal _buildersData;

    function run() public {
        _storeBuildersV1Data();
        writeBuilderRegistryDataToJson();
    }

    function writeBuilderRegistryDataToJson() public {
        // Serialize BuilderRegistryData fields
        string memory _json = vm.serializeAddress("buildersData", "rewardDistributor", _buildersData.rewardDistributor);

        // Serialize gauges and haltedGauges
        _json = vm.serializeAddress("buildersData", "gauges", _buildersData.gauges.values());
        _json = vm.serializeAddress("buildersData", "haltedGauges", _buildersData.haltedGauges.values());
        _json = vm.serializeAddress("buildersData", "gaugeFactory", address(_buildersData.gaugeFactory));
        _json = vm.serializeUint("buildersData", "rewardPercentageCooldown", _buildersData.rewardPercentageCooldown);
        _json = vm.serializeAddress("buildersData", "backersManager", address(backersManager));

        // Serialize BuilderState mappings for each builder
        for (uint256 i = 0; i < _buildersData.builders.length; i++) {
            address _builder = _buildersData.builders[i];
            string memory _builderStr = vm.toString(_builder);

            BuilderState storage _state = _buildersData.builderState[_builder];
            string memory _builderJson =
                vm.serializeBool("builder", string(abi.encodePacked("activated")), _state.activated);
            _builderJson = vm.serializeBool("builder", "kycApproved", _state.kycApproved);
            _builderJson = vm.serializeBool("builder", "communityApproved", _state.communityApproved);
            _builderJson = vm.serializeBool("builder", "paused", _state.paused);
            _builderJson = vm.serializeBool("builder", "revoked", _state.revoked);
            _builderJson = vm.serializeBytes32("builder", "reserved", bytes32(_state.reserved));
            _builderJson = vm.serializeBytes32("builder", "pausedReason", bytes32(_state.pausedReason));

            RewardPercentageData storage _rewardPercentageData = _buildersData.backerRewardPercentage[_builder];
            string memory _backerRewardPercentageJson =
                vm.serializeUint("backerRewardPercentage", "previous", _rewardPercentageData.previous);
            _backerRewardPercentageJson =
                vm.serializeUint("backerRewardPercentage", "rewardPercentageData", _rewardPercentageData.next);
            _backerRewardPercentageJson =
                vm.serializeUint("backerRewardPercentage", "cooldownEndTime", _rewardPercentageData.cooldownEndTime);
            _builderJson = vm.serializeString(_builderStr, "backerRewardPercentage", _backerRewardPercentageJson);

            // Serialize mappings for builder reward receivers
            string memory _rewardReceiverJson = vm.serializeAddress(
                "rewardReceiver", "builderRewardReceiver", _buildersData.builderRewardReceiver[_builder]
            );
            _rewardReceiverJson = vm.serializeAddress(
                "rewardReceiver",
                "builderRewardReceiverReplacement",
                _buildersData.builderRewardReceiverReplacement[_builder]
            );
            _rewardReceiverJson = vm.serializeBool(
                "rewardReceiver",
                "hasRewardReceiverPendingApproval",
                _buildersData.hasBuilderRewardReceiverPendingApproval[_builder]
            );
            _builderJson = vm.serializeString("builder", "rewardReceiver", _rewardReceiverJson);

            GaugeRootstockCollective _gauge = _buildersData.builderToGauge[_builder];
            _builderJson = vm.serializeAddress("builder", "gauge", address(_gauge));

            _builderJson = vm.serializeUint(
                "builder", "haltedGaugeLastPeriodFinish", _buildersData.haltedGaugeLastPeriodFinish[_gauge]
            );

            string memory _buildersJson = vm.serializeString("builders", _builderStr, _builderJson);
            _json = vm.serializeString("buildersData", "builders", _buildersJson);
        }

        // Write the entire namespace to JSON
        vm.writeJson(_json, getVersionedPath("buildersRegistry"));
    }

    function _storeBuildersV1Data() internal {
        uint256 _gaugesLength = builderRegistry.getGaugesLength();
        _buildersData.rewardDistributor = builderRegistry.rewardDistributor();
        _buildersData.rewardPercentageCooldown = builderRegistry.rewardPercentageCooldown();
        _buildersData.gaugeFactory = GaugeFactoryRootstockCollective(builderRegistry.gaugeFactory());

        for (uint256 i = 0; i < _gaugesLength; i++) {
            address _gauge = builderRegistry.getGaugeAt(i);
            address _builder = builderRegistry.gaugeToBuilder(GaugeRootstockCollective(_gauge));
            _buildersData.builders.push(_builder);
            _buildersData.builderState[_builder] = _getBuilderStateV1(_builder);
            _buildersData.builderRewardReceiver[_builder] = builderRegistry.builderRewardReceiver(_builder);
            _buildersData.builderRewardReceiverReplacement[_builder] =
                builderRegistry.builderRewardReceiverReplacement(_builder);
            _buildersData.hasBuilderRewardReceiverPendingApproval[_builder] =
                builderRegistry.hasBuilderRewardReceiverPendingApproval(_builder);
            _buildersData.backerRewardPercentage[_builder] = _getBackerRewardPercentageData(_builder);
            _buildersData.builderToGauge[_builder] = GaugeRootstockCollective(_gauge);
            _buildersData.gaugeToBuilder[GaugeRootstockCollective(_gauge)] = _builder;
            _buildersData.haltedGaugeLastPeriodFinish[GaugeRootstockCollective(_gauge)] =
                builderRegistry.haltedGaugeLastPeriodFinish(GaugeRootstockCollective(_gauge));

            if (builderRegistry.isGaugeHalted(_gauge)) {
                _buildersData.haltedGauges.add(_gauge);
            } else {
                _buildersData.gauges.add(_gauge);
            }
        }
    }

    function _getBuilderStateV1(address builder_) internal view returns (BuilderState memory) {
        (
            bool _activated,
            bool _kycApproved,
            bool _communityApproved,
            bool _paused,
            bool _revoked,
            bytes7 _reserved,
            bytes20 _pausedReason
        ) = builderRegistry.builderState(builder_);
        return BuilderState({
            activated: _activated,
            kycApproved: _kycApproved,
            communityApproved: _communityApproved,
            paused: _paused,
            revoked: _revoked,
            reserved: _reserved,
            pausedReason: _pausedReason
        });
    }

    function _getBackerRewardPercentageData(address builder_) internal view returns (RewardPercentageData memory) {
        (uint64 _previous, uint64 _next, uint128 _cooldownEndTime) = builderRegistry.backerRewardPercentage(builder_);
        return RewardPercentageData({ previous: _previous, next: _next, cooldownEndTime: _cooldownEndTime });
    }
}
