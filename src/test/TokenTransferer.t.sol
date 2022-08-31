pragma solidity ^0.8.14;

import "ds-test/test.sol";
import "./mocks/Suicide.sol";
import {Configs} from "./utils/Configs.sol";
import {ItemType, PackageItem} from "@contracts/lib/StructsAndEnums.sol";
import {Errors} from "@contracts/interfaces/Errors.sol";

contract TokenTransfererTest is Configs {
    function testBalances() public {
        // ERC20
        assertEq(token.balanceOf(organizer), tokenMintedTotal);

        // ERC721
        assertEq(nft.balanceOf(organizer), nftMintedTotal);

        // ERC1155
        assertEq(multiToken.balanceOf(organizer, 0), multiTokenTotal);
        assertEq(multiToken.balanceOf(organizer, 1), multiTokenTotal);
        assertEq(multiToken.balanceOf(organizer, 2), multiTokenTotal);
        assertEq(multiToken.balanceOf(organizer, 3), multiTokenTotal);
        assertEq(multiToken.balanceOf(organizer, 4), multiTokenTotal);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                DEPOSITS
    //////////////////////////////////////////////////////////////////////////*/

    // ETH
    function testETHDeposits() public {
        cheats.startPrank(organizer);
        uint256 bal = address(organizer).balance;
        assertEq(address(god).balance, 0);
        createMockRecipientsAndPackages(
            2,
            2,
            2 ether,
            ItemType.NATIVE,
            address(0x0)
        );

        ex.exDepositPackages{value: 4 ether}(packages, god, organizer, 4 ether);
        cheats.stopPrank();

        // Eth is sent to ex, normally its sent to factory
        assertEq(address(ex).balance, 4 ether);
        assertEq(bal - 4 ether, address(organizer).balance);
    }

    // ERC20
    function testERC20Deposits() public {
        cheats.startPrank(organizer);
        assertEq(token.balanceOf(organizer), tokenMintedTotal);
        assertEq(token.balanceOf(god), 0);

        token.approve(address(ex), 100);
        ex.exDepositPackages(packages, god, organizer, 0);
        cheats.stopPrank();

        assertEq(token.balanceOf(god), 20);
        assertEq(
            token.balanceOf(organizer),
            tokenMintedTotal - (packagesLength * tokenAmountPerPackage)
        );
    }

    // ERC721
    function testER721Deposits() public {
        cheats.startPrank(organizer);
        assertEq(nft.balanceOf(organizer), nftMintedTotal);

        createMockRecipientsAndPackages(2, 2, 2, ItemType.ERC721, address(nft));
        assertEq(nft.balanceOf(god), 0);

        nft.setApprovalForAll(address(ex), true);
        ex.exDepositPackages(packages, god, organizer, 0);
        cheats.stopPrank();

        assertEq(nft.balanceOf(god), 2);
        assertEq(
            nft.balanceOf(organizer),
            nftMintedTotal - tokenAmountPerPackage
        );
    }

    // ERC1155
    function testERC1155Deposits() public {
        cheats.startPrank(organizer);
        assertEq(multiToken.balanceOf(organizer, 0), multiTokenTotal);
        assertEq(multiToken.balanceOf(organizer, 1), multiTokenTotal);

        createMockRecipientsAndPackages(
            2,
            2,
            5,
            ItemType.ERC1155,
            address(multiToken)
        );
        assertEq(multiToken.balanceOf(address(ex), 0), 0);
        assertEq(multiToken.balanceOf(address(ex), 1), 0);

        multiToken.setApprovalForAll(address(ex), true);
        ex.exDepositPackages(packages, address(ex), organizer, 0);
        cheats.stopPrank();

        assertEq(multiToken.balanceOf(address(ex), 0), 5);
        assertEq(multiToken.balanceOf(address(ex), 1), 5);
        assertEq(multiToken.balanceOf(organizer, 0), multiTokenTotal - 5);
        assertEq(multiToken.balanceOf(organizer, 1), multiTokenTotal - 5);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                DISTRIBUTES
    //////////////////////////////////////////////////////////////////////////*/

    // ETH
    // Acutally just sending eth from Basin to God, organizer not needed really
    function testETHDistrubutes() public {
        cheats.deal(address(ex), 10 ether);
        cheats.startPrank(organizer);
        uint256 bal = address(ex).balance;
        assertEq(address(god).balance, 0);
        createMockRecipientsAndPackages(
            2,
            2,
            2 ether,
            ItemType.NATIVE,
            address(0x0)
        );

        ex.exDistributePackage(packages[0], god);
        cheats.stopPrank();

        // Eth is sent to ex, normally its sent to factory
        assertEq(address(god).balance, 2 ether);
        assertEq(bal - 2 ether, address(ex).balance);
    }

    // ERC20
    function testERC20Distributes() public {
        address empty = address(0xb0b);
        address exAddr = address(ex);
        assertEq(token.balanceOf(empty), 0);

        cheats.startPrank(organizer);
        token.approve(address(ex), 1000);
        ex.exDepositPackages(packages, exAddr, organizer, 0);
        assertEq(
            token.balanceOf(organizer),
            tokenMintedTotal - 2 * tokenAmountPerPackage
        );

        ex.exDistributePackage(packages[0], empty);

        assertEq(token.balanceOf(empty), tokenAmountPerPackage);
        assertEq(token.balanceOf(exAddr), tokenAmountPerPackage);

        ex.exDistributePackage(packages[1], empty);

        assertEq(token.balanceOf(empty), 2 * tokenAmountPerPackage);
        assertEq(token.balanceOf(exAddr), 0);
    }

    // ERC721
    function testERC721Distributes() public {
        address empty = address(0xb0b);
        address exAddr = address(ex);

        cheats.startPrank(organizer);
        assertEq(nft.balanceOf(organizer), nftMintedTotal);

        createMockRecipientsAndPackages(2, 2, 2, ItemType.ERC721, address(nft));
        assertEq(nft.balanceOf(empty), 0);

        nft.setApprovalForAll(exAddr, true);
        ex.exDepositPackages(packages, address(ex), organizer, 0);
        cheats.stopPrank();

        assertEq(
            nft.balanceOf(organizer),
            nftMintedTotal - tokenAmountPerPackage
        );

        ex.exDistributePackage(packages[0], empty);

        assertEq(nft.balanceOf(empty), 1);
        assertEq(nft.balanceOf(exAddr), 1);

        ex.exDistributePackage(packages[1], empty);

        assertEq(nft.balanceOf(empty), tokenAmountPerPackage);
        assertEq(nft.balanceOf(exAddr), 0);
    }

    // ERC1155
    function testERC1155Distributes() public {
        address empty = address(0xb0b);
        address exAddr = address(ex);

        cheats.startPrank(organizer);
        assertEq(multiToken.balanceOf(organizer, 0), multiTokenTotal);
        assertEq(multiToken.balanceOf(organizer, 1), multiTokenTotal);

        createMockRecipientsAndPackages(
            2,
            2,
            5,
            ItemType.ERC1155,
            address(multiToken)
        );
        assertEq(multiToken.balanceOf(address(ex), 0), 0);
        assertEq(multiToken.balanceOf(address(ex), 1), 0);

        multiToken.setApprovalForAll(address(ex), true);
        ex.exDepositPackages(packages, address(ex), organizer, 0);
        ex.exDistributePackage(packages[0], empty);

        assertEq(multiToken.balanceOf(empty, 0), 5);
        assertEq(multiToken.balanceOf(exAddr, 0), 0);

        ex.exDistributePackage(packages[1], empty);
        assertEq(multiToken.balanceOf(empty, 1), 5);
        assertEq(multiToken.balanceOf(exAddr, 1), 0);

        cheats.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                DISTRIBUTE FOR CANCEL
    //////////////////////////////////////////////////////////////////////////*/

    // ETH
    function testETHDistributesForCancel() public {
        cheats.deal(address(ex), 10 ether);
        cheats.startPrank(organizer);
        uint256 bal = address(ex).balance;
        assertEq(address(god).balance, 0);
        createMockRecipientsAndPackages(
            2,
            2,
            2 ether,
            ItemType.NATIVE,
            address(0x0)
        );

        ex.exDistributePackagesForCancel(packages, god);
        cheats.stopPrank();

        // Eth is sent to ex, normally its sent to factory
        assertEq(address(god).balance, 4 ether);
        assertEq(bal - 4 ether, address(ex).balance);
    }

    // ERC20
    function testERC20DistributesForCancel() public {
        address empty = address(0xb0b);
        address exAddr = address(ex);
        assertEq(token.balanceOf(empty), 0);

        cheats.startPrank(organizer);
        token.approve(address(ex), 1000);
        ex.exDepositPackages(packages, exAddr, organizer, 0);
        assertEq(
            token.balanceOf(organizer),
            tokenMintedTotal - 2 * tokenAmountPerPackage
        );

        ex.exDistributePackagesForCancel(packages, empty);

        assertEq(token.balanceOf(empty), 2 * tokenAmountPerPackage);
        assertEq(token.balanceOf(exAddr), 0);
    }

    // ERC721
    function testERC721DistributesForCancel() public {
        address empty = address(0xb0b);
        address exAddr = address(ex);

        cheats.startPrank(organizer);
        assertEq(nft.balanceOf(organizer), nftMintedTotal);

        createMockRecipientsAndPackages(2, 2, 2, ItemType.ERC721, address(nft));
        assertEq(nft.balanceOf(empty), 0);

        nft.setApprovalForAll(exAddr, true);
        ex.exDepositPackages(packages, address(ex), organizer, 0);
        cheats.stopPrank();

        assertEq(
            nft.balanceOf(organizer),
            nftMintedTotal - tokenAmountPerPackage
        );

        ex.exDistributePackagesForCancel(packages, empty);

        assertEq(nft.balanceOf(empty), tokenAmountPerPackage);
        assertEq(nft.balanceOf(exAddr), 0);
    }

    // ERC1155
    function testERC1155DistributesForCancel() public {
        address empty = address(0xb0b);
        address exAddr = address(ex);

        cheats.startPrank(organizer);
        assertEq(multiToken.balanceOf(organizer, 0), multiTokenTotal);
        assertEq(multiToken.balanceOf(organizer, 1), multiTokenTotal);

        createMockRecipientsAndPackages(
            2,
            2,
            5,
            ItemType.ERC1155,
            address(multiToken)
        );
        assertEq(multiToken.balanceOf(address(ex), 0), 0);
        assertEq(multiToken.balanceOf(address(ex), 1), 0);

        multiToken.setApprovalForAll(address(ex), true);
        ex.exDepositPackages(packages, address(ex), organizer, 0);
        ex.exDistributePackagesForCancel(packages, empty);

        assertEq(multiToken.balanceOf(empty, 1), 5);
        assertEq(multiToken.balanceOf(exAddr, 1), 0);

        cheats.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                DEPOSITS DIGEST
    //////////////////////////////////////////////////////////////////////////*/

    // ETH
    function testETHDepositsDigest() public {
        cheats.startPrank(organizer);
        uint256 bal = address(organizer).balance;
        assertEq(address(god).balance, 0);
        createMockRecipientsAndPackages(
            2,
            2,
            2 ether,
            ItemType.NATIVE,
            address(0x0)
        );

        cheats.expectRevert(
            abi.encodeWithSelector(
                Errors.TokenTransferer__InvalidTokenType.selector,
                packages[0]
            )
        );
        bool success = ex.exDigestPackageDeposit(packages[0], god, organizer);
        cheats.stopPrank();
    }

    // ERC20
    function testERC20DepositsDigest() public {
        createMockRecipientsAndPackages(
            2,
            2,
            tokenAmountPerPackage,
            ItemType.ERC20,
            address(token)
        );

        cheats.startPrank(organizer);
        assertEq(token.balanceOf(organizer), tokenMintedTotal);
        assertEq(token.balanceOf(god), 0);

        token.approve(address(ex), 100);

        bool success = ex.exDigestPackageDeposit(packages[0], god, organizer);
        assert(success);

        // Eth is sent to ex, normally its sent to factory
        assertEq(
            token.balanceOf(organizer),
            tokenMintedTotal - tokenAmountPerPackage
        );
        assertEq(token.balanceOf(god), tokenAmountPerPackage);
        cheats.stopPrank();
    }

    // ERC721
    function testERC721DepositsDigest() public {
        createMockRecipientsAndPackages(2, 2, 1, ItemType.ERC721, address(nft));

        cheats.startPrank(organizer);
        assertEq(nft.balanceOf(organizer), nftMintedTotal);
        assertEq(nft.balanceOf(god), 0);

        nft.setApprovalForAll(address(ex), true);

        bool success = ex.exDigestPackageDeposit(packages[0], god, organizer);
        assert(success);

        assertEq(nft.balanceOf(god), 1);
        assertEq(nft.balanceOf(organizer), nftMintedTotal - 1);
        cheats.stopPrank();
    }

    // ERC1155
    function testERC1155DepositsDigest() public {
        createMockRecipientsAndPackages(
            2,
            2,
            5,
            ItemType.ERC1155,
            address(multiToken)
        );

        cheats.startPrank(organizer);
        assertEq(multiToken.balanceOf(organizer, 0), multiTokenTotal);
        assertEq(multiToken.balanceOf(god, 0), 0);

        multiToken.setApprovalForAll(address(ex), true);

        bool success = ex.exDigestPackageDeposit(packages[0], god, organizer);
        assert(success);

        assertEq(multiToken.balanceOf(god, 0), 5);
        assertEq(multiToken.balanceOf(organizer, 0), multiTokenTotal - 5);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                DISTRIBUTE DIGEST
    //////////////////////////////////////////////////////////////////////////*/

    // ETH
    function testETHDistributesDigest() public {
        cheats.deal(address(ex), 10 ether);
        cheats.startPrank(organizer);
        uint256 bal = address(organizer).balance;
        assertEq(address(god).balance, 0);
        createMockRecipientsAndPackages(
            2,
            2,
            2 ether,
            ItemType.NATIVE,
            address(0x0)
        );
        bool success = ex.exDigestPackageDistribute(packages[0], payable(god));
        cheats.stopPrank();
        assertEq(address(god).balance, 2 ether);
        assertEq(address(ex).balance, 8 ether);
    }

    // ERC20
    function testERC20DistributesDigest() public {
        address empty = address(0xb0b);
        address exAddr = address(ex);
        assertEq(token.balanceOf(empty), 0);

        cheats.startPrank(organizer);
        token.approve(address(ex), 1000);
        ex.exDepositPackages(packages, exAddr, organizer, 0);
        assertEq(
            token.balanceOf(organizer),
            tokenMintedTotal - 2 * tokenAmountPerPackage
        );

        ex.exDigestPackageDistribute(packages[0], payable(empty));

        assertEq(token.balanceOf(empty), tokenAmountPerPackage);
        assertEq(token.balanceOf(exAddr), tokenAmountPerPackage);

        ex.exDigestPackageDistribute(packages[1], payable(empty));

        assertEq(token.balanceOf(empty), 2 * tokenAmountPerPackage);
        assertEq(token.balanceOf(exAddr), 0);
    }

    // ERC721
    function testERC721DistributesDigest() public {
        address empty = address(0xb0b);
        address exAddr = address(ex);

        cheats.startPrank(organizer);
        assertEq(nft.balanceOf(organizer), nftMintedTotal);

        createMockRecipientsAndPackages(2, 2, 2, ItemType.ERC721, address(nft));
        assertEq(nft.balanceOf(empty), 0);

        nft.setApprovalForAll(exAddr, true);
        ex.exDepositPackages(packages, address(ex), organizer, 0);
        cheats.stopPrank();

        assertEq(
            nft.balanceOf(organizer),
            nftMintedTotal - tokenAmountPerPackage
        );

        ex.exDigestPackageDistribute(packages[0], payable(empty));

        assertEq(nft.balanceOf(empty), 1);
        assertEq(nft.balanceOf(exAddr), 1);

        ex.exDigestPackageDistribute(packages[1], payable(empty));

        assertEq(nft.balanceOf(empty), tokenAmountPerPackage);
        assertEq(nft.balanceOf(exAddr), 0);
    }

    // ERC1155
    function testERC1155DistributesDigest() public {
        address empty = address(0xb0b);
        address exAddr = address(ex);

        cheats.startPrank(organizer);
        assertEq(multiToken.balanceOf(organizer, 0), multiTokenTotal);
        assertEq(multiToken.balanceOf(organizer, 1), multiTokenTotal);

        createMockRecipientsAndPackages(
            2,
            2,
            5,
            ItemType.ERC1155,
            address(multiToken)
        );
        assertEq(multiToken.balanceOf(address(ex), 0), 0);
        assertEq(multiToken.balanceOf(address(ex), 1), 0);

        multiToken.setApprovalForAll(address(ex), true);
        ex.exDepositPackages(packages, address(ex), organizer, 0);
        ex.exDigestPackageDistribute(packages[0], payable(empty));

        assertEq(multiToken.balanceOf(empty, 0), 5);
        assertEq(multiToken.balanceOf(exAddr, 0), 0);

        ex.exDigestPackageDistribute(packages[1], payable(empty));
        assertEq(multiToken.balanceOf(empty, 1), 5);
        assertEq(multiToken.balanceOf(exAddr, 1), 0);

        cheats.stopPrank();
    }

    // ERROR

    /*//////////////////////////////////////////////////////////////////////////
                                TRANSFERS
    //////////////////////////////////////////////////////////////////////////*/

    // ERC20

    function testERC20Transfer() public {
        address empty = address(0xb0b);
        PackageItem memory item = PackageItem({
            itemType: ItemType.ERC20,
            token: address(token),
            identifier: 0,
            amount: 10
        });
        allApprovals(organizer, ItemType.ERC20, address(ex));
        bool success = ex.exTransferERC20(item, address(empty), organizer);
        assert(success);
        assertEq(token.balanceOf(empty), 10);
    }

    // ERC20 Out
    function testERC20Out() public {
        address empty = address(0xb0b);
        delegateTokens(address(ex), ItemType.ERC20, 100, 0, 0);
        PackageItem memory item = PackageItem({
            itemType: ItemType.ERC20,
            token: address(token),
            identifier: 0,
            amount: 10
        });
        bool success = ex.exTransferERC20Out(item, address(empty));
        assert(success);
        assertEq(token.balanceOf(empty), 10);
    }

    // ERC721
    function testERC721Transfer() public {
        address empty = address(0xb0b);
        PackageItem memory item = PackageItem({
            itemType: ItemType.ERC721,
            token: address(nft),
            identifier: 1,
            amount: 1
        });
        allApprovals(organizer, ItemType.ERC721, address(ex));
        bool success = ex.exTransferERC721(item, address(empty), organizer);
        assert(success);
        assertEq(nft.balanceOf(empty), 1);
    }

    // ERC1155
    function testERC1155Transfer() public {
        address empty = address(0xb0b);
        PackageItem memory item = PackageItem({
            itemType: ItemType.ERC1155,
            token: address(multiToken),
            identifier: 1,
            amount: 10
        });
        allApprovals(organizer, ItemType.ERC1155, address(ex));
        bool success = ex.exTransferERC1155(item, address(empty), organizer);
        assert(success);
        assertEq(multiToken.balanceOf(empty, 1), 10);
    }

    // ERROR

    /*//////////////////////////////////////////////////////////////////////////
                                SUICIDES
    //////////////////////////////////////////////////////////////////////////*/

    function testSuicideERC() public {
        Suicide death = new Suicide();
        address deathAddr = address(death);
        address exAddr = address(ex);
        assertEq(token.balanceOf(deathAddr), 0);

        cheats.startPrank(organizer);
        token.approve(address(ex), 1000);

        ex.exDepositPackages(packages, exAddr, organizer, 0);

        assertEq(
            token.balanceOf(organizer),
            tokenMintedTotal - 2 * tokenAmountPerPackage
        );

        ex.exDistributePackage(packages[0], deathAddr);

        assertEq(token.balanceOf(deathAddr), tokenAmountPerPackage);
        assertEq(token.balanceOf(exAddr), tokenAmountPerPackage);

        ex.exDistributePackage(packages[1], deathAddr);

        assertEq(token.balanceOf(deathAddr), 2 * tokenAmountPerPackage);
        assertEq(token.balanceOf(exAddr), 0);
    }

    function testSuicideETH() public {
        Suicide death = new Suicide();
        address deathAddr = address(death);
        address exAddr = address(ex);

        cheats.deal(organizer, 10 ether);
        assertEq(address(organizer).balance, 10 ether);

        createMockRecipientsAndPackages(
            2,
            2,
            1 ether,
            ItemType.NATIVE,
            address(0x0)
        );

        cheats.startPrank(organizer);

        ex.exDepositPackages{value: 2 ether}(
            packages,
            exAddr,
            organizer,
            2 ether
        );
        assertEq(address(ex).balance, 2 ether);

        ex.exDistributePackage(packages[0], deathAddr);

        // This commented out will fail, recieve self destructs and returns eth
        // assertEq(address(deathAddr).balance, 1 ether);

        // Need to confirm how this will affect the channel contract
        assertEq(address(exAddr).balance, 2 ether);

        assertEq(address(organizer).balance, 8 ether);
    }
}

// function testERC20Deposit() public {
//     cheats.startPrank(organizer);
//     assertEq(token.balanceOf(organizer), tokenMintedTotal);
//     assertEq(token.balanceOf(god), 0);

//     token.approve(address(ex), 100);
//     ex.depositPackage(packages[0], god, organizer, 0);
//     cheats.stopPrank();

//     assertEq(token.balanceOf(god), 10);
//     assertEq(
//         token.balanceOf(organizer),
//         tokenMintedTotal - tokenAmountPerPackage
//     );
// }

// function testER721Deposit() public {
//     cheats.startPrank(organizer);
//     assertEq(nft.balanceOf(organizer), nftMintedTotal);

//     createMockRecipientsAndPackages(2, 2, 2, ItemType.ERC721, address(nft));
//     assertEq(nft.balanceOf(god), 0);

//     nft.setApprovalForAll(address(ex), true);
//     ex.depositPackage(packages[0], god, organizer, 0);
//     cheats.stopPrank();

//     assertEq(nft.balanceOf(god), 1);
//     assertEq(nft.balanceOf(organizer), nftMintedTotal - 1);
// }

// function testERC1155Deposit() public {
//     cheats.startPrank(organizer);
//     assertEq(multiToken.balanceOf(organizer, 0), multiTokenTotal);
//     assertEq(multiToken.balanceOf(organizer, 1), multiTokenTotal);

//     createMockRecipientsAndPackages(
//         2,
//         2,
//         5,
//         ItemType.ERC1155,
//         address(multiToken)
//     );
//     assertEq(multiToken.balanceOf(address(ex), 0), 0);
//     assertEq(multiToken.balanceOf(address(ex), 1), 0);

//     multiToken.setApprovalForAll(address(ex), true);
//     ex.depositPackage(packages[0], address(ex), organizer, 0);
//     cheats.stopPrank();

//     assertEq(multiToken.balanceOf(address(ex), 0), 5);
//     assertEq(multiToken.balanceOf(organizer, 0), multiTokenTotal - 5);
//     assertEq(multiToken.balanceOf(organizer, 1), multiTokenTotal);
// }
