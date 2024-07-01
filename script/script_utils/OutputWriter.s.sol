// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script, console } from "forge-std/src/Script.sol";
import { stdJson } from "forge-std/src/StdJson.sol";

/// @notice store the new deployment to be saved
struct Deployment {
    string name;
    address payable addr;
}

abstract contract OutputWriter is Script {
    /// @notice The set of deployments that have been done during execution.
    mapping(string => Deployment) internal _namedDeployments;
    /// @notice The same as `_namedDeployments` but as an array.
    Deployment[] internal _newDeployments;
    /// @notice Error for when attempting to fetch a deployment and it does not exist

    error DeploymentDoesNotExist(string);
    /// @notice Error for when trying to save an invalid deployment
    error InvalidDeployment(string);

    /// @notice The namespace for the deployment. Can be set with the env var DEPLOYMENT_CONTEXT.
    string deploymentContext;
    /// @notice Path to the directory containing the hh deploy style artifacts. Can be overwritten with DEPLOYMENTS_DIR
    /// and DEPLOYMENT_CONTEXT
    string internal deploymentsDir;
    /// @notice The path to the deployments file
    string internal outJsonFile;

    function setUp() public {
        string memory root = vm.projectRoot();
        string memory deployementContext = vm.envString("DEPLOYMENT_CONTEXT");
        string memory deploymentsRootDir = vm.envString("DEPLOYMENTS_DIR");
        deploymentsDir = string.concat(root, "/", deploymentsRootDir, deployementContext);
        try vm.createDir(deploymentsDir, true) { } catch (bytes memory) { }

        outJsonFile = string.concat(deploymentsDir, "/contract_addresses.json");
        try vm.readFile(outJsonFile) returns (string memory) { }
        catch {
            vm.writeJson("{}", outJsonFile);
        }
        console.log("Storing deployment data in %s", outJsonFile);
    }

    /// @notice Writes a deployment to disk as a temp deployment so that the
    ///         hardhat deploy artifact can be generated afterwards.
    /// @param contractName The name of the deployment.
    /// @param deployedAt The address of the deployment.
    function save(string memory contractName, address deployedAt) public {
        if (bytes(contractName).length == 0) {
            revert InvalidDeployment("EmptyName");
        }
        if (bytes(_namedDeployments[contractName].name).length > 0) {
            revert InvalidDeployment("AlreadyExists");
        }

        Deployment memory deployment = Deployment({ name: contractName, addr: payable(deployedAt) });
        _namedDeployments[contractName] = deployment;
        _newDeployments.push(deployment);
        vm.writeJson({ json: stdJson.serialize("", contractName, deployedAt), path: outJsonFile });
    }
}
