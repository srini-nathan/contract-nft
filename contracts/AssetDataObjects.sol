// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;
pragma experimental ABIEncoderV2;

// Interfaces
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

contract AssetDataObjects {
    enum Status {created, minted, listed, unListed, sold}

    struct AssetNFT {
        string _ipfsHash; 
        address _ownerAddress;
        uint _assetPrice;
        Status _status; 
    }
}
