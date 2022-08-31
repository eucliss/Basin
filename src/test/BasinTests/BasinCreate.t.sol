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

contract BasinCreateTest is DSTest, Configs {
    // Setup function
    // creates new Basin contract, setups approvals for transfers
    // Creates recipients, packages lists with ERC20 tokens
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

    // Initializes a 2 recipient channel and starts it
    function twoRecipientChannelInit() public {
        cheats.startPrank(organizer);
        channelId = basin.createChannel(recipients, packages, organizer);

        assertEq(
            token.balanceOf(address(basin)),
            recipientsLength * tokenAmountPerPackage
        );

        // Start the channel
        cheats.expectEmit(true, true, false, true);
        emit Basin__ChannelStatusChanged(channelId, Status.Started);
        basin.changeChannelStatus(
            channelId,
            recipients,
            packages,
            Status.Started
        );
        cheats.stopPrank();

        require(
            basin.getChannelStatus(channelId) == Status.Started,
            "Channel not started."
        );
    }

    // Test creating a channel
    function testCreateChannel() public {
        cheats.prank(organizer);
        channelId = basin.createChannel(recipients, packages, organizer);

        // Make sure tokens are transfered to Basin
        assertEq(
            token.balanceOf(address(basin)),
            recipientsLength * tokenAmountPerPackage
        );

        // bytes hash and address controller are correct
        (bytes32 h, address c, , , , , ) = basin.channels(channelId);
        assertEq(c, organizer);
        assertEq(ex.exposedHash(channelId, recipients, packages), h);
    }

    function testCreateChannelFee() public {
        basin.toggleFee();
        cheats.prank(organizer);
        channelId = basin.createChannel{value: fee}(
            recipients,
            packages,
            organizer
        );

        assertEq(basin.feeHoldings(), basin.protocolFee());

        // bytes hash and address controller are correct
        (bytes32 h, address c, , , , , ) = basin.channels(channelId);
        assertEq(c, organizer);
        assertEq(ex.exposedHash(channelId, recipients, packages), h);
    }

    function testCreateChannelFeeError() public {
        basin.toggleFee();
        cheats.prank(organizer);
        cheats.expectRevert("Not enough ETH sent for fee");
        channelId = basin.createChannel(recipients, packages, organizer);

        // No channel actually created
        (bytes32 h, address c, , , , , ) = basin.channels(channelId);
        assertEq(c, address(0x0));
        assertEq(h, bytes32(0));
    }

    // Create channel with 4 recipients and packages
    function testCreateChannelFour() public {
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

    function testCreateChannelSeventeen() public {
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

    // Fails when calling Channel init directly, must be from basin
    // function testCallChannelInitDirectly() public {
    //     cheats.prank(organizer);
    //     channelId = basin.createChannel(recipients, packages, organizer);
    //     cheats.expectRevert("Initializable: contract is already initialized");
    //     Channel(channelId).init(recipients);

    //     // Even if organizer it still fails
    //     cheats.prank(organizer);
    //     cheats.expectRevert("Initializable: contract is already initialized");
    //     Channel(channelId).init(recipients);
    // }

    // Test creating a channel hash is set right
    function testHashSetInMapping() public {
        for (uint256 i = 0; i < packages.length; i++) {
            allApprovals(organizer, packages[i].itemType, address(ex));
        }
        cheats.prank(organizer);
        channelId = ex.createChannel(recipients, packages, organizer);

        // bytes hash and address controller are correct
        (bytes32 h, address c, , , , , ) = ex.channels(channelId);
        assertEq(ex.exposedHashToAddress(h), channelId);
    }

    // Test creating a channel
    function testChannelInitCalled() public {
        cheats.prank(organizer);
        channelId = basin.createChannel(recipients, packages, organizer);

        (, , uint256 c_size, , , , ) = basin.channels(channelId);
        assertEq(c_size, recipients.length);
    }

    /*
     *   Valid Tournament Checks
     */

    // Create a tournament with 256 recipients, throws error
    function testCreateWith256recipientsErrors() public {
        cheats.expectRevert(
            abi.encodeWithSelector(
                Errors
                    .Basin__InvalidChannel__TooManyRecipientsOrPackages
                    .selector,
                256,
                0
            )
        );
        createMockRecipientsAndPackages(
            256,
            0,
            0,
            ItemType.ERC20,
            address(token)
        );
        channelId = basin.createChannel(recipients, packages, organizer);
    }

    // Create a tournament with 256 packages, throws error
    function testCreateWith256packagesErrors() public {
        cheats.expectRevert(
            abi.encodeWithSelector(
                Errors
                    .Basin__InvalidChannel__TooManyRecipientsOrPackages
                    .selector,
                0,
                256
            )
        );
        createMockRecipientsAndPackages(
            0,
            256,
            0,
            ItemType.ERC20,
            address(token)
        );
        channelId = basin.createChannel(recipients, packages, organizer);
    }

    // Create a tournament with 0 recipients, throws error
    function testCreateNoRecipientsErrors() public {
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

    // Create a tournament with 0 packages, throws error
    function testCreateNoPackagesErrors() public {
        cheats.expectRevert(
            abi.encodeWithSelector(
                Errors
                    .Basin__InvalidChannel__RecipientsAndPackagesMismatch
                    .selector,
                2,
                0
            )
        );
        createMockRecipientsAndPackages(
            2,
            0,
            0,
            ItemType.ERC20,
            address(token)
        );
        channelId = basin.createChannel(recipients, packages, organizer);
    }

    /*
     *  Deposit items with create tests
     */

    // Test depositing Eth
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

    function testDepositAllItemTypes() public {
        cheats.startPrank(organizer);

        // Set approvals
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
                uint256 basinBalance = address(basin).balance;
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
                assertEq(address(basin).balance, basinBalance + 2 ether);
            } else {
                createMockRecipientsAndPackages(
                    2,
                    2,
                    5,
                    item,
                    itemTypeMap[item]
                );
                cheats.expectEmit(true, true, true, true);
                emit TokenTransferer__PackagesDeposited(packages, 0);
                basin.createChannel(recipients, packages, organizer);
            }
        }
    }

    // Send the wrong amount of ether to the contract
    // Its expecting 2 ether total, msg.value is 4 ether
    function testMismatchValueAndPackagesErrors() public {
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

    function testDepositAllItemTypesWithFee() public {
        basin.toggleFee();
        assert(basin.feeEnabled());
        cheats.deal(organizer, 100 ether);
        cheats.startPrank(organizer);
        uint256 fee = basin.protocolFee();

        // Set approvals
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
                uint256 basinBalance = address(basin).balance;
                createMockRecipientsAndPackages(
                    2,
                    2,
                    1 ether,
                    item,
                    itemTypeMap[item]
                );

                cheats.expectEmit(true, true, true, true);
                emit TokenTransferer__PackagesDeposited(packages, 2 ether);
                basin.createChannel{value: 2 ether + fee}(
                    recipients,
                    packages,
                    organizer
                );
                assertEq(address(basin).balance, basinBalance + 2 ether + fee);
            } else {
                createMockRecipientsAndPackages(
                    2,
                    2,
                    5,
                    item,
                    itemTypeMap[item]
                );
                cheats.expectEmit(true, true, true, true);
                emit TokenTransferer__PackagesDeposited(packages, 0);
                basin.createChannel{value: fee}(
                    recipients,
                    packages,
                    organizer
                );
            }
        }
    }
}
