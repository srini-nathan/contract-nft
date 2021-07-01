//SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./AssetDriving.sol";
import "./EnumerableMap.sol";

contract AssetMarketPlace is ERC721Holder, Ownable, Pausable {
    using EnumerableMap for EnumerableMap.UintToUintMap;
    using EnumerableSet for EnumerableSet.UintSet;

    EnumerableMap.UintToUintMap private listings;

    address payable public _casimir;

    AssetDriving private engine;
    IERC721 public nft;

    mapping(address => bool) public actionAllowed;
    mapping(address => EnumerableSet.UintSet) private _userSellingTokens;

    struct Listing {
        uint256 tokenId;
        uint256 price;
    }

    modifier listingExists(uint256 _tokenId) {
        require(listings.contains(_tokenId), "listing doesnt exist");
        _;
    }

    event SellingSuccess(uint256 price, uint256 id, address seller, address buyer);

    constructor(
        address _engine,
        address _nft,
        address payable casimir
    ) {
        require(_nft != address(0), "Invalid Address");
        nft = IERC721(_nft);
        engine = AssetDriving(_engine);
        _casimir = casimir;
        actionAllowed[msg.sender] = true;
    }

    function putToSell(uint256 _tokenId, uint256 _price) public virtual whenNotPaused {
        require(!listings.contains(_tokenId), "listing already exists");
        require(msg.sender == nft.ownerOf(_tokenId), "It is not your token");
        require(msg.sender != address(0), "invalid Address");
        nft.approve(address(this), _tokenId);
        engine.putToSell(_tokenId, _price);
        listings.set(_tokenId, _price);
        _userSellingTokens[msg.sender].add(_tokenId);
    }

    function changeSellingPrice(uint256 _tokenId, uint256 _newPrice) public listingExists(_tokenId) whenNotPaused {
        require(msg.sender == nft.ownerOf(_tokenId), "It is not your token");
        require(msg.sender != address(0), "invalid Address");
        engine.changeSellingPrice(_tokenId, _newPrice);
        listings.set(_tokenId, _newPrice);
    }

    function cancelSelling(uint256 _tokenId) public virtual {
        require(listings.contains(_tokenId), "Non existant token");
        require(msg.sender == nft.ownerOf(_tokenId), "It is not your token");
        require(msg.sender != address(0), "invalid Address");
        nft.approve(address(0), _tokenId);
        engine.cancelSelling(_tokenId);
        listings.remove(_tokenId);
         _userSellingTokens[msg.sender].remove(_tokenId);
    }

    function buyNFT(uint256 _tokenId) public payable virtual whenNotPaused {
        require(listings.contains(_tokenId), "Non existant token");
        require(msg.sender != nft.ownerOf(_tokenId), "It is your token");
        require(msg.sender != address(0), "invalid Address");
        require(msg.value == listings.get(_tokenId), "Not the price");

        engine.cancelSelling(_tokenId);
        listings.remove(_tokenId);
          _userSellingTokens[nft.ownerOf(_tokenId)].remove(_tokenId);
        /// Bought-amount is transferred into a seller wallet and the fee to EuraNov
        payable(nft.ownerOf(_tokenId)).transfer((msg.value * 97) / 100);
        _casimir.transfer((msg.value * 3) / 100);

        emit SellingSuccess(msg.value, _tokenId, nft.ownerOf(_tokenId), msg.sender);

        /// safeTransfer to the buyer address
        //this.safeTransferFrom(nft.ownerOf(_tokenId), msg.sender, _tokenId);
        nft.safeTransferFrom(address(this), msg.sender, _tokenId);
    }

    function isToSell(uint256 _tokenId) public view virtual returns (bool) {
        return engine.isToSell(_tokenId);
    }

    function getPrice(uint256 _tokenId) public view returns (uint256) {
        return engine.getPrice(_tokenId);
    }

    function updateEngine(address _engine) external onlyOwner {
        engine = AssetDriving(_engine);
    }

    function registerMember(address _club) external onlyOwner {
        actionAllowed[_club] = true;
    }

    function cancelMember(address _club) external onlyOwner {
        actionAllowed[_club] = false;
    }

    function pauseContract() external onlyOwner {
        _pause();
    }

    function unpauseContract() external onlyOwner {
        _unpause();
    }

    function totalListings() public view returns (uint256) {
        return listings.length();
    }

    function getAllListings() public view returns (Listing[] memory) {
        Listing[] memory list = new Listing[](listings.length());
        for (uint256 i = 0; i < listings.length(); i++) {
            (uint256 tokenId, uint256 price) = listings.at(i);
            list[i] = Listing({ tokenId: tokenId, price: price });
        }
        return list;
    }

    function getAllListingsInReverse() public view returns (Listing[] memory) {
        Listing[] memory list = new Listing[](listings.length());
        for (uint256 i = listings.length(); i > 0; i--) {
            (uint256 tokenId, uint256 price) = listings.at(i);
            list[listings.length() - i] = Listing({ tokenId: tokenId, price: price });
        }

        return list;
    }

    function getListingsByUser(address user) public view returns (Listing[] memory) {
        Listing[] memory list = new Listing[](_userSellingTokens[user].length());
        for (uint256 i = 0; i < _userSellingTokens[user].length(); i++) {
            uint256 tokenId = _userSellingTokens[user].at(i);
            uint256 price = listings.get(tokenId);
            list[i] = Listing({ tokenId: tokenId, price: price });
        }
        return list;
    }
}
