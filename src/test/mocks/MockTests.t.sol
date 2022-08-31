pragma solidity ^0.8.14;

import "ds-test/test.sol";
import {Vm} from "@std/Vm.sol";

import {MockERC20} from "./MockERC20.sol";
import {MockERC721} from "./MockERC721.sol";
import {MockERC1155} from "./MockERC1155.sol";

contract ContractTest is DSTest {
    MockERC20 public token;
    MockERC721 public nft;
    MockERC1155 public multiToken;
    Vm cheats = Vm(HEVM_ADDRESS);
    address immutable god = address(0xdead);

    function setUp() public {
        cheats.startPrank(god);
        token = new MockERC20();
        nft = new MockERC721();
        multiToken = new MockERC1155();
        cheats.stopPrank();
    }

    function testBalances() public {
        // ERC20
        assertEq(token.balanceOf(god), token.INITIAL_SUPPLY());

        // ERC721
        cheats.prank(god);
        nft.mint(god, 0);
        assertEq(nft.balanceOf(god), 1);

        // ERC1155
        assertEq(multiToken.balanceOf(god, 0), 100);
        assertEq(multiToken.balanceOf(god, 1), 50);
        assertEq(multiToken.balanceOf(god, 69), 50);
    }
}
