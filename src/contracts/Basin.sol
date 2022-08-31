// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

// Standard library imports
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// Custom contract imports
import {IBasin} from "@contracts/interfaces/IBasin.sol";
import {Errors} from "@contracts/interfaces/Errors.sol";
import {Events} from "@contracts/interfaces/Events.sol";
import {ChannelStruct, Status, PackageItem, ItemType} from "@contracts/lib/StructsAndEnums.sol";
import {Channel} from "@contracts/utils/Channel.sol";
import "@contracts/utils/TokenTransferer.sol";
import {SafeTransferLib} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";

/**
 * @title Basin
 * @author waint.eth
 * @notice This contract acts as a distribution factory. Where users can create
 *         distribution channels to transfer ownership of digital assets to
 *         recipients dynamically based on off chain events.
 */
contract Basin is ReentrancyGuard, TokenTransferer, Channel, IBasin {
    using SafeTransferLib for address;

    // Channel ID
    uint256 public nextChannelId = 1;

    // Mapping of hash to channel ID.
    mapping(bytes32 => uint256) internal hashToChannelId;

    // Amount of eth held by fees
    uint256 public feeHoldings;

    // Maximum protocol fee that can be set.
    uint256 internal constant MAX_FEE = 0.01 ether;

    // Fee to host a channel.
    uint256 public protocolFee = 0.001 ether;

    // Boolean to determine if the fee is enabled or not, can be toggled.
    bool public feeEnabled = false;

    // Address of the beneficiary of Channel fees.
    address payable public beneficiary;

    /**
     * @notice Confirms whether a set of recipients and packages can create a valid channel.
     *
     * @param recipients Addresses of the valid recipients in a channel.
     * @param packages PackageItem array of digital assets to be distributed in a channel.
     *
     */
    modifier validChannel(
        address[] calldata recipients,
        PackageItem[] calldata packages
    ) {
        uint256 recipientsLength = recipients.length;
        uint256 packagesLength = packages.length;

        // Too large of a channel
        if (recipientsLength >= 256 || packagesLength >= 256) {
            revert Basin__InvalidChannel__TooManyRecipientsOrPackages(
                recipientsLength,
                packagesLength
            );
        }

        if (recipientsLength < 2)
            revert Basin__InvalidChannel__TooFewRecipients(recipientsLength);

        if (recipientsLength != packagesLength)
            revert Basin__InvalidChannel__RecipientsAndPackagesMismatch(
                recipientsLength,
                packagesLength
            );

        delete recipientsLength;
        delete packagesLength;
        _;
    }

    /**
     * @notice Confirms if the given inputs hashes to a valid channels hash.
     *
     * @param channelId ID of the channel to check controller of.
     * @param recipients Addresses of the valid recipients in a channel.
     * @param packages PackageItem array of digital assets to be distributed in a channel.
     *
     */
    modifier validHash(
        uint256 channelId,
        address[] calldata recipients,
        PackageItem[] calldata packages
    ) {
        bytes32 channelHash = _hashChannel(channelId, recipients, packages);
        if (hashToChannelId[channelHash] == 0) {
            revert Basin__InvalidChannel__InvalidHash(
                recipients,
                packages,
                channelHash,
                "Channel does not exist, ID is 0."
            );
        }
        require(
            channels[hashToChannelId[channelHash]].size == recipients.length,
            "Mismatch between channel size and recipients length."
        );

        delete channelHash;
        _;
    }

    /**
     * @notice Ensure the caller for a given channel is the channel controller.
     *
     * @param channelId ID of the channel to check controller of.
     *
     */
    modifier onlyChannelController(uint256 channelId) {
        if (msg.sender != channels[channelId].controller)
            revert Basin__UnauthorizedChannelController(msg.sender);
        _;
    }

    /**
     * @notice Constructor sets the immutable channel implementation and beneficiary to the sender.
     */
    constructor() {
        beneficiary = payable(msg.sender);
    }

    /**
     * @notice Toggle is feeEnabled is true or false, only called by beneficiary.
     *
     */
    function toggleFee() public {
        require(msg.sender == beneficiary, "Not the beneficiary of the fee.");
        feeEnabled = feeEnabled ? false : true;
        emit Basin__FeeToggled(feeEnabled);
    }

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
    )
        external
        payable
        validChannel(recipients, packages)
        returns (uint256 channelId)
    {
        // Deposit all packages from the caller of the function
        bool success;
        if (feeEnabled) {
            require(msg.value >= protocolFee, "Not enough ETH sent for fee");
            feeHoldings += protocolFee;
            success = depositPackages(
                packages,
                address(this),
                msg.sender,
                msg.value - protocolFee
            );
        } else {
            success = depositPackages(
                packages,
                address(this),
                msg.sender,
                msg.value
            );
        }
        require(success, "Failed to deposit packages.");

        // Create channel hash
        bytes32 channelHash = _hashChannel(nextChannelId, recipients, packages);

        // Hash collision should never occur since we use the
        // Channel address in the hash algo
        require(
            hashToChannelId[channelHash] == 0,
            "Hash collision, reverting creation of channel"
        );
        require(
            channels[nextChannelId].controller == address(0x0),
            "Channel already in use."
        );

        // Initialize the channel
        initializeChannel(controller, recipients, channelHash, nextChannelId);

        hashToChannelId[channelHash] = nextChannelId;

        emit Basin__CreateChannel(channelId, channels[channelId]);
        ++nextChannelId;
        return nextChannelId - 1;
    }

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
    )
        external
        validHash(channelId, recipients, packages)
        onlyChannelController(channelId)
        nonReentrant
    {
        require(
            channels[channelId].channelStatus == Status.Open,
            "Channel is not open, cannot cancel."
        );
        address _to = channels[channelId].controller;
        distributePackagesForCancel(packages, _to);
        delete channels[channelId];
        delete hashToChannelId[_hashChannel(channelId, recipients, packages)];
    }

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
    )
        external
        validHash(channelId, recipients, packages)
        onlyChannelController(channelId)
        nonReentrant
    {
        if (recipientIndex >= recipients.length) {
            revert Basin__InvalidRecipientIndex(
                recipientIndex,
                recipients.length
            );
        }

        if (packageIndex >= packages.length) {
            revert Basin__InvalidPlaceIndex(packageIndex, packages.length);
        }

        _pairRecipientWithPackage(
            channelId,
            recipients[recipientIndex],
            packageIndex,
            recieverStillEligible
        );

        bool delivered = _deliverPackageToRecipient(
            recipients[recipientIndex],
            packages[packageIndex]
        );

        if (delivered == false) {
            revert Basin__FailedToDeliverPackage(
                recipients[recipientIndex],
                packages[packageIndex]
            );
        }
    }

    /**
     * @notice This function will deliver a set of packages to a set of recipients 1:1.
     *         The length of the recipients and the length of the packages must be the same.
     *         Package[0] will be delivered to recipient[0], package[1] - recipient[1], and
     *         so on. This function does not create a channel, this is a single execution
     *         function. All ItemTypes are valid (ETH, ERC20, ERC721, ERC1155).
     *
     * @param recipients Addresses of the people recieving packages.
     * @param packages Packages to be distributed to the recipients.
     *
     */
    function deliverPackages(
        address[] calldata recipients,
        PackageItem[] calldata packages
    ) external payable nonReentrant returns (bool) {
        // Make sure recipients and packages have same length;
        uint256 recipientsLength = recipients.length;
        require(
            recipientsLength == packages.length,
            "Packages and recipients mismatch."
        );

        uint256 ethInPackages = 0;

        for (uint256 i = 0; i < recipientsLength; i++) {
            // If the packages is ETH
            if (packages[i].itemType == ItemType.NATIVE) {
                ethInPackages += packages[i].amount;
                (bool sent, ) = address(recipients[i]).call{
                    value: packages[i].amount
                }("");
                require(sent, "Failed to send Ether");
            } else {
                require(
                    digestPackageDeposit(
                        packages[i],
                        recipients[i],
                        msg.sender
                    ),
                    "Package distribution failed"
                );
            }
        }

        require(ethInPackages == msg.value, "Incorrect Eth Deposit amount");
        return true;
    }

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
    )
        external
        validHash(channelId, recipients, packages)
        onlyChannelController(channelId)
        nonReentrant
    {
        _changeChannelStatus(channelId, newStatus);
    }

    function getChannelStatus(uint256 channelId)
        public
        view
        returns (Status stat)
    {
        return channels[channelId].channelStatus;
    }

    /**
     * @notice This function allows for the changing of the beneficiary. Only the beneficiary can
     *         call this function. The beneficiary is the address which recieves the fees.
     *
     * @param newBeneficiary Address of the new beneficiary to recieve the fees.
     *
     */
    function setBeneficiary(address payable newBeneficiary) external {
        require(
            msg.sender == beneficiary,
            "Not the beneficiary, cannot execute."
        );
        emit Basin__SetBeneficiary(newBeneficiary);
        beneficiary = newBeneficiary;
    }

    /**
     * @notice This function sets the protocolFee which is paid out to the beneficiary.
     *
     * @param newFee New uint256 value for the fee.
     *
     */
    function setProtocolFee(uint256 newFee) external {
        require(
            msg.sender == beneficiary,
            "Not the beneficiary, cannot execute."
        );
        require(newFee <= MAX_FEE, "Fee too high.");
        emit Basin__SetProtocolFee(newFee);
        protocolFee = newFee;
    }

    /**
     * @notice This function allows for the withdrawing of the fees collected by the protocol.
     *         This function is callable by anyone, but only sends the fees to the beneficiary
     *
     */
    function withdrawFee() public nonReentrant {
        uint256 holdingFees = feeHoldings;
        feeHoldings = 0;
        emit Basin__BeneficiaryWithdraw(holdingFees);
        address(beneficiary).safeTransferETH(holdingFees);
    }

    /**
     * @dev Internal function that calls the channels function pairRecipientAndPackage
     *
     * @param channelId ID of the channel to process.
     * @param recipient Address of the recipient derived from the recipients array in the calling function.
     * @param packageIndex Index in the package array to determine which package to deliver.
     * @param recieverStillEligible Bool to set on the Channel contract to block a user from recieveing more packages.
     *
     */
    function _pairRecipientWithPackage(
        uint256 channelId,
        address recipient,
        uint256 packageIndex,
        bool recieverStillEligible
    ) internal {
        emit Basin__RecipientPairedWithPackage(recipient, packageIndex);

        pairRecipientAndPackage(
            channelId,
            recipient,
            packageIndex,
            recieverStillEligible
        );
    }

    /**
     * @dev Internal function that calls the channels function changeStatus.
     *
     * @param channelId ID of the channel to process.
     * @param newStatus New Status enum to change the status in the channel to.
     *
     */
    function _changeChannelStatus(uint256 channelId, Status newStatus) private {
        emit Basin__ChannelStatusChanged(channelId, newStatus);

        changeStatus(channelId, newStatus);
    }

    /**
     * @dev Internal function which delivers a package to a recipient. This calls the TokenTransferer.sol contract.
     *      This function returns a boolean value to confirm the delivery of a package.
     *
     * @param recipient Address of the package recipient.
     * @param package PackageItem outlining what asset is being transfered to the recipient.
     *
     * @return success Boolean value confirming delivery of a package.
     *
     */
    function _deliverPackageToRecipient(
        address recipient,
        PackageItem calldata package
    ) internal returns (bool success) {
        return distributePackage(package, recipient);
    }

    /**
     * @dev Internal function which delivers a package to a recipient. This calls the TokenTransferer.sol contract.
     *      This function returns a boolean value to confirm the delivery of a package.
     *
     * @param recipients Addresses of the valid recipients in a channel.
     * @param packages PackageItem array of digital assets to be distributed in a channel.
     *
     * @return Bytes32 value of the hash of the inputs.
     *
     */
    function _hashChannel(
        uint256 id,
        address[] memory recipients,
        PackageItem[] memory packages
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(id, recipients, packages));
    }
}
