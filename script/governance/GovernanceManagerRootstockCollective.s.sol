// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { GovernanceManagerRootstockCollective } from "src/governance/GovernanceManagerRootstockCollective.sol";

contract Deploy is Broadcaster {
    function run()
        public
        returns (GovernanceManagerRootstockCollective proxy_, GovernanceManagerRootstockCollective implementation_)
    {
        address _governorAddress = vm.envAddress("GOVERNOR_ADDRESS");
        address _foundationAddress = vm.envAddress("FOUNDATION_TREASURY_ADDRESS");
        address _kycApproverAddress = vm.envAddress("KYC_APPROVER_ADDRESS");
        address _upgrader = vm.envAddress("UPGRADER_ADDRESS");

        (proxy_, implementation_) = run(_governorAddress, _foundationAddress, _kycApproverAddress, _upgrader);
    }

    function run(
        address governor_,
        address foundation_,
        address kycApprover_,
        address upgrader_
    )
        public
        broadcast
        returns (GovernanceManagerRootstockCollective proxy_, GovernanceManagerRootstockCollective implementation_)
    {
        require(governor_ != address(0), "Governor address cannot be empty");
        require(foundation_ != address(0), "Foundation address cannot be empty");
        require(kycApprover_ != address(0), "KYC approver address cannot be empty");
        require(upgrader_ != address(0), "Upgrader address cannot be empty");

        bytes memory _initializerData = abi.encodeWithSignature(
            "initialize(address,address,address,address)", governor_, foundation_, kycApprover_, upgrader_
        );
        address _proxy;
        address _implementation;
        if (vm.envOr("NO_DD", false)) {
            _implementation = address(new GovernanceManagerRootstockCollective());
            _proxy = address(new ERC1967Proxy(_implementation, _initializerData));

            return (GovernanceManagerRootstockCollective(_proxy), GovernanceManagerRootstockCollective(_implementation));
        }

        _implementation = address(new GovernanceManagerRootstockCollective{ salt: _salt }());
        _proxy = address(new ERC1967Proxy{ salt: _salt }(_implementation, _initializerData));

        return (GovernanceManagerRootstockCollective(_proxy), GovernanceManagerRootstockCollective(_implementation));
    }
}
