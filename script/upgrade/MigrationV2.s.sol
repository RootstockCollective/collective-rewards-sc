// SPDX-License-Identifier: MIT
// solhint-disable gas-custom-errors
// solhint-disable reason-string
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { MigrationV2 } from "script/upgrade/MigrationV2.sol";

contract Deploy is Broadcaster {
    function run() public returns (MigrationV2 migrationV2_) {
        address _backersManager = vm.envOr("BackersManagerRootstockCollective", address(0));
        if (_backersManager == address(0)) {
            _backersManager = vm.envAddress("BACKERS_MANAGER_ADDRESS");
        }
        migrationV2_ = run(_backersManager);
    }

    function run(address backersManager_) public broadcast returns (MigrationV2 migrationV2_) {
        require(backersManager_ != address(0), "Backers Manager address cannot be empty");

        return new MigrationV2(backersManager_);
    }
}
