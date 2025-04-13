// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

string constant DEFAULT_NAME = "ERC20Mock";
string constant DEFAULT_SYMBOL = "E20M";

contract ERC20Mock is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) { }

    function mint(address account_, uint256 amount_) external {
        _mint(account_, amount_);
    }

    function burn(address account_, uint256 amount_) external {
        _burn(account_, amount_);
    }

    function approve(address spender, uint256 value) public override returns (bool) {
        // Prevent potential race condition (optional but safer. Used in legacy erc20 tokens)
        if (value != 0 && allowance(msg.sender, spender) != 0) {
            return false;
        }
        _approve(msg.sender, spender, value);
        emit Approval(msg.sender, spender, value);
        return true;
    }
}
