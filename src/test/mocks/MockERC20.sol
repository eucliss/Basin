// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC20} from "@solmate/tokens/ERC20.sol";

contract MockERC20 is ERC20 {
    uint256 public constant INITIAL_SUPPLY = 1000000000000000000000000;
    uint8 public constant DECIMALS = 18;

    constructor() ERC20("MockERC20", "M20", DECIMALS) {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    function mint(address to, uint256 value) public virtual {
        _mint(to, value);
    }

    function burn(address from, uint256 value) public virtual {
        _burn(from, value);
    }
}
