// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { OutputWriter } from "script/script_utils/OutputWriter.s.sol";
import { ChangeExecutor } from "src/governance/ChangeExecutor.sol";
import { Deploy as ChangeExecutorDeployer } from "script/governance/ChangeExecutor.s.sol";
import { SimplifiedRewardDistributor } from "src/mvp/SimplifiedRewardDistributor.sol";
import { Deploy as SimplifiedRewardDistributorDeployer } from "script/mvp/SimplifiedRewardDistributor.s.sol";

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
        (ChangeExecutor _changeExecutorProxy, ChangeExecutor _changeExecutorImpl) =
            new ChangeExecutorDeployer().run(_governorAddress);
        saveWithProxy("ChangeExecutor", address(_changeExecutorImpl), address(_changeExecutorProxy));

        (
            SimplifiedRewardDistributor _simplifiedRewardDistributorProxy,
            SimplifiedRewardDistributor _simplifiedRewardDistributorImpl
        ) = new SimplifiedRewardDistributorDeployer().run(address(_changeExecutorProxy), _rewardTokenAddress);
        saveWithProxy(
            "SimplifiedRewardDistributor",
            address(_simplifiedRewardDistributorImpl),
            address(_simplifiedRewardDistributorProxy)
        );
    }
}
