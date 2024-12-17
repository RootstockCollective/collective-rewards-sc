// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

string constant DEFAULT_NAME = "BoosterMock";
string constant DEFAULT_SYMBOL = "BM";

contract BoosterMock is ERC721 {
    constructor() ERC721(DEFAULT_NAME, DEFAULT_SYMBOL) { }

    function mint(address to, uint256 tokenId) external {
        return _mint(to, tokenId);
    }
}
