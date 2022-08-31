pragma solidity ^0.8.14;

import "@std/console.sol";

contract Suicide {
    fallback() external payable {
        selfdestruct(payable(msg.sender));
    }

    receive() external payable {
        selfdestruct(payable(msg.sender));
    }
}
