// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

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

    function _outputWriterSetup() public {
        string memory root = vm.projectRoot();
        string memory deployementContext = vm.envString("DEPLOYMENT_CONTEXT");
        string memory deploymentsRootDir = vm.envString("DEPLOYMENTS_DIR");
        _deploymentsDir = string.concat(root, "/", deploymentsRootDir, deployementContext);
        try vm.createDir(_deploymentsDir, true) { } catch (bytes memory) { }

        _outJsonFile = string.concat(_deploymentsDir, "/contract_addresses.json");
        try vm.readFile(_outJsonFile) returns (string memory) { }
        catch {
            vm.writeJson("{}", _outJsonFile);
        }
        console.log("Storing deployment data in %s", _outJsonFile);

        uint256 chainId = vm.envOr("CHAIN_ID", block.chainid);
        _deployPath = string.concat(root, "/broadcast/Deploy.s.sol/", vm.toString(chainId), "/run-latest.json");
    }

    /// @notice Reads the deployments from disk that were generated
    ///         by the deploy script.
    /// @return An array of deployments.
    function _getDeployments() internal returns (Deployment[] memory) {
        string memory json = vm.readFile(_outJsonFile);
        string[] memory cmd = new string[](3);
        cmd[0] = Executables.BASH;
        cmd[1] = "-c";
        cmd[2] = string.concat(Executables.JQ, " 'keys' <<< '", json, "'");
        bytes memory res = vm.ffi(cmd);
        string[] memory names = stdJson.readStringArray(string(res), "");

        Deployment[] memory deployments = new Deployment[](names.length);
        for (uint256 i; i < names.length; i++) {
            string memory contractName = names[i];
            address addr = stdJson.readAddress(json, string.concat("$.", contractName));
            deployments[i] = Deployment({ name: contractName, addr: payable(addr) });
        }
        return deployments;
    }

    /// @notice Returns the json of the deployment transaction given a contract address.
    function _getDeployTransactionByContractAddress(address _addr) internal returns (string memory) {
        string[] memory cmd = new string[](3);
        cmd[0] = Executables.BASH;
        cmd[1] = "-c";
        cmd[2] = string.concat(
            Executables.JQ,
            " -r '.transactions[] | select(.contractAddress == ",
            "\"",
            vm.toString(_addr),
            "\"",
            ") | select(.transactionType == \"CREATE\"",
            " or .transactionType == \"CREATE2\"",
            ")' < ",
            _deployPath
        );
        bytes memory res = vm.ffi(cmd);
        return string(res);
    }

    /// @notice Returns the contract name from a deploy transaction.
    function _getContractNameFromDeployTransaction(string memory _deployTx) internal pure returns (string memory) {
        return stdJson.readString(_deployTx, ".contractName");
    }

    /// @notice Returns the constructor arguent of a deployment transaction given a transaction json.
    function getDeployTransactionConstructorArguments(string memory _transaction) internal returns (string[] memory) {
        string[] memory cmd = new string[](3);
        cmd[0] = Executables.BASH;
        cmd[1] = "-c";
        cmd[2] = string.concat(Executables.JQ, " -r '.arguments' <<< '", _transaction, "'");
        bytes memory res = vm.ffi(cmd);

        string[] memory args = new string[](0);
        if (keccak256(bytes("null")) != keccak256(res)) {
            args = stdJson.readStringArray(string(res), "");
        }
        return args;
    }

    /// @notice Removes the semantic versioning from a contract name. The semver will exist if the contract is compiled
    /// more than once with different versions of the compiler.
    function _stripSemver(string memory _name) internal returns (string memory) {
        string[] memory cmd = new string[](3);
        cmd[0] = Executables.BASH;
        cmd[1] = "-c";
        cmd[2] = string.concat(
            Executables.ECHO, " ", _name, " | ", Executables.SED, " -E 's/[.][0-9]+\\.[0-9]+\\.[0-9]+//g'"
        );
        bytes memory res = vm.ffi(cmd);
        return string(res);
    }

    /// @notice Builds the fully qualified name of a contract. Assumes that the
    ///         file name is the same as the contract name but strips semver for the file name.
    function _getFullyQualifiedName(string memory _name) internal returns (string memory) {
        string memory sanitized = _stripSemver(_name);
        return string.concat(sanitized, ".sol:", _name);
    }

    /// @notice Wrapper for vm.getCode that handles semver in the name.
    function _getCode(string memory _name) internal returns (bytes memory) {
        string memory fqn = _getFullyQualifiedName(_name);
        bytes memory code = vm.getCode(fqn);
        return code;
    }

    /// @notice Wrapper for vm.getDeployedCode that handles semver in the name.
    function _getDeployedCode(string memory _name) internal returns (bytes memory) {
        string memory fqn = _getFullyQualifiedName(_name);
        bytes memory code = vm.getDeployedCode(fqn);
        return code;
    }

    /// @notice Returns the receipt of a deployment transaction.
    function _getDeployReceiptByContractAddress(address _addr) internal returns (string memory receipt_) {
        string[] memory cmd = new string[](3);
        cmd[0] = Executables.BASH;
        cmd[1] = "-c";
        cmd[2] = string.concat(
            Executables.JQ,
            " -r '.receipts[] | select(.contractAddress == ",
            "\"",
            vm.toString(_addr),
            "\"",
            ")' < ",
            _deployPath
        );
        bytes memory res = vm.ffi(cmd);
        string memory receipt = string(res);
        receipt_ = receipt;
    }

    function _getForgeArtifactDirectory(string memory _name) internal returns (string memory dir_) {
        string[] memory cmd = new string[](3);
        cmd[0] = Executables.BASH;
        cmd[1] = "-c";
        cmd[2] = string.concat(Executables.FORGE, " config --json | ", Executables.JQ, " -r .out");
        bytes memory res = vm.ffi(cmd);
        string memory contractName = _stripSemver(_name);
        dir_ = string.concat(vm.projectRoot(), "/", string(res), "/", contractName, ".sol");
    }

    /// @notice Returns the filesystem path to the artifact path. If the contract was compiled
    ///         with multiple solidity versions then return the first one based on the result of `LS`.
    function _getForgeArtifactPath(string memory _name) internal returns (string memory) {
        string memory directory = _getForgeArtifactDirectory(_name);
        string memory path = string.concat(directory, "/", _name, ".json");
        if (vm.exists(path)) return path;

        string[] memory cmd = new string[](3);
        cmd[0] = Executables.BASH;
        cmd[1] = "-c";
        cmd[2] = string.concat(
            Executables.LS,
            " -1 --color=never ",
            directory,
            " | ",
            Executables.JQ,
            " -R -s -c 'split(\"\n\") | map(select(length > 0))'"
        );
        bytes memory res = vm.ffi(cmd);
        string[] memory files = stdJson.readStringArray(string(res), "");
        return string.concat(directory, "/", files[0]);
    }

    /// @notice Returns the FORGE artifact given a contract name.
    function _getForgeArtifact(string memory _name) internal returns (string memory) {
        string memory forgeArtifactPath = _getForgeArtifactPath(_name);
        return vm.readFile(forgeArtifactPath);
    }

    /// @notice Returns the devdoc for a deployed contract.
    function getDevDoc(string memory _name) internal returns (string memory doc_) {
        string[] memory cmd = new string[](3);
        cmd[0] = Executables.BASH;
        cmd[1] = "-c";
        cmd[2] = string.concat(Executables.JQ, " -r '.devdoc' < ", _getForgeArtifactPath(_name));
        bytes memory res = vm.ffi(cmd);
        doc_ = string(res);
    }

    /// @notice Returns the storage layout for a deployed contract.
    function getStorageLayout(string memory _name) internal returns (string memory layout_) {
        string[] memory cmd = new string[](3);
        cmd[0] = Executables.BASH;
        cmd[1] = "-c";
        cmd[2] = string.concat(Executables.JQ, " -r '.storageLayout' < ", _getForgeArtifactPath(_name));
        bytes memory res = vm.ffi(cmd);
        layout_ = string(res);
    }

    /// @notice Returns the abi for a deployed contract.
    function getAbi(string memory _name) public returns (string memory abi_) {
        string[] memory cmd = new string[](3);
        cmd[0] = Executables.BASH;
        cmd[1] = "-c";
        cmd[2] = string.concat(Executables.JQ, " -r '.abi' < ", _getForgeArtifactPath(_name));
        bytes memory res = vm.ffi(cmd);
        abi_ = string(res);
    }

    /// @notice
    function getMethodIdentifiers(string memory _name) public returns (string[] memory ids_) {
        string[] memory cmd = new string[](3);
        cmd[0] = Executables.BASH;
        cmd[1] = "-c";
        cmd[2] = string.concat(Executables.JQ, " '.methodIdentifiers | keys' < ", _getForgeArtifactPath(_name));
        bytes memory res = vm.ffi(cmd);
        ids_ = stdJson.readStringArray(string(res), "");
    }

    /// @notice Returns the userdoc for a deployed contract.
    function getUserDoc(string memory _name) internal returns (string memory doc_) {
        string[] memory cmd = new string[](3);
        cmd[0] = Executables.BASH;
        cmd[1] = "-c";
        cmd[2] = string.concat(Executables.JQ, " -r '.userdoc' < ", _getForgeArtifactPath(_name));
        bytes memory res = vm.ffi(cmd);
        doc_ = string(res);
    }

    /// @notice
    function getMetadata(string memory _name) internal returns (string memory metadata_) {
        string[] memory cmd = new string[](3);
        cmd[0] = Executables.BASH;
        cmd[1] = "-c";
        cmd[2] = string.concat(Executables.JQ, " '.metadata | tostring' < ", _getForgeArtifactPath(_name));
        bytes memory res = vm.ffi(cmd);
        metadata_ = string(res);
    }

    /// @notice Turns an Artifact into a json serialized string
    /// @param _artifact The artifact to serialize
    /// @return The json serialized string
    function _serializeArtifact(Artifact memory _artifact) internal returns (string memory) {
        string memory json = "";
        json = stdJson.serialize("", "address", _artifact.addr);
        json = stdJson.serialize("", "abi", _artifact.abi);
        json = stdJson.serialize("", "args", _artifact.args);
        json = stdJson.serialize("", "bytecode", _artifact.bytecode);
        json = stdJson.serialize("", "deployedBytecode", _artifact.deployedBytecode);
        json = stdJson.serialize("", "devdoc", _artifact.devdoc);
        json = stdJson.serialize("", "metadata", _artifact.metadata);
        json = stdJson.serialize("", "numDeployments", _artifact.numDeployments);
        json = stdJson.serialize("", "receipt", _artifact.receipt);
        json = stdJson.serialize("", "solcInputHash", _artifact.solcInputHash);
        json = stdJson.serialize("", "storageLayout", _artifact.storageLayout);
        json = stdJson.serialize("", "transactionHash", _artifact.transactionHash);
        json = stdJson.serialize("", "userdoc", _artifact.userdoc);
        return json;
    }

    /// @notice Call this function to sync the deployment artifacts such that
    ///         hardhat deploy style artifacts are created.
    function createHardhatArtifacts() public {
        Deployment[] memory deployments = _getDeployments();
        console.log("Syncing %s deployments", deployments.length);
        console.log("Using deployment artifact %s", _deployPath);

        for (uint256 i; i < deployments.length; i++) {
            address addr = deployments[i].addr;
            string memory deploymentName = deployments[i].name;

            string memory deployTx = _getDeployTransactionByContractAddress(addr);
            if (bytes(deployTx).length == 0) {
                console.log("Deploy Tx not found for %s skipping deployment artifact generation", deploymentName);
                continue;
            }
            string memory contractName = _getContractNameFromDeployTransaction(deployTx);
            console.log("Syncing deployment %s: contract %s", deploymentName, contractName);

            string[] memory args = getDeployTransactionConstructorArguments(deployTx);
            bytes memory code = _getCode(contractName);
            bytes memory deployedCode = _getDeployedCode(contractName);
            string memory receipt = _getDeployReceiptByContractAddress(addr);

            string memory artifactPath = string.concat(_deploymentsDir, "/", deploymentName, ".json");

            uint256 numDeployments = 0;
            try vm.readFile(artifactPath) returns (string memory res) {
                numDeployments = stdJson.readUint(string(res), "$.numDeployments");
                vm.removeFile(artifactPath);
            } catch { }
            numDeployments++;

            Artifact memory artifact = Artifact({
                abi: getAbi(contractName),
                addr: addr,
                args: args,
                bytecode: code,
                deployedBytecode: deployedCode,
                devdoc: getDevDoc(contractName),
                metadata: getMetadata(contractName),
                numDeployments: numDeployments,
                receipt: receipt,
                solcInputHash: bytes32(0),
                storageLayout: getStorageLayout(contractName),
                transactionHash: stdJson.readBytes32(deployTx, "$.hash"),
                userdoc: getUserDoc(contractName)
            });

            string memory json = _serializeArtifact(artifact);

            vm.writeJson({ json: json, path: artifactPath });
        }

        console.log("Created hard-hat deploy files");
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
        vm.writeJson({ json: stdJson.serialize("", contractName, deployedAt), path: _outJsonFile });
    }
}
