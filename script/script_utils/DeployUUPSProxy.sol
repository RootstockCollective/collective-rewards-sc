// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Script } from "forge-std/src/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

abstract contract DeployUUPSProxy is Script {
    function _deployUUPSProxy(
        string memory contractName_,
        bytes memory initializerData_
    )
        internal
        returns (address proxy_, address implementation_)
    {
        implementation_ = _deployFromBytecode(vm.getCode(contractName_));
        proxy_ = address(new ERC1967Proxy(implementation_, initializerData_));
    }

    function _deployFromBytecode(bytes memory bytecode_) private returns (address) {
        address _addr;
        assembly {
            _addr := create(0, add(bytecode_, 32), mload(bytecode_))
        }
        require(_addr != address(0), "Deployment failed");
        return _addr;
    }

    function _deployUUPSProxyDD(
        string memory contractName_,
        bytes memory initializerData_,
        bytes32 salt_
    )
        internal
        returns (address proxy_, address implementation_)
    {
        implementation_ = _deployFromBytecodeDD(vm.getCode(contractName_), salt_);
        proxy_ = address(new ERC1967Proxy{ salt: salt_ }(implementation_, initializerData_));
    }

    function _deployFromBytecodeDD(bytes memory bytecode_, bytes32 salt_) private returns (address) {
        address _addr;
        assembly {
            _addr := create2(0, add(bytecode_, 32), mload(bytecode_), salt_)
        }
        require(_addr != address(0), "Deployment failed");
        return _addr;
    }
}
