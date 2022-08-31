pragma solidity ^0.8.14;

import {ChannelStruct, PackageItem, ItemType, Status} from "@contracts/lib/StructsAndEnums.sol";
import {ChannelEventsAndErrors} from "@contracts/interfaces/ChannelEventsAndErrors.sol";

/**
 * @title Channel
 * @author waint.eth
 * @notice This contract contains the logic to execute a channel. A channel consists of
 *         a Bytes32 representation of the recipients and packages, the size of the channel,
 *         and the status of the channel. When a channel is initialized, a bitmap is created
 *         for the recipients, this essentially maps the array of recipients to binary bits
 *         the bits are used for tracking whether a recipient can recieve a package or not.
 *         if the bit associated with a recipient index is 1, they can recieve a package, if
 *         it is 0, they cannot. The packages storage works in a similar way, although we dont
 *         need to store the packageItem associated with that bit like we do addresses for
 *         recipients. Basin will take care of that. Here is a representation of a bitmap:
 *
 *                  Bit map from recipient address to bits
 *                      [addr0, addr1, addr2, addr3, addr4] => 1 1 1 1 1
 *                      Flip the list so
 *                      0 => 2^0 bit
 *                      1 => 2^1 bit
 *                      2 => 2^2 bit ...
 *
 *         When a recipient is paired with a package, they have the option to mark the recipient
 *         as not eligible for other packages, if this is the case then we will flip the recipients
 *         bit in the recipients bytes32 storage. Next we need to flip the package bit as well since
 *         the package will be delivered and Basin will not own it any longer.
 */
contract Channel is ChannelEventsAndErrors {
    // Mapping of channel address to struct containing hash and controller.
    mapping(uint256 => ChannelStruct) public channels;
    mapping(uint256 => mapping(address => uint256))
        public channelRecipientBitmap;

    //     struct ChannelStruct {
    //     bytes32 hash;
    //     address controller;
    //     uint256 size;
    //     bytes32 recipients;
    //     bytes32 packages;
    //     mapping(address => uint256) recipientBitMap;
    //     uint256 id;
    //     Status channelStatus;
    // }

    /**
     * @notice This is the initialization function, only called once during createChannel from Basin.
     *         This function sets the size of the channel to the length of the recipients and sets the
     *         recipientBitMap. It goes through and initializes the bytes32 recipients storage to 2**size -1
     *         and the bytes32 packages storage to 0.
     *
     * @param _recipientsList Address array of recipients to initialize the channel with.
     *
     */
    function initializeChannel(
        address controller,
        address[] memory _recipientsList,
        bytes32 channelHash,
        uint256 channelId
    ) internal {
        channels[channelId] = ChannelStruct({
            hash: channelHash,
            controller: controller,
            size: _recipientsList.length,
            recipients: bytes32(2**_recipientsList.length - 1),
            packages: 0,
            id: channelId,
            channelStatus: Status.Open
        });
        _createRecipientBitMap(channelId, _recipientsList);
        emit Channel__NewChannelInitiated(channelId);
    }

    /**
     * @notice Helper function to initialize the bitmap with. This function takes the recipients
     *         and the size of the channel and maps each address recipient to a bit index. This
     *         allows us to flip a specific bit when an address is being paired with a package.
     *
     * @param _recipients Address array of recipients to initialize the bitmap with.
     *
     */
    function _createRecipientBitMap(
        uint256 channelId,
        address[] memory _recipients
    ) internal {
        // Init all recipients to 1's
        // recipients = channels[channelId].recipients;
        uint256 size = channels[channelId].size;

        unchecked {
            for (uint256 i = 0; i < size; i++) {
                // TODO: this actually should be an indexed error for reporting
                // Fix v1/test/Channel.t.sol test testCreateRecipientBitMapError when fixed
                require(
                    channelRecipientBitmap[channelId][_recipients[i]] == 0,
                    "Bit already set for recipient, error initiating channel."
                );
                channelRecipientBitmap[channelId][_recipients[i]] = i;
            }
        }
    }

    /**
     * @notice This function takes a recipient and pairs them with a package. It does this by flipping
     *         bits in the recipients and packages storage. If the bool recieverStillEligible is false,
     *         then we flip the recipient bit to a 0 to mark them as uneligible for future packages.
     *         Regardless of this boolean value we flip the package bit to mark that Basin does
     *         not own that package any longer.
     *
     * @param _recipient Address of the recipient of a package.
     * @param _packageIndex Index of the package to be delivered in the package array.
     * @param recieverStillEligible Bool to set to mark a reciever as eligible in the future or not.
     *
     */
    function pairRecipientAndPackage(
        uint256 channelId,
        address _recipient,
        uint256 _packageIndex,
        bool recieverStillEligible
    ) internal {
        // Confirm the recipient is eligible for a package still
        bytes32 recipientBit = bytes32(
            2**(channelRecipientBitmap[channelId][_recipient])
        );
        require(
            (channels[channelId].recipients & recipientBit) == recipientBit,
            "Recipient not eligible to recieve packages in this Channel."
        );

        // If they are no longer eligible, flip the bit
        if (!recieverStillEligible) {
            flipRecipientBit(channelId, _recipient);
        }

        flipPackageBit(channelId, _packageIndex);
        emit Channel__RecipientPlaced(_recipient, _packageIndex);
    }

    /**
     * @notice This function flips a recipients bit. A recipients bit must be a 1.
     *
     * @param channelId ID of the channel to change
     * @param _recipient Address of the recipient of a package.
     *
     */
    function flipRecipientBit(uint256 channelId, address _recipient) internal {
        // Bit operations to take recipient index and set to 0 in bitmap
        bytes32 recipientBit = bytes32(
            2**(channelRecipientBitmap[channelId][_recipient])
        );

        // And the recipients
        channels[channelId].recipients =
            channels[channelId].recipients ^
            recipientBit;
    }

    /**
     * @notice This function flips a package bit. A package bit must be 0.
     *
     * @param packageIndex Index in packages to flip.
     *
     */
    function flipPackageBit(uint256 channelId, uint256 packageIndex) internal {
        // Must be less than the size of the recipients
        require(
            packageIndex < channels[channelId].size,
            "Package index too high"
        );

        // Get the package bit
        // Package 0 = bit 0 == 2^0 == 1 -> 00001
        // Package 1 = bit 1 == 2^1 == 2 -> 00010
        // Package 2 = bit 3 == 2^2 == 4 -> 00100
        // 0  .... 0  0  0
        // pX .... p2 p1 p0
        bytes32 packageBit = bytes32(2**packageIndex);

        if (packageBit & channels[channelId].packages == packageBit) {
            revert Channel__PackageAlreadyDelivered(packageIndex);
        }

        channels[channelId].packages =
            channels[channelId].packages |
            packageBit;
    }

    /**
     * @notice This function changes the status of the Channel.
     *         Status changes from Open -> Started -> Completed.
     *
     * @param newStatus New status to set the channel to.
     *
     */
    function changeStatus(uint256 channelId, Status newStatus) internal {
        // If newStatus is Open, revert. Cant re-open a channel.
        if (newStatus == Status.Open) {
            revert Channel__StatusCannotBeSetToOpen();
        }

        // If new status is started
        // Confirm channel is going from Open -> Started
        // Confirm channel is not Completed.
        if (newStatus == Status.Started) {
            require(
                channels[channelId].channelStatus == Status.Open,
                "Channel is not open."
            );
            require(
                channels[channelId].channelStatus != Status.Completed,
                "Channel is completed."
            );
        }

        // If new status is Completed
        // Confirm channel status is Started, must be Started -> Completed
        if (newStatus == Status.Completed) {
            require(
                channels[channelId].channelStatus == Status.Started,
                "Channel is not started."
            );

            // Require all packages delivered before completing channel
            require(
                channels[channelId].packages ==
                    bytes32(2**channels[channelId].size - 1),
                "Not all packages delivered."
            );
        }

        // Set status
        channels[channelId].channelStatus = newStatus;
        emit Channel__ChannelStatusChanged(channelId, newStatus);
    }
}

/*

    What is a channel ??

A channel has
- Recipients
    - Recipients are eliminated and payed out
- Matches
    - Matches are played and leads to eliminations
- Prizepool
    - Prizepool gets paid to recipients
- Package structure
    - Determines how prizepool is distributed


    recipient1 - x
    x
    recipient2 -----------------|
                            |    recipient2    ___WINNER___
    recipient3 - x              | ---- x -------| Recipient 4 |
    x                     |    recipient4    ------------
    recipient4 -|     recipient4 --|
            | ------ x 
    recipient5 -|     recipient5


recipients = [1, 2, 3, 4, 5] 
packages = [50, 30, 10, 10, 0]
len = 5
    

*/

/*
    Requirements for allchannels

    - Recipients == Package Distribution
    - Packages == 100% of prizepool
    - Prizepool > 0 ether
    - Recipients cannot be paid out twice
    - Packages cannot be repeated
*/
