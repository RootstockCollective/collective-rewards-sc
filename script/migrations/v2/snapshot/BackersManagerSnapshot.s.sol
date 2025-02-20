// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script } from "forge-std/src/Script.sol";
import { MigrationV2Utils } from "./MigrationV2Utils.sol";

contract BackersManagerSnapshot is Script, MigrationV2Utils {
    function run() public {
        _writeDataToJson();
    }

    function _writeDataToJson() internal {
        string memory _json;

        // Fetch GovernanceManager address
        address _governanceManager = address(backersManager.governanceManager());
        _json = vm.serializeAddress("backersManagerData", "governanceManager", _governanceManager);

        // Fetch CycleData
        (uint32 _previousDuration, uint32 _nextDuration, uint64 _previousStart, uint64 _nextStart, uint24 _offset) =
            backersManager.cycleData();

        string memory _cycleDataJson = vm.serializeUint("cycleData", "previousDuration", _previousDuration);
        _cycleDataJson = vm.serializeUint("cycleData", "nextDuration", _nextDuration);
        _cycleDataJson = vm.serializeUint("cycleData", "previousStart", _previousStart);
        _cycleDataJson = vm.serializeUint("cycleData", "nextStart", _nextStart);
        _cycleDataJson = vm.serializeUint("cycleData", "offset", _offset);

        _json = vm.serializeString("backersManagerData", "cycleData", _cycleDataJson);

        // Fetch remaining Data
        _json = vm.serializeUint("backersManagerData", "distributionDuration", backersManager.distributionDuration());
        _json = vm.serializeAddress("backersManagerData", "stakingToken", address(backersManager.stakingToken()));
        _json = vm.serializeAddress("backersManagerData", "rewardToken", backersManager.rewardToken());
        _json = vm.serializeUint("backersManagerData", "totalPotentialReward", backersManager.totalPotentialReward());
        _json = vm.serializeUint(
            "backersManagerData", "tempTotalPotentialReward", backersManager.tempTotalPotentialReward()
        );
        _json = vm.serializeUint("backersManagerData", "rewardsERC20", backersManager.rewardsERC20());
        _json = vm.serializeUint("backersManagerData", "rewardsCoinbase", backersManager.rewardsCoinbase());
        _json = vm.serializeUint(
            "backersManagerData", "indexLastGaugeDistributed", backersManager.indexLastGaugeDistributed()
        );
        _json = vm.serializeBool("backersManagerData", "onDistributionPeriod", backersManager.onDistributionPeriod());

        // Write JSON to file
        vm.writeJson(_json, getVersionedPath("backersManager"));
    }
}
