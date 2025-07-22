// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { GaugeRootstockCollective } from "./GaugeRootstockCollective.sol";

contract GaugeFactoryRootstockCollective {
    /// @notice address of beacon contract who stores gauge implementation address which is where gauge proxies will
    /// delegate all function calls
    address public immutable beacon;
    /// @notice address of rif token rewarded to builder and backers
    address public immutable rifToken;
    /// @notice address of usdRif token rewarded to builder and backers
    address public immutable usdrifToken;

    /**
     * @notice constructor
     * @param beacon_ address of the beacon
     * @param rifToken_ address of the token rewarded to builder and voters
     * @param usdrifToken_ address of the token rewarded to builder and voters
     */
    constructor(address beacon_, address rifToken_, address usdrifToken_) {
        beacon = beacon_;
        rifToken = rifToken_;
        usdrifToken = usdrifToken_;
    }

    function createGauge() external returns (GaugeRootstockCollective gauge_) {
        bytes memory _initializerData =
            abi.encodeCall(GaugeRootstockCollective.initialize, (rifToken, usdrifToken, msg.sender));
        gauge_ = GaugeRootstockCollective(address(new BeaconProxy(beacon, _initializerData)));
    }
}
