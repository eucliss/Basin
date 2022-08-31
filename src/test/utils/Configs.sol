// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// Test contracts
import "ds-test/test.sol";
import "./Exposed.sol";
import "../mocks/MockERC721.sol";
import "../mocks/MockERC20.sol";
import "../mocks/MockERC1155.sol";
import {TokenInitializer} from "./TokenInitializer.sol";
import {Vm} from "@std/Vm.sol";
import "../mocks/Suicide.sol";

// Custom Contracts
import "@contracts/lib/StructsAndEnums.sol";
import "@contracts/Basin.sol";
import "@contracts/utils/Channel.sol";
import {Errors} from "@contracts/interfaces/Errors.sol";
import {Events} from "@contracts/interfaces/Events.sol";
import {ChannelEventsAndErrors} from "@contracts/interfaces/ChannelEventsAndErrors.sol";

import {ItemType} from "@contracts/lib/StructsAndEnums.sol";

contract Configs is DSTest, Errors, Events, ChannelEventsAndErrors {
    Vm public cheats = Vm(HEVM_ADDRESS);

    Exposed public ex;
    MockERC20 public token;
    MockERC721 public nft;
    MockERC1155 public multiToken;
    TokenInitializer public tInit;
    TokenTransferer public router;
    Basin public basin;
    Channel public channel;

    PackageItem[] public packages;
    PackageItem public emptyItem =
        PackageItem(ItemType.NONE, address(0x0), 0, 0);

    address public constant DEPLOYER =
        0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;
    address public organizer = address(420);
    address public newBeneficary = address(0xB0B);
    address immutable god = address(0xdead);
    address public channelAddress;
    address public basinAddress;
    address payable public owner = payable(address(0x6969696969));
    address[] public recipients;
    // address payable public beneficiary = payable(address(0x6969696969));

    /*
     *      MAGIC NUMBERS OOOOOH
     */
    uint256 public tokenMintedTotal = 100000;
    uint256 public basinTokenBalance = 10000;
    uint256 public nftMintedTotal = 50;
    uint256 public multiTokenTotal = 1000;
    uint256 public erc20ItemAmount = 1000;
    uint256 public newRecipientCount = 0;

    uint256 channelId;
    uint256 public tokenAmountPerPackage;
    uint256 public recipientsLength;
    uint256 public packagesLength;
    uint256 public channelSize;
    uint256 public generateSalt = 0;
    uint256 public fee = 0.001 ether;

    bool[] public packagesRequired;

    mapping(ItemType => address) itemTypeMap;

    constructor() {
        _initContracts();
        _setItemTypeMap();
        cheats.deal(organizer, 10 ether);
        createMockRecipientsAndPackages(
            2,
            2,
            10,
            ItemType.ERC20,
            address(token)
        );
    }

    function _initContracts() public {
        ex = new Exposed();
        tInit = new TokenInitializer();
        tInit.bulkMintInit(organizer, tokenMintedTotal, nftMintedTotal);
        token = tInit.token();
        nft = tInit.nft();
        multiToken = tInit.multiToken();
        multiTokenTotal = tInit.multiTokenCreated();
        router = new TokenTransferer();

        assertEq(token.balanceOf(organizer), tokenMintedTotal);
        assertEq(nft.balanceOf(organizer), nftMintedTotal);
        assertEq(multiToken.balanceOf(organizer, 0), multiTokenTotal);
        assertEq(multiToken.balanceOf(organizer, 1), multiTokenTotal);
    }

    function _setItemTypeMap() public {
        itemTypeMap[ItemType.NATIVE] = address(0x0);
        itemTypeMap[ItemType.ERC20] = address(token);
        itemTypeMap[ItemType.ERC721] = address(nft);
        itemTypeMap[ItemType.ERC1155] = address(multiToken);
    }

    function _setupApprovals(address approve, uint256 balance) public {
        cheats.startPrank(organizer);
        token.approve(approve, balance);
        assertEq(token.allowance(organizer, approve), balance);
        cheats.stopPrank();
    }

    function createMockRecipientsAndPackages(
        uint256 recipients_num,
        uint256 packages_num,
        uint256 tokenAmounts,
        ItemType itemType,
        address tokenAddr
    ) public {
        tokenAmountPerPackage = tokenAmounts;
        recipientsLength = recipients_num;
        packagesLength = packages_num;
        resetRecipientsAndPackages();
        generateRecipients(recipients_num);
        generatePackages(packages_num, tokenAddr, tokenAmounts, itemType);
    }

    function generateRecipients(uint256 number) public {
        delete recipients;
        for (uint256 i = 0; i < number; i++) {
            recipients.push(address(uint160(i + 420 + generateSalt))); // Salt so not overwriding the precombiled addresses
        }
        generateSalt += 420;
    }

    function createDynamicPackagesRequired(uint256 number, bool val) public {
        for (uint256 i = 0; i < number; i++) {
            packagesRequired.push(val);
        }
    }

    function delegateTokens(
        address reciever,
        ItemType item,
        uint256 amount,
        uint256 nftID,
        uint256 mutliTokenID
    ) public {
        if (item == ItemType.NATIVE) {
            cheats.deal(reciever, amount);
        }
        if (item == ItemType.ERC20) {
            cheats.prank(organizer);
            token.mint(reciever, 100);
        }
        if (item == ItemType.ERC721) {
            cheats.prank(organizer);
            nft.transferFrom(organizer, reciever, nftID);
            assertEq(nft.ownerOf(nftID), reciever);
        }
        if (item == ItemType.ERC1155) {
            cheats.prank(organizer);
            multiToken.safeTransferFrom(
                organizer,
                reciever,
                mutliTokenID,
                amount,
                ""
            );
            assertEq(multiToken.balanceOf(reciever, mutliTokenID), amount);
        }
    }

    // struct PackageItem {
    //     ItemType itemType;
    //     address token;
    //     uint256 identifier;
    //     uint256 amount;
    // }

    // function confirmOwnershipOfPackage(address addr, PackageItem item) public returns(bool) {
    //     assertEq
    // }

    function allApprovals(
        address from,
        ItemType item,
        address spender
    ) public {
        if (item == ItemType.ERC20) {
            cheats.startPrank(address(from));
            bool suc;
            suc = token.approve(address(spender), token.balanceOf(from));
            assert(suc);
            suc = token.approve(address(router), token.balanceOf(from));
            assert(suc);
            suc = token.approve(address(ex), token.balanceOf(from));
            assert(suc);
        }
        if (item == ItemType.ERC721) {
            cheats.startPrank(address(from));
            nft.setApprovalForAll(address(spender), true);
            nft.setApprovalForAll(address(router), true);
            nft.setApprovalForAll(address(ex), true);
        }
        if (item == ItemType.ERC1155) {
            cheats.startPrank(address(from));
            multiToken.setApprovalForAll(address(spender), true);
            multiToken.setApprovalForAll(address(router), true);
            multiToken.setApprovalForAll(address(ex), true);
        }
        cheats.stopPrank();
    }

    function newRecipient() public returns (address recipient) {
        recipient = address(uint160(newRecipientCount + 696969));
        newRecipientCount++;
    }

    function generatePackages(
        uint256 number,
        address tokenAddr,
        uint256 tokenAmounts,
        ItemType itemType
    ) public {
        delete packages;
        for (uint256 i = 0; i < number; i++) {
            packages.push(
                PackageItem({
                    itemType: itemType,
                    token: tokenAddr,
                    identifier: itemType == ItemType.ERC20 ||
                        itemType == ItemType.NATIVE
                        ? 0
                        : i,
                    amount: tokenAmounts
                })
            );
        }
    }

    function generateAllPackageTypesAndRecipients() public {
        resetRecipientsAndPackages();
        ItemType[4] memory items = [
            ItemType.NATIVE,
            ItemType.ERC20,
            ItemType.ERC721,
            ItemType.ERC1155
        ];

        for (uint256 i = 0; i < items.length; i++) {
            packages.push(
                PackageItem({
                    itemType: items[i],
                    token: itemTypeMap[items[i]],
                    identifier: items[i] == ItemType.ERC20 ||
                        items[i] == ItemType.NATIVE
                        ? 0
                        : 1,
                    amount: items[i] == ItemType.NATIVE ? (1 ether) : 1
                })
            );
        }
        generateRecipients(items.length);
    }

    function resetRecipientsAndPackages() public {
        delete packagesRequired;
        delete recipients;
        delete packages;
    }

    uint256 public oneEthPrize = 1 ether;
    uint256 public oneFiveEthPrize = 1.5 ether;
    uint256 public twoEthPrize = 2 ether;
    uint256 public oneGweiPrize = 1 gwei;

    function etherUnits() public pure {
        assert(1 wei == 1);
        assert(1 gwei == 1e9);
        assert(1 ether == 1e18);
        assert(1 == 1 seconds);
        assert(1 minutes == 60 seconds);
        assert(1 hours == 60 minutes);
        assert(1 days == 24 hours);
        assert(1 weeks == 7 days);
    }
}
