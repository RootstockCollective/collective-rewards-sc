// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { OutputWriter } from "script/script_utils/OutputWriter.s.sol";
import { ChangeExecutor } from "src/mvp/ChangeExecutor.sol";
import { Deploy as ChangeExecutorDeployerRootstockCollective } from "./ChangeExecutorDeployerRootstockCollective.s.sol";
import { SimplifiedRewardDistributor } from "src/mvp/SimplifiedRewardDistributor.sol";
import { Deploy as SimplifiedRewardDistributorRootstockCollectiveDeployer } from "script/mvp/SimplifiedRewardDistributorRootstockCollectiveDeployer.s.sol";

contract MVPDeploy is Broadcaster, OutputWriter {
    address private _governorAddress;
    address private _rewardTokenAddress;
    address private _kycApproverAddress;

    function setUp() public {
        _governorAddress = vm.envAddress("GOVERNOR_ADDRESS");
        _rewardTokenAddress = vm.envAddress("REWARD_TOKEN_ADDRESS");

        outputWriterSetup();
    }

    function run() public {
        (ChangeExecutorRootstockCollective _changeExecutorProxy, ChangeExecutorRootstockCollective _changeExecutorImpl)
        = new ChangeExecutorDeployerRootstockCollective().run(_governorAddress);
        saveWithProxy("ChangeExecutorRootstockCollective", address(_changeExecutorImpl), address(_changeExecutorProxy));

        (
            SimplifiedRewardDistributorRootstockCollective _simplifiedRewardDistributorProxy,
            SimplifiedRewardDistributorRootstockCollective _simplifiedRewardDistributorImpl
        ) = new SimplifiedRewardDistributorRootstockCollectiveDeployer().run(
            address(_changeExecutorProxy), _rewardTokenAddress
        );
        saveWithProxy(
            "SimplifiedRewardDistributorRootstockCollective",
            address(_simplifiedRewardDistributorImpl),
            address(_simplifiedRewardDistributorProxy)
        );
    }
}
