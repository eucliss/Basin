// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

// Custom contract imports
import {ChannelStruct, Status, PackageItem, ItemType} from "@contracts/lib/StructsAndEnums.sol";

/**
 * @title IBasin
 * @author waint.eth
 * @notice This is the interface to Basin.sol
 */
interface IBasin {
    /**
     * @notice Primary functionality of Basin. This function allows you to create a new channel to distribute assets.
     *         The function will charge the protocolFee if feeEnabled is set to true. The function transfers all input packages
     *         to this contract for holding until they're distributed. A new channel is then created and mappings are updated
     *         with all the new information and hashes. The channel contract is then initialized and ready for distribution.
     *         The outcome is a new Channel contract with its own address and Basin having ownership of all package items taken as
     *         input. The channel can be canceled while its status is still in Open, but when the status is switched to Started
     *         the assets will only be deliverable to the recipients in the channel. This function is externally facing and requires
     *         payment and depositting of assets.
     *
     * @param recipients Addresses of the valid recipients in a channel.
     * @param packages PackageItem array of digital assets to be distributed in a channel.
     * @param controller Address of who will be controlling the channel.
     *
     * @return channelId ID of the channel created.
     */
    function createChannel(
        address[] calldata recipients,
        PackageItem[] calldata packages,
        address controller
    ) external payable returns (uint256 channelId);

    /**
     * @notice This function acts as a safety net for the creator of a channel. Before the channel is started, the
     *         controller of the channel has the ability to cancel it and return all the assets Basin controls back to them.
     *         This is the only time the user can withdraw items from a channel unless they're delivering the package to the
     *         recipient.
     *
     * @param channelId Address of the channel being executed.
     * @param recipients Addresses of the valid recipients in a channel.
     * @param packages PackageItem array of digital assets to be distributed in a channel.
     *
     */
    function cancelChannel(
        uint256 channelId,
        address[] calldata recipients,
        PackageItem[] calldata packages
    ) external;

    /**
     * @notice This function distributes a package to a recipient. The function first determines if the
     *         given inputs hash to a valid channel, which would confirm the packages and recipients are valid.
     *         The function then uses indexes for recipients and packages instead of taking addresses which
     *         forces the reciever to be valid in the channel, and also forces the package to be one which is
     *         already deposited. The function also sets if the reciever of the package is still eligible on
     *         the channel contract. This flag allows a single recipient to recieve multiple packages, or be
     *         restricted to a single package. The function calls _pairRecipientWithPackage which alters the
     *         storage on the channel contract to confirm distribution of a package and reception from a recipient.
     *         The function then distributes the package which protects against re-entrancy. Then the function
     *         transfers the package from Basin to the recipient.
     *
     * @param channelId ID of the channel to process.
     * @param recipients Addresses of the valid recipients in a channel.
     * @param packages PackageItem array of digital assets to be distributed in a channel.
     * @param recipientIndex Index in the recipients array to deliver the package to.
     * @param packageIndex Index in the package array to determine which package to deliver.
     * @param recieverStillEligible Bool to set on the Channel contract to block a user from recieveing more packages.
     *
     */
    function distributeToRecipient(
        uint256 channelId,
        address[] calldata recipients,
        PackageItem[] calldata packages,
        uint256 recipientIndex,
        uint256 packageIndex,
        bool recieverStillEligible
    ) external;

    /**
     * @notice This function changes the status of a Channel. The status are Open, Started, and Completed.
     *         The channel status can progress from Open -> Started -> Completed, this is the only way
     *         the statuses can progress. The channel contract asserts this progression.
     *
     * @param channelId ID of the channel to process.
     * @param recipients Addresses of the valid recipients in a channel.
     * @param packages PackageItem array of digital assets to be distributed in a channel.
     * @param newStatus Status enum value to set for the channel.
     *
     */
    function changeChannelStatus(
        uint256 channelId,
        address[] calldata recipients,
        PackageItem[] calldata packages,
        Status newStatus
    ) external;

    /**
     * @notice Toggle is feeEnabled is true or false, only called by beneficiary.
     *
     */
    function toggleFee() external;

    /**
     * @notice This function allows for the changing of the beneficiary. Only the beneficiary can
     *         call this function. The beneficiary is the address which recieves the fees.
     *
     * @param newBeneficiary Address of the new beneficiary to recieve the fees.
     *
     */
    function setBeneficiary(address payable newBeneficiary) external;

    /**
     * @notice This function sets the protocolFee which is paid out to the beneficiary.
     *
     * @param newFee New uint256 value for the fee.
     *
     */
    function setProtocolFee(uint256 newFee) external;

    /**
     * @notice This function allows for the withdrawing of the fees collected by the protocol.
     *         This function is callable by anyone, but only sends the fees to the beneficiary
     *
     */
    function withdrawFee() external;

    /**
     * @notice This function will deliver a set of packages to a set of recipients 1:1.
     *         The length of the recipients and the length of the packages must be the same.
     *         Package[0] will be delivered to recipient[0], package[1] - recipient[1], and
     *         so on. This function does not create a channel, this is a single execution
     *         function. All ItemTypes are valid (ETH, ERC20, ERC721, ERC1155).
     */
    function deliverPackages(
        address[] calldata recipients,
        PackageItem[] calldata packages
    ) external payable returns (bool);

    /**
     * @notice Get the status of a given Channel
     *
     */
    function getChannelStatus(uint256 channelId)
        external
        view
        returns (Status stat);
}
