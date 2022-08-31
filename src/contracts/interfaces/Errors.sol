pragma solidity ^0.8.0;

import {PackageItem} from "@contracts/lib/StructsAndEnums.sol";

/**
 * @title Errors
 * @author waint.eth
 * @notice Errors contains errors for Basin
 */
interface Errors {

    /// @notice Invalid number of players `playersLength`, must have at least 2
    /// @param playersLength Length of players array
    error Basin__InvalidChannel__TooFewRecipients(uint256 playersLength);

    error Basin__InvalidChannel__TooManyRecipientsOrPackages(
        uint256 playersLength,
        uint256 payoutsLength
    );

    /// @notice Array lengths of players & payouts don't match (`playersLength` != `payoutsLength`)
    /// @param playersLength Length of players array
    /// @param payoutsLength Length of payouts array
    error Basin__InvalidChannel__RecipientsAndPackagesMismatch(
        uint256 playersLength,
        uint256 payoutsLength
    );

    /// @notice Sum of payouts != 100%
    /// @param payoutsSum Sum of all payouts for the Channel
    error InvalidChannel__InvalidPackagesSum(uint32 payoutsSum);

    /// @notice Package value for `index` is negative
    /// @param index Index for the negative payout value
    error InvalidChannel__PackagesMustBePositive(uint256 index);

    /// @notice Invalid distributorFee `distributorFee` cannot be greater than 10% (1e5)
    /// @param distributorFee Invalid distributorFee amount
    error InvalidChannel__InvalidDistributorFee(uint32 distributorFee);

    /// @notice Unauthorized sender `sender`
    /// @param sender Transaction sender
    error Basin__UnauthorizedChannelController(address sender);

    error Basin__InvalidChannel__InvalidHash(
        address[] players,
        PackageItem[] payouts,
        bytes32 channelHash,
        string mes
    );

    error Basin__InvalidRecipientIndex(
        uint256 playerIndex,
        uint256 playersLength
    );

    error Basin__InvalidPlaceIndex(uint256 placeIndex, uint256 placeLength);

    error TokenTransferer__InvalidTokenType(PackageItem item);

    error TokenTransferer__FailedTokenDeposit(PackageItem item, address from);

    error TokenTransferer__IncorrectEthValueSentWithPackages(
        uint256 ethSent,
        uint256 ethInPackages
    );
    error TokenTransferer__NoneTypeItemDeposit(
        address from,
        PackageItem reward
    );

    error Basin__FailedToDeliverPackage(address player, PackageItem item);
}
