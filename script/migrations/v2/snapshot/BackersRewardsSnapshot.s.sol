// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script } from "forge-std/src/Script.sol";
import { GaugeRootstockCollective } from "src/gauge/GaugeRootstockCollective.sol";
import { MigrationV2Utils } from "./MigrationV2Utils.sol";

contract BackersSnapshot is Script, MigrationV2Utils {
    address public constant COINBASE_ADDRESS = address(uint160(uint256(keccak256("COINBASE_ADDRESS"))));

    function run() public {
        _writeDataToJson();
    }

    function _writeDataToJson() internal {
        // Read backers from file
        string memory _jsonContent = vm.readFile(getPath("backersList"));
        address[] memory _backers = abi.decode(vm.parseJson(_jsonContent), (address[]));

        // Fetch all gauges
        uint256 _gaugesLength = builderRegistry.getGaugesLength();
        address[] memory _gauges = new address[](_gaugesLength);

        for (uint256 i = 0; i < _gaugesLength; i++) {
            _gauges[i] = builderRegistry.getGaugeAt(i);
        }

        // Start JSON serialization
        string memory _json = vm.serializeAddress("backersData", "allBackers", _backers);
        _json = vm.serializeAddress("backersData", "allGauges", _gauges);

        for (uint256 i = 0; i < _backers.length; i++) {
            address _backer = _backers[i];
            string memory _backerJson = "";

            for (uint256 j = 0; j < _gaugesLength; j++) {
                address _gauge = _gauges[j];
                address _rif = GaugeRootstockCollective(_gauge).rewardToken();

                uint256 _rifRewardPerTokenPaid =
                    GaugeRootstockCollective(_gauge).backerRewardPerTokenPaid(_rif, _backer);
                uint256 _rbtcRewardPerTokenPaid =
                    GaugeRootstockCollective(_gauge).backerRewardPerTokenPaid(COINBASE_ADDRESS, _backer);
                uint256 _rifRewards = GaugeRootstockCollective(_gauge).rewards(_rif, _backer);
                uint256 _rbtcRewards = GaugeRootstockCollective(_gauge).rewards(COINBASE_ADDRESS, _backer);

                string memory _gaugeJson = vm.serializeUint("gauge", "rifRewardPerTokenPaid", _rifRewardPerTokenPaid);
                _gaugeJson = vm.serializeUint("gauge", "rbtcRewardPerTokenPaid", _rbtcRewardPerTokenPaid);
                _gaugeJson = vm.serializeUint("gauge", "rifRewards", _rifRewards);
                _gaugeJson = vm.serializeUint("gauge", "rbtcRewards", _rbtcRewards);

                _backerJson = vm.serializeString("backer", toString(_gauge), _gaugeJson);
            }

            _json = vm.serializeString("backersData", toString(_backer), _backerJson);
        }

        vm.writeJson(_json, getVersionedPath("backersRewards"));
    }
}
