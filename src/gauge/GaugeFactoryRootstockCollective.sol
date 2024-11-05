// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { GaugeRootstockCollective } from "./GaugeRootstockCollective.sol";

contract GaugeFactoryRootstockCollective {
    /// @notice address of beacon contract who stores gauge implementation address which is where gauge proxies will
    /// delegate all function calls
    address public immutable beacon;
    /// @notice address of the token rewarded to builder and voters
    address public immutable rewardToken;

    /**
     * @notice constructor
     * @param beacon_ address of the beacon
     * @param rewardToken_ address of the token rewarded to builder and voters
     */
    constructor(address beacon_, address rewardToken_) {
        beacon = beacon_;
        rewardToken = rewardToken_;
    }

    function createGauge() external returns (GaugeRootstockCollective gauge_) {
        bytes memory _initializerData = abi.encodeCall(GaugeRootstockCollective.initialize, (rewardToken, msg.sender));
        gauge_ = GaugeRootstockCollective(address(new BeaconProxy(beacon, _initializerData)));
    }
}
