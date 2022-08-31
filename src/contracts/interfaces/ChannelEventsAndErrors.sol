pragma solidity ^0.8.0;

import {PackageItem} from "@contracts/lib/StructsAndEnums.sol";

import {Status} from "@contracts/lib/StructsAndEnums.sol";

/**
 * @title ChannelErrors
 * @author waint.eth
 * @notice ChannelErrors contains errors related to channels
 */
interface ChannelEventsAndErrors {
    error Channel__PackageAlreadyDelivered(uint256 placeIndex);

    // Channel & Binary
    error Channel__StatusCannotBeSetToOpen();

    event Channel__ChannelStatusChanged(uint256 channelId, Status newStatus);
    event Channel__NewChannelInitiated(uint256 channelId);
    event Channel__RecipientPlaced(address player, uint256 place);
}
