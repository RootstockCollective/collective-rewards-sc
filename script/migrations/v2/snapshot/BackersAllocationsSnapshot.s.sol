// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

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
        string memory _json;

        // Load backers from file
        string memory _backersList = vm.readFile(getPath("backersList"));
        address[] memory _backers = abi.decode(vm.parseJson(_backersList), (address[]));

        // Fetch all gauges
        uint256 _gaugesLength = builderRegistry.getGaugesLength();
        address[] memory _gauges = new address[](_gaugesLength);
        for (uint256 i = 0; i < _gaugesLength; i++) {
            _gauges[i] = builderRegistry.getGaugeAt(i);
        }

        // Serialize backers and gauges
        _json = vm.serializeAddress("backersData", "allBackers", _backers);
        _json = vm.serializeAddress("backersData", "allGauges", _gauges);

        // Iterate over backers to get allocations
        for (uint256 i = 0; i < _backers.length; i++) {
            address _backer = _backers[i];

            // Fetch total allocation
            uint256 _totalAllocation = backersManager.backerTotalAllocation(_backer);
            string memory _backerJson = vm.serializeUint("backer", "totalAllocation", _totalAllocation);

            // Serialize each gauge allocation
            for (uint256 j = 0; j < _gaugesLength; j++) {
                address _gauge = _gauges[j];
                uint256 _allocation = GaugeRootstockCollective(_gauge).allocationOf(_backer);

                _backerJson = vm.serializeUint("backer", toString(_gauge), _allocation);
            }

            _json = vm.serializeString("backersData", toString(_backer), _backerJson);
        }

        // Write JSON to file
        vm.writeJson(_json, getVersionedPath("backersAllocations"));
    }
}
