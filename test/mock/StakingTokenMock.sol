// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { ICollectiveRewardsCheckRootstockCollective } from
    "src/interfaces/ICollectiveRewardsCheckRootstockCollective.sol";

string constant DEFAULT_NAME = "ERC20Mock";
string constant DEFAULT_SYMBOL = "E20M";

contract StakingTokenMock is ERC20 {
    using ERC165Checker for address;

    error STRIFStakedInCollectiveRewardsCanWithdraw(bool canWithdraw);
    error STRIFSupportsERC165(bool _supports);
    error STRIFSupportsICollectiveRewardsCheckRootstockCollective(bool _supports);
    error STRIFUnexpectedCanWithdraw(address _checkAddress);

    /// @notice The address of the CollectiveRewards Contract
    address public collectiveRewardsCheck;

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) { }

    function mint(address account_, uint256 amount_) external {
        _mint(account_, amount_);
    }

    function burn(address account_, uint256 amount_) external {
        _burn(account_, amount_);
    }

    //checks CollectiveRewards for stake
    modifier _checkCollectiveRewardsForStake(address staker, uint256 value) {
        _;
        // The check is applied after the fnc modified, so that if there is any revert there, it takes priority
        if (collectiveRewardsCheck != address(0)) {
            try ICollectiveRewardsCheckRootstockCollective(collectiveRewardsCheck).canWithdraw(staker, value) returns (
                bool canWithdraw
            ) {
                if (!canWithdraw) {
                    revert STRIFStakedInCollectiveRewardsCanWithdraw(false);
                }
            } catch { }
        }
    }

    // checks that received address has method which can successfully be called
    // before setting it to state
    function setCollectiveRewardsAddress(address collectiveRewardsAddress) public {
        if (!collectiveRewardsAddress.supportsERC165()) {
            revert STRIFSupportsERC165(false);
        }
        if (!collectiveRewardsAddress.supportsInterface(type(ICollectiveRewardsCheckRootstockCollective).interfaceId)) {
            revert STRIFSupportsICollectiveRewardsCheckRootstockCollective(false);
        }

        try ICollectiveRewardsCheckRootstockCollective(collectiveRewardsAddress).canWithdraw(address(0), 1) returns (
            bool
        ) {
            collectiveRewardsCheck = collectiveRewardsAddress;
        } catch {
            revert STRIFUnexpectedCanWithdraw(collectiveRewardsAddress);
        }
    }

    function _update(
        address from,
        address to,
        uint256 value
    )
        internal
        override
        _checkCollectiveRewardsForStake(from, value)
    {
        super._update(from, to, value);
    }
}
