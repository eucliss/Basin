pragma solidity ^0.8.14;

// import "ds-test/test.sol";
// import {CheatCodes} from "../utils/CheatCodes.sol";
import "@std/console.sol";
import "../mocks/MockERC20.sol";
import "../mocks/MockERC721.sol";
import "../mocks/MockERC1155.sol";

contract TokenInitializer {
    MockERC20 public token;
    MockERC721 public nft;
    MockERC1155 public multiToken;
    address immutable god = address(0xdead);
    uint256[] internal ids;
    uint256[] internal amts;
    uint256 public multiTokenCreated = 5000;
    uint256 public multiTokenIdNumber = 10;

    constructor() {
        token = new MockERC20();
        nft = new MockERC721();
        multiToken = new MockERC1155();
        _helperBatchMint();
    }

    function bulkMintInit(
        address recipient,
        uint256 tokenAmount,
        uint256 nftAmount
    ) public {
        bool success = token.transfer(recipient, tokenAmount);
        require(success, "Token transfer failed");

        for (uint256 i = 0; i < nftAmount; i++) {
            nft.safeMint(recipient, i, "");
        }

        multiToken.batchMint(recipient, ids, amts, "");
    }

    function bulkTransfer(
        address recipient,
        uint256 tokenAmount,
        uint256 nftAmount,
        uint256 multiNumber,
        uint256 multiAmount
    ) public {
        bool success = token.transferFrom(msg.sender, recipient, tokenAmount);
        require(success, "Token transfer failed");

        for (uint256 i = 0; i < nftAmount; i++) {
            nft.safeTransferFrom(msg.sender, recipient, i, "");
        }

        for (uint256 l = 0; l < multiNumber; l++) {
            multiToken.safeTransferFrom(
                msg.sender,
                recipient,
                l,
                multiAmount,
                ""
            );
        }
    }

    function _helperBatchMint() public {
        for (uint256 i = 0; i < multiTokenIdNumber; i++) {
            ids.push(i);
            amts.push(multiTokenCreated);
        }
    }
}
