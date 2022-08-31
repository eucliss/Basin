pragma solidity ^0.8.14;

import {PackageItem, ItemType} from "@contracts/lib/StructsAndEnums.sol";

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC721, ERC721TokenReceiver} from "@solmate/tokens/ERC721.sol";
import {ERC1155, ERC1155TokenReceiver} from "@solmate/tokens/ERC1155.sol";
import {SafeTransferLib} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import "@contracts/interfaces/Errors.sol";
import "@contracts/interfaces/Events.sol";

/**
 * @title TokenTransferer
 * @author waint.eth
 * @notice This contract contains the token transfer capability for Basin.sol. This will be
 *         used to transfer PackageItem struct type values containing ERC standard tokens (20, 721, 1155, ETH)
 *         to recipients in channels or to Basin itself. This contract allows for
 *         depositing multiple packages and distributing packages to recipients.
 */
contract TokenTransferer is
    Errors,
    Events,
    ERC721TokenReceiver,
    ERC1155TokenReceiver
{
    using SafeTransferLib for ERC20;
    using SafeTransferLib for address;

    /**
     * @notice Deposit an array of PackageItems into the Basin contract. This function takes a to
     *         parameter which is always set to the address of Basin. The packages can include ETH
     *         as well as any ERC(20, 721, 1155) thus the function validates the amount of ETH sent
     *         in the msg.value of the transaction matches what is defined in the packages themselves.
     *         The function then digests each package deposit by sending the package to Basin. The
     *         function requires depositing of all packages and correct ETH amount or it fails.
     *
     * @param packages PackageItem array of digital assets to be deposited.
     * @param to To address of where the packages are being deposited.
     * @param from Address where the packages are being transfered from.
     * @param ethValue ETH value that was sent with the message, must align with all package value.
     *
     * @return success Boolean value confirming the depositing of all packages.
     */
    function depositPackages(
        PackageItem[] calldata packages,
        address to,
        address from,
        uint256 ethValue
    ) internal returns (bool success) {
        // ) internal payable returns (bool success) {
        // Initiate values for later
        uint256 len = packages.length;
        uint256 packageEth = 0;
        bool ethInPackages = false;

        // Loop through all packages
        for (uint256 i = 0; i < len; i++) {
            // If the package is ETH, track the amount and flip the ethInPackages flag.
            if (packages[i].itemType == ItemType.NATIVE) {
                packageEth += packages[i].amount;
                ethInPackages = true;

                // Else we need to digest the package and confirm depositing.
            } else {
                success = digestPackageDeposit(packages[i], to, from);
                if (success == false) {
                    revert TokenTransferer__FailedTokenDeposit(
                        packages[i],
                        from
                    );
                }
            }
        }

        // If no eth in the packages, but eth sent with msg, revert
        if (ethInPackages == false && ethValue != 0) {
            revert TokenTransferer__IncorrectEthValueSentWithPackages(
                ethValue,
                packageEth
            );
        }

        // If eth is in the packages but the eth in the package doesnt equal eth sent, revert
        if (ethInPackages && packageEth != ethValue) {
            revert TokenTransferer__IncorrectEthValueSentWithPackages(
                ethValue,
                packageEth
            );
        }

        emit TokenTransferer__PackagesDeposited(packages, ethValue);
        return true;
    }

    /**
     * @notice Distributes a single package to a recipient.
     *
     * @param item PackageItem to be distributed to the to param address.
     * @param to To address of where the package is getting distributed.
     *
     * @return success Boolean value confirming the distribution of the package.
     */
    function distributePackage(PackageItem calldata item, address to)
        internal
        returns (bool success)
    {
        success = digestPackageDistribute(item, payable(to));
        require(success, "Failed to distribute payout.");
    }

    /**
     * @notice Distribute packages for a channel in the event of a cancelation.
     *         This function distributes all the packages to one address.
     *
     * @param items PackageItems to be distributed to the to param address.
     * @param to To address of where the package is getting distributed.
     *
     * @return success Boolean value confirming the distribution of the package.
     */
    function distributePackagesForCancel(
        PackageItem[] calldata items,
        address to
    ) internal returns (bool success) {
        // Loop through all packages and send to the to address.
        for (uint256 i = 0; i < items.length; i++) {
            success = digestPackageDistribute(items[i], payable(to));
            require(success, "Failed to distribute payout.");
        }
    }

    /**
     * @notice Take a PackageItem being deposited and execute the deposit. This function
     *         will handle ERC(20, 721, 1155) but not ETH - that is handled elsewhere.
     *         The function transfers assets to Basin. If it fails, reverts.
     *
     * @param item PackageItem to be deposited to the to param address.
     * @param to To address of where the package is getting deposited.
     * @param from Address to transfer the item from.
     *
     * @return success Boolean value confirming the distribution of the package.
     */
    function digestPackageDeposit(
        PackageItem calldata item,
        address to,
        address from
    ) internal returns (bool success) {
        // ERC20
        if (item.itemType == ItemType.ERC20) {
            success = transferERC20(item, to, from);
            return success;
        }

        // ERC721
        if (item.itemType == ItemType.ERC721) {
            success = transferERC721(item, to, from);
            return success;
        }

        // ERC1155
        if (item.itemType == ItemType.ERC1155) {
            success = transferERC1155(item, to, from);
            return success;
        }
        if (success == false || item.itemType == ItemType.NATIVE) {
            revert TokenTransferer__InvalidTokenType(item);
        }
    }

    /**
     * @notice Take a PackageItem being distributed and execute the distribution. This function
     *         will handle ERC(20, 721, 1155) and also ETH. The function transfers the package
     *         to the param to. Will revert if it fails.
     *
     * @param item PackageItem to be distributed to the to param address.
     * @param to To address of where the package is getting distributed.
     *
     * @return success Boolean value confirming the distribution of the package.
     */
    function digestPackageDistribute(
        PackageItem calldata item,
        address payable to
    ) internal returns (bool success) {
        // ETH
        if (item.itemType == ItemType.NATIVE) {
            address(to).safeTransferETH(item.amount);
            return true;
        }

        // ERC20
        if (item.itemType == ItemType.ERC20) {
            success = transferERC20Out(item, to);
            return success;
        }

        // ERC721
        if (item.itemType == ItemType.ERC721) {
            success = transferERC721(item, to, address(this));
            return success;
        }

        // ERC1155
        if (item.itemType == ItemType.ERC1155) {
            success = transferERC1155(item, to, address(this));
            return success;
        }

        // Revert if it fails
        if (success == false) {
            revert TokenTransferer__InvalidTokenType(item);
        }
    }

    /**
     * @dev Transfer an ERC20 PackageItem to Basin from a channel owner. This function
     *      handles in the inbound package deposits.
     *
     * @param item PackageItem to be distributed to the to param address.
     * @param to To address of where the package is getting distributed.
     * @param from Address to transfer the item from.
     *
     * @return success Boolean value confirming the distribution of the package.
     */
    function transferERC20(
        PackageItem memory item,
        address to,
        address from
    ) internal returns (bool success) {
        success = ERC20(item.token).transferFrom(from, to, item.amount);
        require(success, "Safe transfer for ERC20 failed.");
    }

    /**
     * @dev Transfer an ERC20 PackageItem to a recipient from Basin. This function
     *      handles only the outbound package distributions.
     *
     * @param item PackageItem to be distributed to the to param address.
     * @param to To address of where the package is getting distributed.
     *
     * @return success Boolean value confirming the distribution of the package.
     */
    function transferERC20Out(PackageItem memory item, address to)
        internal
        returns (bool success)
    {
        success = ERC20(item.token).transfer(to, item.amount);
        require(success, "Safe transfer for ERC20 failed.");
    }

    /**
     * @dev Transfer an ERC721 PackageItem to an address from another address. This function
     *      handles both deposits and distribution of packages.
     *
     * @param item PackageItem to be distributed to the to param address.
     * @param to To address of where the package is getting distributed.
     * @param from Address to transfer the item from.
     *
     * @return success Boolean value confirming the distribution of the package.
     */
    function transferERC721(
        PackageItem memory item,
        address to,
        address from
    ) internal returns (bool success) {
        ERC721(item.token).safeTransferFrom(from, to, item.identifier);
        return true;
    }

    /**
     * @dev Transfer an ERC1155 PackageItem to an address from another address. This function
     *      handles both deposits and distribution of packages.
     *
     * @param item PackageItem to be distributed to the to param address.
     * @param to To address of where the package is getting distributed.
     * @param from Address to transfer the item from.
     *
     * @return success Boolean value confirming the distribution of the package.
     */
    function transferERC1155(
        PackageItem memory item,
        address to,
        address from
    ) internal returns (bool success) {
        ERC1155(item.token).safeTransferFrom(
            from,
            to,
            item.identifier,
            item.amount,
            ""
        );
        return true;
    }
}

/**
 * @notice Deposits a single package into Basin. This function takes a PackegeItem from the
 *         user and deposits it into the address defined in the to parameter.
 *
 *
 */
// function depositPackage(
//     PackageItem calldata package,
//     address to,
//     address from,
//     uint256 ethValue
// ) public payable returns (bool success) {
//     if (package.itemType == ItemType.NONE) {
//         revert TokenTransferer__NoneTypeItemDeposit(from, package);
//     }
//     bool ethInPackages = false;
//     if (package.itemType == ItemType.NATIVE) {
//         if (ethValue != package.amount) {
//             ethInPackages = true;
//             revert TokenTransferer__IncorrectEthValueSentWithPackages(
//                 ethValue,
//                 package.amount
//             );
//         }
//     } else {
//         success = digestPackageDeposit(package, to, from);
//         if (success == false) {
//             revert TokenTransferer__FailedTokenDeposit(package, from);
//         }
//     }
//     // emit TokenTransferer__PackagesDeposited(package, ethValue);
//     return true;
// }
