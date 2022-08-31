// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "@std/console.sol";
import "../mocks/Suicide.sol";

import "@contracts/utils/Channel.sol";
import "@contracts/Basin.sol";

import {Configs} from "../utils/Configs.sol";

import {Errors} from "@contracts/interfaces/Errors.sol";
import {Events} from "@contracts/interfaces/Events.sol";
import {RecipientStatus, ChannelDetails, Status} from "@contracts/lib/StructsAndEnums.sol";

contract BasinTestExtras is DSTest, Configs {
    function setUp() public {
        // /* owner = msg.sender; */
        // owner = payable(msg.sender);
        cheats.prank(owner);
        basin = new Basin();
        _setupApprovals(address(basin), basinTokenBalance);
        createMockRecipientsAndPackages(
            2,
            2,
            10,
            ItemType.ERC20,
            address(token)
        );
    }

    function twoRecipientChannelInit() public {
        cheats.startPrank(organizer);
        uint256 previousId = basin.nextChannelId();
        channelId = basin.createChannel(recipients, packages, organizer);
        assertEq(
            token.balanceOf(address(basin)),
            recipientsLength * tokenAmountPerPackage
        );
        assertEq(channelId, previousId + 1);

        cheats.expectEmit(true, true, false, true);
        emit Basin__ChannelStatusChanged(channelId, Status.Started);
        basin.changeChannelStatus(
            channelId,
            recipients,
            packages,
            Status.Started
        );
        cheats.stopPrank();
        // Not using assert cause Status type
        require(
            basin.getChannelStatus(channelId) == Status.Started,
            "Channel not started."
        );
    }

    function twoRecipientChannelInitWithFee() public {
        cheats.prank(owner);
        basin.toggleFee();
        cheats.startPrank(organizer);
        channelId = basin.createChannel{value: 0.001 ether}(
            recipients,
            packages,
            organizer
        );
        assertEq(
            token.balanceOf(address(basin)),
            recipientsLength * tokenAmountPerPackage
        );

        cheats.expectEmit(true, true, false, true);
        emit Basin__ChannelStatusChanged(channelId, Status.Started);
        basin.changeChannelStatus(
            channelId,
            recipients,
            packages,
            Status.Started
        );
        cheats.stopPrank();
        // Not using assert cause Status type
        require(
            basin.getChannelStatus(channelId) == Status.Started,
            "Channel not started."
        );

        assertEq(basin.feeHoldings(), 0.001 ether);
    }

    function testFeeToggle() public {
        cheats.startPrank(owner);
        assert(!basin.feeEnabled());
        basin.toggleFee();
        assert(basin.feeEnabled());
        cheats.stopPrank();
    }

    function testFailFeeToggle() public {
        assert(!basin.feeEnabled());
        cheats.prank(address(0xd3ad));
        basin.toggleFee();
        assert(basin.feeEnabled());
    }

    function testFeeToggleError() public {
        assert(!basin.feeEnabled());
        cheats.expectRevert("Not the beneficiary of the fee.");
        cheats.prank(address(0xd3ad));
        basin.toggleFee();
        assert(!basin.feeEnabled());
    }

    function testSetProtocolFee() public {
        assertEq(basin.protocolFee(), 0.001 ether);
        cheats.prank(owner);
        cheats.expectEmit(true, true, false, true);
        emit Basin__SetProtocolFee(0.01 ether);
        basin.setProtocolFee(0.01 ether);
        assertEq(basin.protocolFee(), 0.01 ether);
    }

    function testFailSetProtocolFee() public {
        assertEq(basin.protocolFee(), 0.001 ether);
        cheats.prank(address(0xd3ad));
        cheats.expectEmit(true, true, false, true);
        emit Basin__SetProtocolFee(0.01 ether);
        basin.setProtocolFee(0.01 ether);
        assertEq(basin.protocolFee(), 0.01 ether);
    }

    function testSetProtocolFeeError() public {
        assertEq(basin.protocolFee(), 0.001 ether);
        cheats.prank(address(0xd3ad));
        cheats.expectRevert("Not the beneficiary, cannot execute.");
        basin.setProtocolFee(0.01 ether);
        assertEq(basin.protocolFee(), 0.001 ether);
    }

    function testFeeWithdraw() public {
        twoRecipientChannelInitWithFee();
        uint256 balance = address(owner).balance;
        cheats.startPrank(owner);
        basin.withdrawFee();
        assertEq(address(owner).balance, balance + 0.001 ether);
        assertEq(basin.feeHoldings(), 0);
    }

    function testFeeWithdrawNotBeneficiary() public {
        twoRecipientChannelInitWithFee();
        uint256 balance = address(owner).balance;
        cheats.startPrank(address(0xd3ad));
        basin.withdrawFee();
        assertEq(address(owner).balance, balance + 0.001 ether);
        assertEq(basin.feeHoldings(), 0);
        assertEq(address(0xd3ad).balance, 0);
    }

    function testFailHashFunction() public {
        cheats.startPrank(organizer);
        address recipient1 = newRecipient();
        address recipient2 = newRecipient();
        delete recipients;
        recipients.push(recipient1);
        recipients.push(recipient2);
        channelId = basin.createChannel(recipients, packages, organizer);
        (bytes32 h, address c, , , , , ) = basin.channels(channelId);
        assertEq(c, organizer);
        assertEq(ex.exposedHash(channelId, recipients, packages), h);
        delete recipients;
        recipients.push(recipient2);
        recipients.push(recipient1);
        channelId = basin.createChannel(recipients, packages, organizer);
        (bytes32 ha, address co, , , , , ) = basin.channels(channelId);
        assertEq(ha, h);
        cheats.stopPrank();
    }
}
