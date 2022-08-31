pragma solidity ^0.8.0;

enum ItemType {
    NATIVE,
    ERC20,
    ERC721,
    ERC1155,
    NONE
}

enum Status {
    Open,
    Started,
    Completed
}

struct ChannelStruct {
    bytes32 hash;
    address controller;
    uint256 size;
    bytes32 recipients;
    bytes32 packages;
    uint256 id;
    Status channelStatus;
}

struct ChannelDetails {
    address[] players;
    uint32[] payouts;
    uint prizepool;
}

struct RecipientStatus {
    bool placed;
    uint32 place;
    uint payout;
    bool eligible;
}

struct PackageItem {
    ItemType itemType;
    address token;
    uint256 identifier;
    uint256 amount;
}

struct EligibleRecipient {
    bool eligible;
    bool accepted;
    bool deposited;
    bool payoutDepositRequired;
    PackageItem deposit;
}