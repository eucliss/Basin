// // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@contracts/Basin.sol";

contract Exposed is Basin {
    function exposedHashToAddress(bytes32 h) public view returns (uint256) {
        return hashToChannelId[h];
    }

    function exposedHash(
        uint256 channelId,
        address[] memory players,
        PackageItem[] memory payouts
    ) public pure returns (bytes32 sum) {
        sum = _hashChannel(channelId, players, payouts);
    }

    /*//////////////////////////////////////////////////////////////
                                 CHANNEL
    //////////////////////////////////////////////////////////////*/

    function exInit(
        address controller,
        address[] memory _recipientsList,
        bytes32 channelHash,
        uint256 channelId
    ) public {
        initializeChannel(controller, _recipientsList, channelHash, channelId);
    }

    function exCreateRecipientBitMap(
        uint256 channelId,
        address[] memory _recipients
    ) public {
        _createRecipientBitMap(channelId, _recipients);
    }

    function exPairRecipientAndPackage(
        uint256 channelId,
        address _recipient,
        uint256 _packageIndex,
        bool recieverStillEligible
    ) public {
        pairRecipientAndPackage(
            channelId,
            _recipient,
            _packageIndex,
            recieverStillEligible
        );
    }

    function exFlipRecipientBit(uint256 channelId, address _recipient) public {
        flipRecipientBit(channelId, _recipient);
    }

    function exFlipPackageBit(uint256 channelId, uint256 index) public {
        flipPackageBit(channelId, index);
    }

    function exChangeStatus(uint256 channelId, Status newStatus) public {
        changeStatus(channelId, newStatus);
    }

    // Channel Helper
    function exSetChannelSize(uint256 channelId, uint256 size) public {
        channels[channelId].size = size;
    }

    /*//////////////////////////////////////////////////////////////
                                 TOKEN TRANSFERER
    //////////////////////////////////////////////////////////////*/

    function exDepositPackages(
        PackageItem[] calldata packages,
        address to,
        address from,
        uint256 ethValue
    ) public payable returns (bool success) {
        return depositPackages(packages, to, from, ethValue);
    }

    function exDistributePackage(PackageItem calldata item, address to)
        public
        returns (bool success)
    {
        return distributePackage(item, to);
    }

    function exDistributePackagesForCancel(
        PackageItem[] calldata items,
        address to
    ) public returns (bool success) {
        return distributePackagesForCancel(items, to);
    }

    function exDigestPackageDeposit(
        PackageItem calldata item,
        address to,
        address from
    ) public returns (bool success) {
        return digestPackageDeposit(item, to, from);
    }

    function exDigestPackageDistribute(
        PackageItem calldata item,
        address payable to
    ) public returns (bool success) {
        return digestPackageDistribute(item, to);
    }

    function exTransferERC20(
        PackageItem memory item,
        address to,
        address from
    ) public returns (bool success) {
        success = transferERC20(item, to, from);
    }

    function exTransferERC20Out(PackageItem memory item, address to)
        public
        returns (bool success)
    {
        success = transferERC20Out(item, to);
    }

    function exTransferERC721(
        PackageItem memory item,
        address to,
        address from
    ) public returns (bool success) {
        success = transferERC721(item, to, from);
    }

    function exTransferERC1155(
        PackageItem memory item,
        address to,
        address from
    ) public returns (bool success) {
        success = transferERC1155(item, to, from);
    }
}
