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
import {ChannelEventsAndErrors} from "@contracts/interfaces/ChannelEventsAndErrors.sol";

import {RecipientStatus, ChannelDetails, Status} from "@contracts/lib/StructsAndEnums.sol";

contract BasinTest is DSTest, Configs {
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

    function testCreateMainChannel() public {
        cheats.prank(organizer);
        channelId = basin.createChannel(recipients, packages, organizer);
        assertEq(
            token.balanceOf(address(basin)),
            recipientsLength * tokenAmountPerPackage
        );
        (bytes32 h, address c, , , , , ) = basin.channels(channelId);
        assertEq(c, organizer);
        assertEq(ex.exposedHash(channelId, recipients, packages), h);
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

    function testCreateMainChannelErrorThrow() public {
        cheats.expectRevert(
            abi.encodeWithSelector(
                Errors.Basin__InvalidChannel__TooFewRecipients.selector,
                0
            )
        );
        createMockRecipientsAndPackages(
            0,
            2,
            0,
            ItemType.ERC20,
            address(token)
        );
        channelId = basin.createChannel(recipients, packages, organizer);
    }

    function testCreateMainChannelFour() public {
        // Adding 0 for distributorFee for equality check on prizepool
        createMockRecipientsAndPackages(
            4,
            4,
            10,
            ItemType.ERC20,
            address(token)
        );
        cheats.prank(organizer);
        channelId = basin.createChannel(recipients, packages, organizer);
        assertEq(
            token.balanceOf(address(basin)),
            packagesLength * tokenAmountPerPackage
        );

        (, address c, , , , , ) = basin.channels(channelId);
        assertEq(c, organizer);
    }

    function testCreate255Channel() public {
        // Adding 0 for distributorFee for equality check on prizepool
        createMockRecipientsAndPackages(
            255,
            255,
            10,
            ItemType.ERC20,
            address(token)
        );
        cheats.prank(organizer);
        channelId = basin.createChannel(recipients, packages, organizer);
        assertEq(
            token.balanceOf(address(basin)),
            packagesLength * tokenAmountPerPackage
        );

        (, address c, , , , , ) = basin.channels(channelId);
        assertEq(c, organizer);
    }

    function testCreateMainChannelSeventeen() public {
        // Adding 0 for distributorFee for equality check on prizepool
        createMockRecipientsAndPackages(
            17,
            17,
            10,
            ItemType.ERC20,
            address(token)
        );
        cheats.prank(organizer);
        channelId = basin.createChannel(recipients, packages, organizer);
        assertEq(
            token.balanceOf(address(basin)),
            recipientsLength * tokenAmountPerPackage
        );
        (, address c, , , , , ) = basin.channels(channelId);
        require(c != address(0x0), "Not zero address");
        assertEq(c, organizer);
    }

    // function testFailCallInitDirectly() public {
    //     channelId = basin.createChannel(recipients, packages, organizer);
    //     Channel(channelId).init(recipients);
    // }

    // function testFailCallDirectlyStart() public {
    //     channelId = basin.createChannel(recipients, packages, organizer);
    //     basin.changeChannelStatus(channelId, recipients, )
    //     Channel(channelId).changeStatus(Status.Started);
    // }

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

    function testFaildistributeToRecipientRecipientNotInChannel() public {
        twoRecipientChannelInit();
        uint32 place = 1;
        cheats.prank(organizer);
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

    function testFaildistributeToRecipientWrongRecipients() public {
        twoRecipientChannelInit();
        generatePackages(1, address(token), 10, ItemType.ERC20);
        cheats.prank(organizer);
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

    // Token Deposit function testing

    function testDepositEth() public {
        createMockRecipientsAndPackages(
            2,
            2,
            1 ether,
            ItemType.NATIVE,
            address(0x0)
        );
        basin.createChannel{value: twoEthPrize}(
            recipients,
            packages,
            organizer
        );
        assertEq(address(basin).balance, 2 ether);
    }

    // function testDepositFuzzy(ItemType fuzzyItem) public {
    //     cheats.startPrank(organizer);
    //     cheats.assume(uint8(fuzzyItem) <= uint8(3));
    //     // cheats.assume(fuzzyItem != ItemType.ERC20);
    //     // cheats.assume(fuzzyItem != ItemType.ERC721);
    //     // cheats.assume(fuzzyItem != ItemType.ERC1155);

    //     multiToken.setApprovalForAll(address(basin), true);
    //     nft.setApprovalForAll(address(basin), true);
    //     token.approve(address(basin), 1000);

    //     if(fuzzyItem == ItemType.NATIVE){
    //         createMockRecipientsAndPackages(2, 2, 1 ether, fuzzyItem, itemTypeMap[fuzzyItem]);

    //         cheats.expectEmit(true, true, true, true);
    //         emit TokenTransferer__PackagesDeposited(packages, 2 ether);
    //         basin.createChannel{value: 2 ether}(
    //             recipients,
    //             packages,
    //             organizer
    //         );
    //     } else {

    //         createMockRecipientsAndPackages(2, 2, 5, fuzzyItem, itemTypeMap[fuzzyItem]);
    //         // cheats.expectEmit(true, true, true, true);
    //         // emit TokenTransferer__PackagesDeposited(packages, 10);
    //         console.log("Fuzzy");
    //         basin.createChannel(
    //             recipients,
    //             packages,
    //             organizer
    //         );
    //     }
    // }

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

    function testMismatchValueAndPackages() public {
        createMockRecipientsAndPackages(
            2,
            2,
            1 ether,
            ItemType.NATIVE,
            address(0x0)
        );
        cheats.expectRevert(
            abi.encodeWithSelector(
                Errors
                    .TokenTransferer__IncorrectEthValueSentWithPackages
                    .selector,
                4 ether,
                2 ether
            )
        );
        channelId = basin.createChannel{value: 4 ether}(
            recipients,
            packages,
            organizer
        );
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

    function testDepositAllItemTypes() public {
        cheats.startPrank(organizer);
        multiToken.setApprovalForAll(address(basin), true);
        nft.setApprovalForAll(address(basin), true);
        token.approve(address(basin), 1000);

        ItemType[4] memory items = [
            ItemType.NATIVE,
            ItemType.ERC20,
            ItemType.ERC721,
            ItemType.ERC1155
        ];

        for (uint256 i = 0; i < items.length; i++) {
            ItemType item = items[i];
            if (item == ItemType.NATIVE) {
                createMockRecipientsAndPackages(
                    2,
                    2,
                    1 ether,
                    item,
                    itemTypeMap[item]
                );

                cheats.expectEmit(true, true, true, true);
                emit TokenTransferer__PackagesDeposited(packages, 2 ether);
                basin.createChannel{value: 2 ether}(
                    recipients,
                    packages,
                    organizer
                );
            } else {
                createMockRecipientsAndPackages(
                    2,
                    2,
                    5,
                    item,
                    itemTypeMap[item]
                );

                basin.createChannel(recipients, packages, organizer);
            }
        }
    }
}
