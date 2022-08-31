// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "@ds/test.sol";
import "@std/console.sol";
import "@contracts/utils/Channel.sol";
import "@contracts/Basin.sol";
import {Configs} from "./utils/Configs.sol";

// import { Errors } from "@contracts/interfaces/Errors.sol";
// import { Events } from "@contracts/interfaces/Events.sol";

contract ChannelTest is DSTest, Configs {
    bytes32 channelHash;
    bytes32 recipientsBits;
    bytes32 packagesBits;
    Status channelStatus;

    function setUp() public {
        basin = new Basin();
        basinAddress = msg.sender;
        channelId = 100;

        init5RecipientChannelExposed();
    }

    function init5RecipientChannelExposed() public {
        allApprovals(organizer, ItemType.ERC20, address(ex));
        cheats.prank(organizer);
        channelId = ex.createChannel(recipients, packages, organizer);
        (
            channelHash,
            ,
            channelSize,
            recipientsBits,
            packagesBits,
            ,
            channelStatus
        ) = ex.channels(channelId);

        assertEq(channelSize, recipients.length);
    }

    function init2RecipientChannel() public {
        resetRecipientsAndPackages();
        createMockRecipientsAndPackages(
            2,
            2,
            10,
            ItemType.ERC20,
            address(token)
        );
        allApprovals(organizer, ItemType.ERC20, address(basin));
        cheats.prank(organizer);
        channelId = basin.createChannel(recipients, packages, organizer);
        (
            channelHash,
            ,
            channelSize,
            recipientsBits,
            packagesBits,
            ,
            channelStatus
        ) = basin.channels(channelId);
        assertEq(channelSize, recipients.length);
    }

    function testChannelSetup() public {
        assertEq(recipientsBits, bytes32(uint256(2**channelSize - 1)));
        assertEq(packagesBits, bytes32(uint256(0)));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                INIT
    //////////////////////////////////////////////////////////////////////////*/

    function testChannelInit() public {
        channelHash = ex.exposedHash(channelId, recipients, packages);
        channelId++;

        cheats.startPrank(organizer);
        cheats.expectEmit(true, true, true, true);
        emit Channel__NewChannelInitiated(channelId);
        ex.exInit(organizer, recipients, channelHash, channelId);

        (
            bytes32 resHash,
            address resController,
            uint256 resSize,
            bytes32 resRecipients,
            bytes32 resPackages,
            uint256 resId,
            Status resStatus
        ) = ex.channels(channelId);

        assertEq(resHash, channelHash);
        assertEq(resController, organizer);
        assertEq(resSize, recipients.length);
        assertEq(resRecipients, bytes32(2**recipients.length - 1));
        assertEq(resPackages, bytes32(0));
        assertEq(resId, channelId);
        require(resStatus == Status.Open);
    }

    /*//////////////////////////////////////////////////////////////////////////
                        CREATE RECIPIENT BITMAP
    //////////////////////////////////////////////////////////////////////////*/

    function testRecipientBitMap() public {
        init2RecipientChannel();
        bytes32 r;
        for (uint256 i = 0; i < channelSize; i++) {
            assertEq(basin.channelRecipientBitmap(channelId, recipients[i]), i);
        }
    }

    function testCreateRecipientBitMap() public {
        cheats.startPrank(organizer);
        channelId++;
        ex.exSetChannelSize(channelId, recipients.length);
        ex.exCreateRecipientBitMap(channelId, recipients);

        (, , , bytes32 resRecipients, , , ) = ex.channels(channelId);
        for (uint256 i = 0; i < recipients.length; i++) {
            assertEq(i, ex.channelRecipientBitmap(channelId, recipients[i]));
        }
    }

    function testCreateRecipientBitMapError() public {
        cheats.startPrank(organizer);
        (, , , bytes32 resRecipients, , , ) = ex.channels(channelId);
        for (uint256 i = 0; i < recipients.length; i++) {
            assertEq(i, ex.channelRecipientBitmap(channelId, recipients[i]));
        }

        cheats.expectRevert(
            "Bit already set for recipient, error initiating channel."
        );
        ex.exCreateRecipientBitMap(channelId, recipients);
    }

    /*//////////////////////////////////////////////////////////////////////////
                        PAIR RECIPIENT AND PACKAGE
    //////////////////////////////////////////////////////////////////////////*/

    function testpairRecipientAndPackage() public {
        bytes32 pack;
        bytes32 r;
        address p;
        uint256 val = 0;
        uint256 recipientVal = uint256(2**channelSize - 1);
        for (uint256 i = 0; i < channelSize; i++) {
            p = recipients[i];
            ex.exPairRecipientAndPackage(channelId, p, i, false);
            recipientVal = recipientVal - (2**i);
            val = val + (2**i);

            (, , , r, pack, , ) = ex.channels(channelId);

            assertEq(pack, bytes32(val));
            assertEq(r, bytes32(recipientVal));
        }
    }

    function testpairRecipientAndMultiplePackages() public {
        bytes32 pack;
        bytes32 r;
        address p = recipients[0];
        uint256 val = 0;
        uint256 recipientVal = uint256(2**channelSize - 1);
        for (uint256 i = 0; i < channelSize; i++) {
            ex.exPairRecipientAndPackage(channelId, p, i, true);
            val = val + (2**i);

            (, , , r, pack, , ) = ex.channels(channelId);

            assertEq(pack, bytes32(val));
            assertEq(r, bytes32(recipientVal));
        }
    }

    function testpairRecipientAndMultiplePackagesError() public {
        bytes32 pack; // bytes packages value for flipped package bits
        bytes32 r; // bytes recipients value, eligibility flag (0 | 1)
        address p = recipients[0];
        uint256 val = 0;
        uint256 recipientVal = uint256(2**channelSize - 1); //

        // Val at index 0 for packages[0]
        val = val + (2**0);
        emit Channel__RecipientPlaced(p, val);

        // Send p package[0], allow more packages
        ex.exPairRecipientAndPackage(channelId, p, 0, true);
        (, , , r, pack, , ) = ex.channels(channelId);
        // Assert bytes value for that recipient is correct in channel
        assertEq(r, bytes32(recipientVal));

        assertEq(pack, bytes32(val));

        // Send p package[1], no more packages
        ex.exPairRecipientAndPackage(channelId, p, 1, false);
        val = val + (2**1);
        (, , , r, pack, , ) = ex.channels(channelId);
        assertEq(pack, bytes32(val));
        // 2^0 b/c recipient is 0 index
        assertEq(r, bytes32(recipientVal - 2**0));

        // Send p package[1] to different person should fail
        cheats.expectRevert(
            abi.encodeWithSelector(
                ChannelEventsAndErrors
                    .Channel__PackageAlreadyDelivered
                    .selector,
                1
            )
        );
        ex.exPairRecipientAndPackage(channelId, recipients[1], 1, true);

        // Send p package[1] to same person should have different error
        cheats.expectRevert(
            "Recipient not eligible to recieve packages in this Channel."
        );

        ex.exPairRecipientAndPackage(channelId, p, 1, true);

        // Send p package[2] to same person should have different error
        cheats.expectRevert(
            "Recipient not eligible to recieve packages in this Channel."
        );
        ex.exPairRecipientAndPackage(channelId, p, 2, false);
    }

    function testFlipRecipientBitError() public {
        ex.exPairRecipientAndPackage(channelId, recipients[0], 0, false);
        cheats.expectRevert(
            "Recipient not eligible to recieve packages in this Channel."
        );
        ex.exPairRecipientAndPackage(channelId, recipients[0], 1, true);
    }

    function testFlipRecipientBitPackageOutOfBounds() public {
        ex.exPairRecipientAndPackage(channelId, recipients[1], 1, true);
        cheats.expectRevert("Package index too high");
        ex.exPairRecipientAndPackage(channelId, recipients[1], 2, true);
    }

    /*//////////////////////////////////////////////////////////////////////////
                        FLIPPING BITS
    //////////////////////////////////////////////////////////////////////////*/

    function testFlipRecipientBit() public {
        bytes32 r;
        address p;
        uint256 val = uint256(2**channelSize - 1);
        for (uint256 i = 0; i < channelSize; i++) {
            p = recipients[i];
            ex.exFlipRecipientBit(channelId, p);
            val = val - (2**i);
            (, , , r, , , ) = ex.channels(channelId);
            assertEq(r, bytes32(val));
        }
    }

    function testFlipPackageBit() public {
        bytes32 p;
        uint256 val = 0;
        for (uint256 i = 0; i < channelSize; i++) {
            ex.exFlipPackageBit(channelId, i);
            val = val + (2**i);
            (, , , , p, , ) = ex.channels(channelId);
            assertEq(p, bytes32(val));
        }
    }

    function testFlipPackageBitOutOfBoundsError() public {
        cheats.expectRevert("Package index too high");
        ex.exFlipPackageBit(channelId, 1000000000);
    }

    function testFlipPackageBitAlreadyDeliveredError() public {
        ex.exFlipPackageBit(channelId, 0);
        cheats.expectRevert(
            abi.encodeWithSelector(
                ChannelEventsAndErrors
                    .Channel__PackageAlreadyDelivered
                    .selector,
                0
            )
        );
        ex.exFlipPackageBit(channelId, 0);
    }

    /*//////////////////////////////////////////////////////////////////////////
                        Channel Status
    //////////////////////////////////////////////////////////////////////////*/

    function testChangeStatus() public {
        // init 5 channel exposed
        init5RecipientChannelExposed();

        // OPEN

        // Channel is Open to start, Try setting channel to Open fails
        cheats.expectRevert(Channel__StatusCannotBeSetToOpen.selector);
        ex.exChangeStatus(channelId, Status.Open);

        // Try changing to completed
        cheats.expectRevert("Channel is not started.");
        ex.exChangeStatus(channelId, Status.Completed);

        // Set channel to Started then
        ex.exChangeStatus(channelId, Status.Started);
        require(
            ex.getChannelStatus(channelId) == Status.Started,
            "Statuses not = Started.."
        );

        // STARTED

        // Try changing back to open
        cheats.expectRevert(Channel__StatusCannotBeSetToOpen.selector);
        ex.exChangeStatus(channelId, Status.Open);

        // Try changing to Started (current status)
        cheats.expectRevert("Channel is not open.");
        ex.exChangeStatus(channelId, Status.Started);

        // Try changing to completed then
        cheats.expectRevert("Not all packages delivered.");
        ex.exChangeStatus(channelId, Status.Completed);

        // Place the recipients to fulfil completion requirements
        ex.exPairRecipientAndPackage(channelId, recipients[0], 0, false);
        ex.exPairRecipientAndPackage(channelId, recipients[1], 1, false);

        // COMPLETED

        // Now that they're placed lets complete the tournament
        cheats.expectEmit(true, true, true, true);
        emit Channel__ChannelStatusChanged(channelId, Status.Completed);
        ex.exChangeStatus(channelId, Status.Completed);
        require(
            ex.getChannelStatus(channelId) == Status.Completed,
            "Channel didnt complete"
        );

        // Try changing back to open
        cheats.expectRevert(Channel__StatusCannotBeSetToOpen.selector);
        ex.exChangeStatus(channelId, Status.Open);

        // Try changing to Started (current status)
        cheats.expectRevert("Channel is not open.");
        ex.exChangeStatus(channelId, Status.Started);

        // Try changing to completed
        cheats.expectRevert("Channel is not started.");
        ex.exChangeStatus(channelId, Status.Completed);
    }

    // function testFlipStatusFuzz(Status _newStatus) public {
    //     if (_newStatus == Status.Open) {
    //         cheats.expectRevert(Channel__StatusCannotBeSetToOpen.selector);
    //     } else {
    //         channel.flipStatus(_newStatus);
    //         require(channel.channelStatus() == _newStatus);
    //     }
    // }
}
