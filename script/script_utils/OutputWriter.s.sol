// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// Some code is copied from the
// https://github.com/rsksmart/optimism/blob/develop/packages/contracts-bedrock/scripts/Deployer.sol
// and modified to work for our purposes.

import { Script, console } from "forge-std/src/Script.sol";
import { stdJson } from "forge-std/src/StdJson.sol";

import { Executables } from "script/script_utils/Executables.sol";

/// @notice store the new deployment to be saved
struct Deployment {
    string name;
    address payable addr;
}

/// @notice A `hardhat-deploy` style artifact
struct Artifact {
    string abi;
    address addr;
    string[] args;
    bytes bytecode;
    bytes deployedBytecode;
    string devdoc;
    string metadata;
    uint256 numDeployments;
    string receipt;
    bytes32 solcInputHash;
    string storageLayout;
    bytes32 transactionHash;
    string userdoc;
}

/* solhint-disable no-console */
abstract contract OutputWriter is Script {
    /// @notice The set of deployments that have been done during execution.
    mapping(string name => Deployment deployment) internal _namedDeployments;
    /// @notice The same as `_namedDeployments` but as an array.
    Deployment[] internal _newDeployments;

    /// @notice Error for when attempting to fetch a deployment and it does not exist
    error DeploymentDoesNotExist(string);
    /// @notice Error for when trying to save an invalid deployment
    error InvalidDeployment(string);

    /// @notice The namespace for the deployment. Can be set with the env var DEPLOYMENT_CONTEXT.
    string internal _deploymentContext;
    /// @notice Path to the directory containing the hh deploy style artifacts. Can be overwritten with DEPLOYMENTS_DIR
    /// and DEPLOYMENT_CONTEXT
    string internal _deploymentsDir;
    /// @notice The path to the deployments file
    string internal _outJsonFile;
    /// @notice Path to the deploy artifact generated by foundry
    string internal _deployPath;

    function outputWriterSetup() public {
        string memory _root = vm.projectRoot();
        string memory _envDeploymentContext = vm.envString("DEPLOYMENT_CONTEXT");
        string memory _deploymentsRootDir = vm.envString("DEPLOYMENTS_DIR");
        _deploymentsDir = string.concat(_root, "/", _deploymentsRootDir, _envDeploymentContext);
        try vm.createDir(_deploymentsDir, true) { }
        catch (bytes memory revertMessage) {
            assembly {
                revertMessage := add(revertMessage, 0x04)
            }
            revert(
                string.concat(
                    "Failed to create directory at ",
                    _deploymentsDir,
                    " with message: ",
                    abi.decode(revertMessage, (string))
                )
            );
        }

        _outJsonFile = string.concat(_deploymentsDir, "/contract_addresses.json");
        try vm.readFile(_outJsonFile) returns (string memory) { }
        catch {
            vm.writeJson("{}", _outJsonFile);
        }
        console.log("Storing deployment data in %s", _outJsonFile);

        uint256 _chainId = vm.envOr("CHAIN_ID", block.chainid);
        require(
            _chainId == block.chainid,
            "Please set a CHAIN_ID env var that matches the network set as DEPLOYMENT_CONTEXT"
        );
        _deployPath = string.concat(_root, "/broadcast/Deploy.s.sol/", vm.toString(_chainId), "/run-latest.json");
    }

    /// @notice Reads the deployments from disk that were generated
    ///         by the deploy script.
    /// @return An array of deployments.
    function _getDeployments() internal returns (Deployment[] memory) {
        string memory _json = vm.readFile(_outJsonFile);
        string[] memory _cmd = new string[](3);
        _cmd[0] = Executables._BASH;
        _cmd[1] = "-c";
        _cmd[2] = string.concat(Executables._JQ, " 'keys' <<< '", _json, "'");
        bytes memory _res = vm.ffi(_cmd);
        string[] memory _names = stdJson.readStringArray(string(_res), "");

        Deployment[] memory _deployments = new Deployment[](_names.length);
        for (uint256 i; i < _names.length; i++) {
            string memory _contractName = _names[i];
            address _addr = stdJson.readAddress(_json, string.concat("$.", _contractName));
            _deployments[i] = Deployment({ name: _contractName, addr: payable(_addr) });
        }
        return _deployments;
    }

    /// @notice Returns the json of the deployment transaction given a contract address.
    function _getDeployTransactionByContractAddress(address addr_) internal returns (string memory) {
        string[] memory _cmd = new string[](3);
        _cmd[0] = Executables._BASH;
        _cmd[1] = "-c";
        _cmd[2] = string.concat(
            Executables._JQ,
            " -r '.transactions[] | select(.contractAddress == ",
            "\"",
            vm.toLowercase(vm.toString(addr_)),
            "\"",
            ") | select(.transactionType == \"CREATE\"",
            " or .transactionType == \"CREATE2\"",
            ")' < ",
            _deployPath
        );
        bytes memory _res = vm.ffi(_cmd);
        return string(_res);
    }

    /// @notice Returns the contract name from a deploy transaction.
    function _getContractNameFromDeployTransaction(string memory deployTx_) internal pure returns (string memory) {
        return stdJson.readString(deployTx_, ".contractName");
    }

    /// @notice Removes the semantic versioning from a contract name. The semver will exist if the contract is compiled
    /// more than once with different versions of the compiler.
    function _stripSemver(string memory name_) internal returns (string memory) {
        string[] memory _cmd = new string[](3);
        _cmd[0] = Executables._BASH;
        _cmd[1] = "-c";
        _cmd[2] = string.concat(
            Executables._ECHO, " ", name_, " | ", Executables._SED, " -E 's/[.][0-9]+\\.[0-9]+\\.[0-9]+//g'"
        );
        bytes memory _res = vm.ffi(_cmd);
        return string(_res);
    }

    function _getForgeArtifactDirectory(string memory name_) internal returns (string memory dir_) {
        string[] memory _cmd = new string[](3);
        _cmd[0] = Executables._BASH;
        _cmd[1] = "-c";
        _cmd[2] = string.concat(Executables._FORGE, " config --json | ", Executables._JQ, " -r .out");
        bytes memory _res = vm.ffi(_cmd);
        string memory _contractName = _stripSemver(name_);
        dir_ = string.concat(vm.projectRoot(), "/", string(_res), "/", _contractName, ".sol");
    }

    /// @notice Returns the filesystem path to the artifact path. If the contract was compiled
    ///         with multiple solidity versions then return the first one based on the result of `LS`.
    function _getForgeArtifactPath(string memory name_) internal returns (string memory) {
        string memory _directory = _getForgeArtifactDirectory(name_);
        string memory _path = string.concat(_directory, "/", name_, ".json");
        if (vm.exists(_path)) return _path;

        string[] memory _cmd = new string[](3);
        _cmd[0] = Executables._BASH;
        _cmd[1] = "-c";
        _cmd[2] = string.concat(
            Executables._LS,
            " -1 --color=never ",
            _directory,
            " | ",
            Executables._JQ,
            " -R -s -c 'split(\"\n\") | map(select(length > 0))'"
        );
        bytes memory _res = vm.ffi(_cmd);
        string[] memory _files = stdJson.readStringArray(string(_res), "");
        return string.concat(_directory, "/", _files[0]);
    }

    /// @notice Returns the FORGE artifact given a contract name.
    function _getForgeArtifact(string memory name_) internal returns (string memory) {
        string memory _forgeArtifactPath = _getForgeArtifactPath(name_);
        return vm.readFile(_forgeArtifactPath);
    }

    function _getAbiFile(string memory name_) internal returns (string memory) {
        return string.concat(_getForgeArtifactDirectory(name_), "/", name_, ".abi.json");
    }

    function _copyFile(string memory input_, string memory output_) internal {
        vm.copyFile(input_, output_);
    }

    /// @notice Call this function to copy the ABI files to the deployment folder.
    function copyAbis() public {
        Deployment[] memory _deployments = _getDeployments();
        console.log("Syncing %s deployments", _deployments.length);
        console.log("Using deployment artifact %s", _deployPath);

        for (uint256 i; i < _deployments.length; i++) {
            address _addr = _deployments[i].addr;
            string memory _deploymentName = _deployments[i].name;

            string memory _deployTx = _getDeployTransactionByContractAddress(_addr);
            if (bytes(_deployTx).length == 0) {
                console.log("Deploy Tx not found for %s skipping deployment artifact generation", _deploymentName);
                continue;
            }
            string memory _contractName = _getContractNameFromDeployTransaction(_deployTx);
            console.log("Syncing deployment %s: contract %s", _deploymentName, _contractName);

            string memory _copyInput = _getAbiFile(_contractName);
            string memory _copyOutput = string.concat(_deploymentsDir, "/", _deploymentName, ".abi" ".json");

            _copyFile(_copyInput, _copyOutput);
        }

        console.log("ABI files copied");
    }

    /// @notice Writes a deployment to disk.
    /// @param contractName_ The name of the deployment.
    /// @param deployedAt_ The address of the deployment.
    function save(string memory contractName_, address deployedAt_) public {
        if (bytes(contractName_).length == 0) {
            revert InvalidDeployment("EmptyName");
        }
        if (bytes(_namedDeployments[contractName_].name).length > 0) {
            revert InvalidDeployment("AlreadyExists");
        }

        Deployment memory _deployments = Deployment({ name: contractName_, addr: payable(deployedAt_) });
        _namedDeployments[contractName_] = _deployments;
        _newDeployments.push(_deployments);
        vm.writeJson({ json: stdJson.serialize("", contractName_, deployedAt_), path: _outJsonFile });
    }

    /// @notice Fetches a deployment by name.
    /// @param contractName_ The name of the deployment.
    /// @return The deployment.
    function get(string memory contractName_) public view returns (Deployment memory) {
        Deployment memory _deployment = _namedDeployments[contractName_];
        if (bytes(_deployment.name).length == 0) {
            revert DeploymentDoesNotExist(contractName_);
        }
        return _deployment;
    }

    /// @notice Writes a deployment and the updragable contract address to disk.
    /// @param contractName_ The name of the deployment.
    /// @param deployedAt_ The address of the deployment.
    /// @param proxyAddress_ The address of the proxy contract.
    function saveWithProxy(string memory contractName_, address deployedAt_, address proxyAddress_) public {
        save(contractName_, deployedAt_);
        save(string.concat(contractName_, "Proxy"), proxyAddress_);
    }
}
/* solhint-enable no-console */
