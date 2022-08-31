// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.14;

import {ERC721} from "@solmate/tokens/ERC721.sol";

contract MockERC721 is ERC721 {
    constructor() ERC721("MockNFT", "NFT") {}

    function tokenURI(uint256)
        public
        pure
        virtual
        override
        returns (string memory)
    {
        return "TokenURI";
    }

    function mint(address to, uint256 tokenId) public virtual {
        _mint(to, tokenId);
    }

    function burn(uint256 tokenId) public virtual {
        _burn(tokenId);
    }

    function safeMint(address to, uint256 tokenId) public virtual {
        _safeMint(to, tokenId);
    }

    function safeMint(
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual {
        _safeMint(to, tokenId, data);
    }
}
