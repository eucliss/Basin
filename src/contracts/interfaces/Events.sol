pragma solidity ^0.8.0;

import {ChannelStruct, ChannelDetails, Status, PackageItem} from "@contracts/lib/StructsAndEnums.sol";

/**
 * @title Events
 * @author waint.eth
 * @notice Events contains Basin Events
 */
interface Events {
    event Basin__SetBeneficiary(address beneficiary);
    event Basin__SetProtocolFee(uint256 newFee);
    event Basin__RecipientPairedWithPackage(address player, uint256 place);
    event Basin__ChannelStatusChanged(uint256 channelId, Status newStatus);
    event Basin__CreateChannel(
        uint256 channelId,
        ChannelStruct _createdChannel
    );
    event Basin__CreateDynamicChannel(
        address _channelAddress,
        ChannelStruct _createdChannel
    );
    event Basin__RecipientAddedToDynamicChannel(
        uint256 channelId,
        address player,
        uint256 size
    );

    event Basin__RecipientRemovedFromChannel(
        uint256 channelId,
        address player,
        uint256 size
    );
    event Basin__RecipientAccepted(uint256 channelId, address player);
    event Basin__RecipientDeclined(uint256 channelId, address player);
    event Basin__RecipientRescindedAcceptance(
        uint256 channelId,
        address player
    );
    event Basin__DynamicChannelStarted(uint256 channelId, address[] player);
    event Basin__FeeToggled(bool feeStatus);
    event Basin__BeneficiaryWithdraw(uint256 fees);

    // event Channel__ChannelStatusChanged(uint256 channelId, Status newStatus);
    // event Channel__NewChannelInitiated(uint256 channelId);
    // event Channel__RecipientPlaced(address player, uint256 place);

    event TokenTransferer__PackagesDeposited(
        PackageItem[] payouts,
        uint256 ethValue
    );
}
