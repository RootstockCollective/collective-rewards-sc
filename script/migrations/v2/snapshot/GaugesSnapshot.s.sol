// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { GaugeRootstockCollective } from "src/gauge/GaugeRootstockCollective.sol";
import { MigrationV2Utils } from "./MigrationV2Utils.sol";

contract GaugesSnapshot is MigrationV2Utils {
    address public constant COINBASE_ADDRESS = address(uint160(uint256(keccak256("COINBASE_ADDRESS"))));

    function run() public {
        _writeGaugesDataToJson();
    }

    function _writeGaugesDataToJson() internal {
        uint256 _gaugesLength = builderRegistry.getGaugesLength();
        address[] memory _gauges = new address[](_gaugesLength);
        string memory _json = "";

        for (uint256 i = 0; i < _gaugesLength; i++) {
            GaugeRootstockCollective _gauge = GaugeRootstockCollective(builderRegistry.getGaugeAt(i));
            _gauges[i] = address(_gauge);
            address _rif = _gauge.rewardToken();

            string memory _gaugeJson = vm.serializeAddress("gauge", "rewardToken", _rif);
            _gaugeJson = vm.serializeAddress("gauge", "backersManager", address(backersManager));
            _gaugeJson = vm.serializeUint("gauge", "totalAllocation", _gauge.totalAllocation());
            _gaugeJson = vm.serializeUint("gauge", "rewardShares", _gauge.rewardShares());

            _gaugeJson = vm.serializeString("gauge", "rif", _getRewardDataJson(_gauge, _rif));
            _gaugeJson = vm.serializeString("gauge", "rbtc", _getRewardDataJson(_gauge, COINBASE_ADDRESS));

            _json = vm.serializeString("gauges", toString(address(_gauge)), _gaugeJson);
        }

        _json = vm.serializeAddress("gauges", "gauges", _gauges);

        vm.writeJson(_json, getVersionedPath("gauges"));
    }

    function _getRewardDataJson(
        GaugeRootstockCollective gauge_,
        address rewardToken_
    )
        internal
        returns (string memory json_)
    {
        json_ = vm.serializeUint("rewardData", "rewardRate", gauge_.rewardRate(rewardToken_));
        json_ = vm.serializeUint("rewardData", "rewardPerTokenStored", gauge_.rewardPerTokenStored(rewardToken_));
        json_ = vm.serializeUint("rewardData", "rewardMissing", gauge_.rewardMissing(rewardToken_));
        json_ = vm.serializeUint("rewardData", "lastUpdateTime", gauge_.lastUpdateTime(rewardToken_));
        json_ = vm.serializeUint("rewardData", "builderRewards", gauge_.builderRewards(rewardToken_));
    }
}
