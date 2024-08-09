// SPDX-License-Identifier: UNLICENSED
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
        string memory _deploymentContext = vm.envString("DEPLOYMENT_CONTEXT");
        string memory _deploymentsRootDir = vm.envString("DEPLOYMENTS_DIR");
        _deploymentsDir = string.concat(_root, "/", _deploymentsRootDir, _deploymentContext);
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

        _outJsonFile = string.concat(_deploymentsDir, "/contract_addresses._json");
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
        _deployPath = string.concat(_root, "/broadcast/Deploy.s.sol/", vm.toString(_chainId), "/run-latest._json");
    }

    /// @notice Reads the deployments from disk that were generated
    ///         by the deploy script.
    /// @return An array of deployments.
    function _getDeployments() internal returns (Deployment[] memory) {
        string memory _json = vm.readFile(_outJsonFile);
        string[] memory _cmd = new string[](3);
        _cmd[0] = Executables.BASH;
        _cmd[1] = "-c";
        _cmd[2] = string.concat(Executables.JQ, " 'keys' <<< '", _json, "'");
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

    /// @notice Returns the _json of the deployment transaction given a contract address.
    function _getDeployTransactionByContractAddress(address addr_) internal returns (string memory) {
        string[] memory _cmd = new string[](3);
        _cmd[0] = Executables.BASH;
        _cmd[1] = "-c";
        _cmd[2] = string.concat(
            Executables.JQ,
            " -r '.transactions[] | select(.contractAddress == ",
            "\"",
            vm.toString(addr_),
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

    /// @notice Returns the constructor arguent of a deployment transaction given a transaction _json.
    function _getDeployTransactionConstructorArguments(string memory transaction_) internal returns (string[] memory) {
        string[] memory _cmd = new string[](3);
        _cmd[0] = Executables.BASH;
        _cmd[1] = "-c";
        _cmd[2] = string.concat(Executables.JQ, " -r '.arguments' <<< '", transaction_, "'");
        bytes memory _res = vm.ffi(_cmd);

        string[] memory _args = new string[](0);
        if (keccak256(bytes("null")) != keccak256(_res)) {
            _args = stdJson.readStringArray(string(_res), "");
        }
        return _args;
    }

    /// @notice Removes the semantic versioning from a contract name. The semver will exist if the contract is compiled
    /// more than once with different versions of the compiler.
    function _stripSemver(string memory name_) internal returns (string memory) {
        string[] memory _cmd = new string[](3);
        _cmd[0] = Executables.BASH;
        _cmd[1] = "-c";
        _cmd[2] = string.concat(
            Executables.ECHO, " ", name_, " | ", Executables.SED, " -E 's/[.][0-9]+\\.[0-9]+\\.[0-9]+//g'"
        );
        bytes memory _res = vm.ffi(_cmd);
        return string(_res);
    }

    /// @notice Builds the fully qualified name of a contract. Assumes that the
    ///         file name is the same as the contract name but strips semver for the file name.
    function _getFullyQualifiedName(string memory name_) internal returns (string memory) {
        string memory _sanitized = _stripSemver(name_);
        return string.concat(_sanitized, ".sol:", name_);
    }

    /// @notice Wrapper for vm.getCode that handles semver in the name.
    function _getCode(string memory name_) internal returns (bytes memory) {
        string memory _fqn = _getFullyQualifiedName(name_);
        bytes memory _code = vm.getCode(_fqn);
        return _code;
    }

    /// @notice Wrapper for vm.getDeployedCode that handles semver in the name.
    function _getDeployedCode(string memory name_) internal returns (bytes memory) {
        string memory _fqn = _getFullyQualifiedName(name_);
        bytes memory _code = vm.getDeployedCode(_fqn);
        return _code;
    }

    /// @notice Returns the receipt of a deployment transaction.
    function _getDeployReceiptByContractAddress(address addr_) internal returns (string memory receipt_) {
        string[] memory _cmd = new string[](3);
        _cmd[0] = Executables.BASH;
        _cmd[1] = "-c";
        _cmd[2] = string.concat(
            Executables.JQ,
            " -r '.receipts[] | select(.contractAddress == ",
            "\"",
            vm.toString(addr_),
            "\"",
            ")' < ",
            _deployPath
        );
        bytes memory _res = vm.ffi(_cmd);
        string memory _receipt = string(_res);
        receipt_ = _receipt;
    }

    function _getForgeArtifactDirectory(string memory name_) internal returns (string memory dir_) {
        string[] memory _cmd = new string[](3);
        _cmd[0] = Executables.BASH;
        _cmd[1] = "-c";
        _cmd[2] = string.concat(Executables.FORGE, " config --_json | ", Executables.JQ, " -r .out");
        bytes memory _res = vm.ffi(_cmd);
        string memory _contractName = _stripSemver(name_);
        dir_ = string.concat(vm.projectRoot(), "/", string(_res), "/", _contractName, ".sol");
    }

    /// @notice Returns the filesystem path to the artifact path. If the contract was compiled
    ///         with multiple solidity versions then return the first one based on the result of `LS`.
    function _getForgeArtifactPath(string memory name_) internal returns (string memory) {
        string memory _directory = _getForgeArtifactDirectory(name_);
        string memory _path = string.concat(_directory, "/", name_, "._json");
        if (vm.exists(_path)) return _path;

        string[] memory _cmd = new string[](3);
        _cmd[0] = Executables.BASH;
        _cmd[1] = "-c";
        _cmd[2] = string.concat(
            Executables.LS,
            " -1 --color=never ",
            _directory,
            " | ",
            Executables.JQ,
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

    /// @notice Returns the devdoc for a deployed contract.
    function _getDevDoc(string memory name_) internal returns (string memory doc_) {
        string[] memory _cmd = new string[](3);
        _cmd[0] = Executables.BASH;
        _cmd[1] = "-c";
        _cmd[2] = string.concat(Executables.JQ, " -r '.devdoc' < ", _getForgeArtifactPath(name_));
        bytes memory _res = vm.ffi(_cmd);
        doc_ = string(_res);
    }

    /// @notice Returns the storage layout for a deployed contract.
    function _getStorageLayout(string memory name_) internal returns (string memory layout_) {
        string[] memory _cmd = new string[](3);
        _cmd[0] = Executables.BASH;
        _cmd[1] = "-c";
        _cmd[2] = string.concat(Executables.JQ, " -r '.storageLayout' < ", _getForgeArtifactPath(name_));
        bytes memory _res = vm.ffi(_cmd);
        layout_ = string(_res);
    }

    /// @notice Returns the abi for a deployed contract.
    function getAbi(string memory name_) public returns (string memory abi_) {
        string[] memory _cmd = new string[](3);
        _cmd[0] = Executables.BASH;
        _cmd[1] = "-c";
        _cmd[2] = string.concat(Executables.JQ, " -r '.abi' < ", _getForgeArtifactPath(name_));
        bytes memory _res = vm.ffi(_cmd);
        abi_ = string(_res);
    }

    /// @notice
    function getMethodIdentifiers(string memory name_) public returns (string[] memory ids_) {
        string[] memory _cmd = new string[](3);
        _cmd[0] = Executables.BASH;
        _cmd[1] = "-c";
        _cmd[2] = string.concat(Executables.JQ, " '.methodIdentifiers | keys' < ", _getForgeArtifactPath(name_));
        bytes memory _res = vm.ffi(_cmd);
        ids_ = stdJson.readStringArray(string(_res), "");
    }

    /// @notice Returns the userdoc for a deployed contract.
    function _getUserDoc(string memory name_) internal returns (string memory doc_) {
        string[] memory _cmd = new string[](3);
        _cmd[0] = Executables.BASH;
        _cmd[1] = "-c";
        _cmd[2] = string.concat(Executables.JQ, " -r '.userdoc' < ", _getForgeArtifactPath(name_));
        bytes memory _res = vm.ffi(_cmd);
        doc_ = string(_res);
    }

    /// @notice
    function _getMetadata(string memory name_) internal returns (string memory metadata_) {
        string[] memory _cmd = new string[](3);
        _cmd[0] = Executables.BASH;
        _cmd[1] = "-c";
        _cmd[2] = string.concat(Executables.JQ, " '.metadata | tostring' < ", _getForgeArtifactPath(name_));
        bytes memory _res = vm.ffi(_cmd);
        metadata_ = string(_res);
    }

    /// @notice Turns an Artifact into a _json serialized string
    /// @param artifact_ The artifact to serialize
    /// @return The _json serialized string
    function _serializeArtifact(Artifact memory artifact_) internal returns (string memory) {
        string memory _json = "";
        _json = stdJson.serialize("", "address", artifact_.addr);
        _json = stdJson.serialize("", "abi", artifact_.abi);
        _json = stdJson.serialize("", "args", artifact_.args);
        _json = stdJson.serialize("", "bytecode", artifact_.bytecode);
        _json = stdJson.serialize("", "deployedBytecode", artifact_.deployedBytecode);
        _json = stdJson.serialize("", "devdoc", artifact_.devdoc);
        _json = stdJson.serialize("", "metadata", artifact_.metadata);
        _json = stdJson.serialize("", "numDeployments", artifact_.numDeployments);
        _json = stdJson.serialize("", "receipt", artifact_.receipt);
        _json = stdJson.serialize("", "solcInputHash", artifact_.solcInputHash);
        _json = stdJson.serialize("", "storageLayout", artifact_.storageLayout);
        _json = stdJson.serialize("", "transactionHash", artifact_.transactionHash);
        _json = stdJson.serialize("", "userdoc", artifact_.userdoc);
        return _json;
    }

    /// @notice Call this function to sync the deployment artifacts such that
    ///         hardhat deploy style artifacts are created.
    function createHardhatArtifacts() public {
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

            string[] memory _args = _getDeployTransactionConstructorArguments(_deployTx);
            bytes memory _code = _getCode(_contractName);
            bytes memory _deployedCode = _getDeployedCode(_contractName);
            string memory _receipt = _getDeployReceiptByContractAddress(_addr);

            string memory _artifactPath = string.concat(_deploymentsDir, "/", _deploymentName, "._json");

            uint256 _numDeployments = 0;
            try vm.readFile(_artifactPath) returns (string memory _res) {
                _numDeployments = stdJson.readUint(string(_res), "$.numDeployments");
                vm.removeFile(_artifactPath);
            } catch { }
            _numDeployments++;

            Artifact memory _artifact = Artifact({
                abi: getAbi(_contractName),
                addr: _addr,
                args: _args,
                bytecode: _code,
                deployedBytecode: _deployedCode,
                devdoc: _getDevDoc(_contractName),
                metadata: _getMetadata(_contractName),
                numDeployments: _numDeployments,
                receipt: _receipt,
                solcInputHash: bytes32(0),
                storageLayout: _getStorageLayout(_contractName),
                transactionHash: stdJson.readBytes32(_deployTx, "$.hash"),
                userdoc: _getUserDoc(_contractName)
            });

            string memory _json = _serializeArtifact(_artifact);

            vm.writeJson({ json: _json, path: _artifactPath });
        }

        console.log("Created hard-hat deploy files");
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
