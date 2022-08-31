// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC1155} from "@solmate/tokens/ERC1155.sol";

contract MockERC1155 is ERC1155 {
    constructor() {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 69;

        uint256[] memory amts = new uint256[](2);
        amts[0] = 50;
        amts[1] = 50;
        mint(msg.sender, 0, 100, "");
        batchMint(msg.sender, ids, amts, "");
    }

    function uri(uint256) public pure virtual override returns (string memory) {
        return "TokenURI";
    }

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual {
        _mint(to, id, amount, data);
    }

    function batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual {
        _batchMint(to, ids, amounts, data);
    }

    function burn(
        address from,
        uint256 id,
        uint256 amount
    ) public virtual {
        _burn(from, id, amount);
    }

    function batchBurn(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) public virtual {
        _batchBurn(from, ids, amounts);
    }
}
