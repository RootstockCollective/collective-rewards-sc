// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { ChangeExecutor } from "../../src/governance/ChangeExecutor.sol";

/**
 * @title ChangeExecutorMock
 *   @dev Test only contract to mock Governor behavior
 */
contract ChangeExecutorMock is ChangeExecutor {
    bool public isAuthorized;

    function isAuthorizedChanger(address changer_) external view override returns (bool) {
        return isAuthorized || _isAuthorizedChanger(changer_);
    }

    function setIsAuthorized(bool isAuthorized_) public {
        isAuthorized = isAuthorized_;
    }
}
