// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { ICollectiveRewardsCheck } from "../../src/interfaces/ICollectiveRewardsCheck.sol";

string constant DEFAULT_NAME = "ERC20Mock";
string constant DEFAULT_SYMBOL = "E20M";

contract StakingTokenMock is ERC20 {
    using ERC165Checker for address;

    error STRIFStakedInCollectiveRewardsCanWithdraw(bool canWithdraw);
    error STRIFSupportsERC165(bool _supports);
    error STRIFSupportsICollectiveRewardsCheck(bool _supports);
    error STRIFUnexpectedCanWithdraw(address _checkAddress);

    /// @notice The address of the CollectiveRewards Contract
    address public bimCheck;

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) { }

    function mint(address account_, uint256 amount_) external {
        _mint(account_, amount_);
    }

    function burn(address account_, uint256 amount_) external {
        _burn(account_, amount_);
    }

    //checks CollectiveRewards for stake
    modifier _checkCollectiveRewardsForStake(address staker, uint256 value) {
        if (bimCheck != address(0)) {
            try ICollectiveRewardsCheck(bimCheck).canWithdraw(staker, value) returns (bool canWithdraw) {
                if (!canWithdraw) {
                    revert STRIFStakedInCollectiveRewardsCanWithdraw(false);
                }
            } catch { }
        }
        _;
    }

    // checks that received address has method which can successfully be called
    // before setting it to state
    function setCollectiveRewardsAddress(address bimAddress) public {
        if (!bimAddress.supportsERC165()) {
            revert STRIFSupportsERC165(false);
        }
        if (!bimAddress.supportsInterface(type(ICollectiveRewardsCheck).interfaceId)) {
            revert STRIFSupportsICollectiveRewardsCheck(false);
        }

        try ICollectiveRewardsCheck(bimAddress).canWithdraw(address(0), 1) returns (bool) {
            bimCheck = bimAddress;
        } catch {
            revert STRIFUnexpectedCanWithdraw(bimAddress);
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
