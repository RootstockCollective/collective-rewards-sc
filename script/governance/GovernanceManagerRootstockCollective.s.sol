// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { GovernanceManagerRootstockCollective } from "src/governance/GovernanceManagerRootstockCollective.sol";

contract Deploy is Broadcaster {
    function run()
        public
        returns (GovernanceManagerRootstockCollective proxy_, GovernanceManagerRootstockCollective implementation_)
    {
        address _governorAddress = vm.envAddress("GOVERNOR_ADDRESS");
        address _treasuryAddress = vm.envAddress("FOUNDATION_TREASURY_ADDRESS");
        address _kycApproverAddress = vm.envAddress("KYC_APPROVER_ADDRESS");

        (proxy_, implementation_) = run(_governorAddress, _treasuryAddress, _kycApproverAddress);
    }

    function run(
        address governor_,
        address treasury_,
        address kycApprover_
    )
        public
        broadcast
        returns (GovernanceManagerRootstockCollective proxy_, GovernanceManagerRootstockCollective implementation_)
    {
        require(governor_ != address(0), "Governor address cannot be empty");
        require(treasury_ != address(0), "Treasury address cannot be empty");
        require(kycApprover_ != address(0), "KYC approver address cannot be empty");

        bytes memory _initializerData =
            abi.encodeWithSignature("initialize(address,address,address)", governor_, treasury_, kycApprover_);
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
