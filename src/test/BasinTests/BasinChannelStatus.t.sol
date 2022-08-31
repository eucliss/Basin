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

contract BasinTestStatus is DSTest, Configs {
    function setUp() public {
        // /* owner = msg.sender; */
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
        channelId = basin.createChannel(recipients, packages, organizer);
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
    }

    function testCancelChannel() public {
        createMockRecipientsAndPackages(2, 2, 1, ItemType.ERC721, address(nft));
        assertEq(ERC721(nft).balanceOf(organizer), nftMintedTotal);
        cheats.startPrank(organizer);
        nft.setApprovalForAll(address(basin), true);
        channelId = basin.createChannel(recipients, packages, organizer);

        assertEq(ERC721(nft).balanceOf(organizer), nftMintedTotal - 2);
        assertEq(ERC721(nft).balanceOf(address(basin)), 2);

        basin.cancelChannel(channelId, recipients, packages);

        assertEq(ERC721(nft).balanceOf(organizer), nftMintedTotal);
        assertEq(ERC721(nft).balanceOf(address(basin)), 0);
    }

    function testCancelChannelErrorStatus() public {
        createMockRecipientsAndPackages(2, 2, 1, ItemType.ERC721, address(nft));
        assertEq(ERC721(nft).balanceOf(organizer), nftMintedTotal);
        cheats.startPrank(organizer);
        nft.setApprovalForAll(address(basin), true);

        channelId = basin.createChannel(recipients, packages, organizer);
        basin.changeChannelStatus(
            channelId,
            recipients,
            packages,
            Status.Started
        );

        assertEq(ERC721(nft).balanceOf(organizer), nftMintedTotal - 2);
        assertEq(ERC721(nft).balanceOf(address(basin)), 2);

        cheats.expectRevert("Channel is not open, cannot cancel.");
        basin.cancelChannel(channelId, recipients, packages);
    }

    // function testFailCallDirectlyStart() public {
    //     channelId = basin.createChannel(recipients, packages, organizer);
    //     Channel(channelId).changeStatus(Status.Started);
    // }

    function testChannelStart() public {
        cheats.startPrank(organizer);
        channelId = basin.createChannel(recipients, packages, organizer);
        cheats.expectEmit(true, true, true, true);
        emit Basin__ChannelStatusChanged(channelId, Status.Started);
        basin.changeChannelStatus(
            channelId,
            recipients,
            packages,
            Status.Started
        );
        require(
            basin.getChannelStatus(channelId) == Status.Started,
            "Channel not started."
        );
        cheats.stopPrank();
    }

    function testChannelStartErrorNotController() public {
        cheats.prank(organizer);
        channelId = basin.createChannel(recipients, packages, organizer);
        cheats.prank(god);
        cheats.expectRevert(
            abi.encodeWithSelector(
                Errors.Basin__UnauthorizedChannelController.selector,
                god
            )
        );
        basin.changeChannelStatus(
            channelId,
            recipients,
            packages,
            Status.Started
        );
    }

    function testChannelCompleteErrorNoDistributes() public {
        cheats.startPrank(organizer);
        channelId = basin.createChannel(recipients, packages, organizer);
        cheats.expectRevert("Channel is not started.");
        basin.changeChannelStatus(
            channelId,
            recipients,
            packages,
            Status.Completed
        );
    }

    function testChannelSetToOpenError() public {
        cheats.startPrank(organizer);
        channelId = basin.createChannel(recipients, packages, organizer);
        cheats.expectRevert(
            abi.encodeWithSelector(
                ChannelEventsAndErrors.Channel__StatusCannotBeSetToOpen.selector
            )
        );
        basin.changeChannelStatus(channelId, recipients, packages, Status.Open);
    }

    function testChannelCompletedFromStarted() public {
        cheats.startPrank(organizer);
        channelId = basin.createChannel(recipients, packages, organizer);
        basin.changeChannelStatus(
            channelId,
            recipients,
            packages,
            Status.Started
        );
        cheats.expectRevert("Not all packages delivered.");
        basin.changeChannelStatus(
            channelId,
            recipients,
            packages,
            Status.Completed
        );
    }

    function testChannelComplete() public {
        assertEq(token.balanceOf(recipients[0]), 0);
        assertEq(token.balanceOf(recipients[1]), 0);

        cheats.startPrank(organizer);
        channelId = basin.createChannel(recipients, packages, organizer);

        assertEq(
            token.balanceOf(address(basin)),
            tokenAmountPerPackage * recipientsLength
        );

        cheats.expectEmit(true, true, true, true);
        emit Basin__ChannelStatusChanged(channelId, Status.Started);
        basin.changeChannelStatus(
            channelId,
            recipients,
            packages,
            Status.Started
        );
        require(
            basin.getChannelStatus(channelId) == Status.Started,
            "Channel not started."
        );

        // Eliminate both the recipients from the channel
        basin.distributeToRecipient(
            channelId,
            recipients,
            packages,
            0,
            0,
            false
        );
        basin.distributeToRecipient(
            channelId,
            recipients,
            packages,
            1,
            1,
            false
        );

        basin.changeChannelStatus(
            channelId,
            recipients,
            packages,
            Status.Completed
        );
        require(
            basin.getChannelStatus(channelId) == Status.Completed,
            "Channel not completed."
        );

        assertEq(token.balanceOf(recipients[0]), tokenAmountPerPackage);
        assertEq(token.balanceOf(recipients[1]), tokenAmountPerPackage);
        assertEq(token.balanceOf(address(basin)), 0);

        cheats.stopPrank();
    }
}
