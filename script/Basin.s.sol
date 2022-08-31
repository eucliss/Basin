// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Script.sol";
import "@std/console.sol";
import "../src/contracts/Basin.sol";

contract DeployBasin is Script {
    function run() external {

        vm.startBroadcast();

        Basin b = new Basin();

        console.log(address(b));


        vm.stopBroadcast();
    }
}