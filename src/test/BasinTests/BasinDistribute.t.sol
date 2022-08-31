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

contract BasinTestDistribution is DSTest, Configs {
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

    // function testFailCallDirectlyPlace() public {
    //     channelId = basin.createChannel(recipients, packages, organizer);
    //     Channel(channelId).pairRecipientAndPackage(
    //         recipients[0],
    //         1,
    //         false
    //     );
    // }

    function testMultiplePackages() public {
        twoRecipientChannelInit();
        uint256 ogRecipient0Balance = token.balanceOf(recipients[0]);
        uint256 ogRecipient1Balance = token.balanceOf(recipients[1]);
        assertEq(token.balanceOf(recipients[0]), ogRecipient0Balance);
        assertEq(token.balanceOf(recipients[1]), ogRecipient1Balance);

        assertEq(
            token.balanceOf(address(basin)),
            tokenAmountPerPackage * recipientsLength
        );

        cheats.expectEmit(true, true, true, true);
        emit Channel__RecipientPlaced(recipients[0], 0);
        cheats.startPrank(organizer);
        basin.distributeToRecipient(
            channelId,
            recipients,
            packages,
            0,
            0,
            false
        );
        assertEq(
            token.balanceOf(recipients[0]),
            ogRecipient0Balance + tokenAmountPerPackage
        );
        assertEq(token.balanceOf(address(basin)), tokenAmountPerPackage);

        cheats.expectEmit(true, true, true, true);
        emit Channel__RecipientPlaced(recipients[1], 1);
        basin.distributeToRecipient(
            channelId,
            recipients,
            packages,
            1,
            1,
            false
        );
        assertEq(
            token.balanceOf(recipients[1]),
            ogRecipient1Balance + tokenAmountPerPackage
        );
        assertEq(token.balanceOf(address(basin)), 0);
    }

    function testDistributeToRecipient() public {
        twoRecipientChannelInit();
        uint32 place = 0;
        uint256 recipientIndex = 0; // recipient1
        assertEq(token.balanceOf(recipients[recipientIndex]), 0);
        assertEq(token.balanceOf(recipients[1]), 0);
        assertEq(
            token.balanceOf(address(basin)),
            tokenAmountPerPackage * recipientsLength
        );

        cheats.startPrank(organizer);

        cheats.expectEmit(true, true, true, true);
        emit Channel__RecipientPlaced(recipients[recipientIndex], place);
        basin.distributeToRecipient(
            channelId,
            recipients,
            packages,
            recipientIndex,
            place,
            false
        );
        assertEq(
            token.balanceOf(recipients[recipientIndex]),
            tokenAmountPerPackage
        );
        assertEq(token.balanceOf(address(basin)), tokenAmountPerPackage);

        recipientIndex = 1; // recipient2
        place = 1;
        cheats.expectEmit(true, true, true, true);
        emit Channel__RecipientPlaced(recipients[recipientIndex], place);
        basin.distributeToRecipient(
            channelId,
            recipients,
            packages,
            1,
            place,
            false
        );
        assertEq(
            token.balanceOf(recipients[recipientIndex]),
            tokenAmountPerPackage
        );
        assertEq(token.balanceOf(address(basin)), 0);
        cheats.stopPrank();
    }

    function testdistributeToRecipientRecipientNotInChannelError() public {
        twoRecipientChannelInit();
        uint32 place = 1;
        cheats.prank(organizer);
        cheats.expectRevert(
            abi.encodeWithSelector(
                Errors.Basin__InvalidRecipientIndex.selector,
                2,
                2
            )
        );
        basin.distributeToRecipient(
            channelId,
            recipients,
            packages,
            2, // length of channel is 2, indexes available=0,1
            place,
            false
        );
    }

    function testdistributeToRecipientInAlreadyUsedPlace() public {
        twoRecipientChannelInit();
        cheats.startPrank(organizer);
        basin.distributeToRecipient(
            channelId,
            recipients,
            packages,
            0,
            0,
            false
        );
        cheats.expectRevert(
            abi.encodeWithSelector(
                ChannelEventsAndErrors
                    .Channel__PackageAlreadyDelivered
                    .selector,
                0
            )
        );
        basin.distributeToRecipient(
            channelId,
            recipients,
            packages,
            1,
            0,
            false
        );
    }

    function testDistributeToRecipientWrongRecipients() public {
        twoRecipientChannelInit();
        generatePackages(1, address(token), 10, ItemType.ERC20);
        cheats.prank(organizer);

        cheats.expectRevert(
            abi.encodeWithSelector(
                Errors.Basin__InvalidChannel__InvalidHash.selector,
                recipients,
                packages,
                ex.exposedHash(channelId, recipients, packages),
                "Channel does not exist, ID is 0."
            )
        );

        basin.distributeToRecipient(
            channelId,
            recipients,
            packages,
            0,
            1,
            false
        );
    }

    function testWrongRecipientSetWithRevert() public {
        twoRecipientChannelInit();
        generateRecipients(4);
        uint32 place = 1;
        cheats.prank(organizer);
        cheats.expectRevert(
            abi.encodeWithSelector(
                Errors.Basin__InvalidChannel__InvalidHash.selector,
                recipients,
                packages,
                ex.exposedHash(channelId, recipients, packages),
                "Channel does not exist, ID is 0."
            )
        );
        basin.distributeToRecipient(
            channelId,
            recipients,
            packages,
            0,
            place,
            false
        );
    }

    function testWrongPlaceSetWithRevert() public {
        twoRecipientChannelInit();
        generatePackages(1, address(token), 10, ItemType.ERC20);
        uint32 place = 1;
        cheats.prank(organizer);
        cheats.expectRevert(
            abi.encodeWithSelector(
                Errors.Basin__InvalidChannel__InvalidHash.selector,
                recipients,
                packages,
                ex.exposedHash(channelId, recipients, packages),
                "Channel does not exist, ID is 0."
            )
        );
        basin.distributeToRecipient(
            channelId,
            recipients,
            packages,
            0,
            place,
            false
        );
    }

    function testWrongPlaceOutOfBounds() public {
        twoRecipientChannelInit();
        uint32 place = 2;
        cheats.expectRevert(
            abi.encodeWithSelector(
                Errors.Basin__InvalidPlaceIndex.selector,
                place,
                packagesLength
            )
        );
        cheats.prank(organizer);
        basin.distributeToRecipient(
            channelId,
            recipients,
            packages,
            0,
            place,
            false
        );
    }

    // Token Deposit function testing

    function testDistributeEth() public {
        createMockRecipientsAndPackages(
            2,
            2,
            1 ether,
            ItemType.NATIVE,
            address(0x0)
        );
        channelId = basin.createChannel{value: twoEthPrize}(
            recipients,
            packages,
            organizer
        );
        cheats.startPrank(organizer);
        basin.changeChannelStatus(
            channelId,
            recipients,
            packages,
            Status.Started
        );
        uint256 holdBalance = address(recipients[0]).balance;
        assertEq(address(recipients[0]).balance, holdBalance);
        basin.distributeToRecipient(
            channelId,
            recipients,
            packages,
            0,
            0,
            false
        );
        assertEq(address(recipients[0]).balance, holdBalance + 1 ether);

        holdBalance = address(recipients[1]).balance;
        assertEq(address(recipients[1]).balance, holdBalance);
        basin.distributeToRecipient(
            channelId,
            recipients,
            packages,
            1,
            1,
            false
        );
        assertEq(address(recipients[1]).balance, holdBalance + 1 ether);

        cheats.stopPrank();
    }

    function testSuicideETHbasin() public {
        Suicide death = new Suicide();
        cheats.deal(organizer, 10 ether);

        createMockRecipientsAndPackages(
            1,
            1,
            1 ether,
            ItemType.NATIVE,
            address(0x0)
        );
        recipients.push(address(death));
        packages.push(
            PackageItem({
                itemType: ItemType.NATIVE,
                token: address(0x0),
                identifier: 0,
                amount: 2 ether
            })
        );

        cheats.startPrank(organizer);

        channelId = basin.createChannel{value: 3 ether}(
            recipients,
            packages,
            organizer
        );
        basin.changeChannelStatus(
            channelId,
            recipients,
            packages,
            Status.Started
        );

        assertEq(recipients[1], address(death));
        assertEq(packages[1].amount, 2 ether);
        assertEq(address(death).balance, 0 ether);

        assertEq(address(organizer).balance, 7 ether);
        assertEq(address(basin).balance, 3 ether);

        // package death
        basin.distributeToRecipient(
            channelId,
            recipients,
            packages,
            1,
            1,
            false
        );

        assertEq(address(death).balance, 0 ether);

        assertEq(address(organizer).balance, 7 ether);
        assertEq(address(basin).balance, 3 ether);
    }

    /*//////////////////////////////////////////////////////////////////////////
                            DELIVER PACKAGES
    //////////////////////////////////////////////////////////////////////////*/

    function testDeliverPackages() public {
        cheats.startPrank(organizer);

        // Set approvals
        multiToken.setApprovalForAll(address(basin), true);
        nft.setApprovalForAll(address(basin), true);
        token.approve(address(basin), 1000);

        generateAllPackageTypesAndRecipients();

        assertEq(packages.length, recipients.length);

        // ETH
        assertEq(address(recipients[0]).balance, 0);
        // ERC20
        assertEq(token.balanceOf(recipients[1]), 0);
        // ERC721
        assertEq(nft.balanceOf(recipients[2]), 0);
        // ERC1155
        assertEq(multiToken.balanceOf(recipients[3], 1), 0);

        // Deliver Packages
        require(
            basin.deliverPackages{value: packages[0].amount}(
                recipients,
                packages
            ),
            "Failed transfer"
        );

        // ETH
        assertEq(address(recipients[0]).balance, packages[0].amount);
        // ERC20
        assertEq(token.balanceOf(recipients[1]), packages[1].amount);
        // ERC721
        assertEq(nft.balanceOf(recipients[2]), packages[2].amount);
        // ERC1155
        assertEq(multiToken.balanceOf(recipients[3], 1), packages[3].amount);
    }

    function testDeliverPackagesMismatchError() public {
        cheats.startPrank(organizer);
        delete packages;
        cheats.expectRevert("Packages and recipients mismatch.");
        basin.deliverPackages(recipients, packages);
    }

    function testDeliverPackagesFailedToSendEth() public {
        cheats.startPrank(organizer);
        generateAllPackageTypesAndRecipients();

        // Deliver Packages
        cheats.expectRevert("Failed to send Ether");
        basin.deliverPackages(recipients, packages);
    }

    function testDeliverPackagesErrorNotEnoughEth() public {
        cheats.startPrank(organizer);
        createMockRecipientsAndPackages(
            2,
            2,
            1 ether,
            ItemType.NATIVE,
            address(0)
        );

        // Deliver Packages
        cheats.expectRevert("Incorrect Eth Deposit amount");
        basin.deliverPackages{value: 2.2 ether}(recipients, packages);
    }
}
