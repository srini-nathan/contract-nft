// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "./EnumerableMap.sol";
import "./AssetDriving.sol";

// Interfaces
import { AssetDataStorages } from "./AssetDataStorages.sol";

contract Asset is
    Context,
    AccessControlEnumerable,
    ERC721URIStorage,
    ERC721Burnable,
    ERC721Pausable,
    AssetDataStorages,
    Ownable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    // bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    // bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.UintToUintMap;

    EnumerableMap.UintToUintMap private listings;

    AssetDriving private engine;
    address payable public _casimir;

    mapping(uint256 => uint256) public tokenToAuction;
    mapping(address => uint256[]) internal myCollectableAssets;

    mapping(address => EnumerableSet.UintSet) private _userSellingTokens;

    string private _prefixURI;

    struct Listing {
        uint256 tokenId;
        uint256 price;
    }


    modifier listingExists(uint256 _tokenId) {
        require(listings.contains(_tokenId), "listing doesnt exist");
        _;
    }

    event MinterRoleGranted(address indexed beneficiary, address indexed caller);

    event MinterRoleRemoved(address indexed beneficiary, address indexed caller);

    event SellingSuccess(uint256 price, uint256 id, address seller, address buyer);

    constructor(
        string memory name,
        string memory symbol,
        string memory metadataBaseURI,
        address payable casimir,
        address _engine
    ) ERC721(name, symbol) {
        _prefixURI = metadataBaseURI;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _casimir = casimir;
        engine = AssetDriving(_engine);
    }

    // It holds the total number of assets.
    Counters.Counter internal _assetCounter;

    // It holds the total number of tokens minted.
    Counters.Counter internal _tokenCounter;

    // It holds the information about a asset.
    mapping(uint256 => AssetNFT) internal _assets;

    // // It holds which asset a token ID is in.
    // mapping(uint256 => uint256) internal _tokenAsset;

    // It holds a set of token IDs for an owner address.
    mapping(address => EnumerableSet.UintSet) internal _ownerTokenIDs;

    EnumerableMap.UintToUintMap private idToAssetIndex;
    EnumerableMap.UintToUintMap private indexToTokenId;

    Status public status;

    /* Modifiers */

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "AssetNFT: not admin");
        _;
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }

    /**
     * @notice Adds a new Asset to be minted with the given information.
     * @dev It auto increments the index of the next asset to add.
     *
     * Requirements:
     *  - Caller must have the {MINTER} role
     */
    function addAsset(
        uint256 _assetPrice,
        string memory _ipfsHash,
        uint256 assetIndex
    ) external {
        AssetNFT storage asset = _assets[assetIndex];

        asset._assetPrice = _assetPrice;
        asset._ipfsHash = _ipfsHash;
        asset._ownerAddress = msg.sender;

        asset._status = Status.created;
    }

    /**
     * @notice It returns information about a Asset for a token ID.
     * @param assetIndex AssetNFT assetIndex to get info.
     * @return asset_ the tier which belongs to the respective assetIndex
     */
    function getAssetNFT(uint256 assetIndex) external view returns (AssetNFT memory asset_) {
        asset_ = _assets[assetIndex];
    }

    function updateAssetNFTStatus(uint256 assetIndex, Status newStatus) internal {
        AssetNFT storage asset = _assets[assetIndex];
        asset._status = newStatus;
    }

    function updateAssetNFTPrice(uint256 assetIndex, uint256 newPrice) internal {
        AssetNFT storage asset = _assets[assetIndex];
        asset._assetPrice = newPrice;
    }

    function getAssetNFTStatus(uint256 assetIndex) external view returns (Status _status) {
        return _assets[assetIndex]._status;
    }

    /**
     * @notice It mints a new token for a Asset index.
     * @param assetIndex Asset to mint token on.
     * @param owner The owner of the new token.
     *
     * Requirements:
     *  - Caller must be an authorized minter
     */
    function mint(uint256 assetIndex, address owner) external whenNotPaused {
        require(hasRole(MINTER_ROLE, _msgSender()), "must have minter role to mint");
        // Get the new token ID
        uint256 tokenId = _tokenCounter.current();
        _tokenCounter.increment();

        // Mint and set the token to the asset index
        _safeMint(owner, tokenId);

        AssetNFT storage asset = _assets[assetIndex];
        asset._status = Status.minted;

        idToAssetIndex.set(assetIndex, tokenId);
        indexToTokenId.set(tokenId, assetIndex);
        _setTokenURI(tokenId, asset._ipfsHash);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerable, ERC721)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function approve(address to, uint256 tokenId) public virtual override {
        require(!isToSell(tokenId) && !isInAuction(tokenId), "This NFT is to trade");
        super.approve(to, tokenId);
    }

    function _burn(uint256 tokenId) internal virtual override(ERC721URIStorage, ERC721) onlyOwner {
        super._burn(tokenId);
    }

    function pauseContract() external onlyOwner {
        _pause();
    }

    function unpauseContract() external onlyOwner {
        _unpause();
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721URIStorage, ERC721) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    /**
     * @notice The base URI path where the token media is hosted.
     * @dev Base URI for computing {tokenURI}
     * @return our metadata URI
     */
    function _baseURI() internal view override returns (string memory) {
        return _prefixURI;
    }

    /**
     * @notice Used to check whether an address has the minter role
     * @param _address EOA or contract being checked
     * @return bool True if the account has the role or false if it does not
     */
    function hasMinterRole(address _address) public view returns (bool) {
        return hasRole(MINTER_ROLE, _address);
    }

    /**
     * @notice Grants the minter role to an address
     * @dev The sender must have the admin role
     * @param _address EOA or contract receiving the new role
     */
    function addMinterRole(address _address) external {
        grantRole(MINTER_ROLE, _address);
        emit MinterRoleGranted(_address, _msgSender());
    }

    /**
     * @notice Removes the minter role from an address
     * @dev The sender must have the admin role
     * @param _address EOA or contract affected
     */
    function removeMinterRole(address _address) external {
        revokeRole(MINTER_ROLE, _address);
        emit MinterRoleRemoved(_address, _msgSender());
    }

    // /**
    //  * @notice It removes the token from the current owner set and adds to new owner.
    //  * @param newOwner the new owner of the tokenID
    //  * @param tokenId the ID of the NFT
    //  */
    // function _setOwner(address newOwner, uint256 tokenId) internal {
    //     address currentOwner = ownerOf(tokenId);
    //     if (currentOwner != address(0)) {
    //         _ownerTokenIDs[currentOwner].remove(tokenId);
    //     }
    //     _ownerTokenIDs[newOwner].add(tokenId);
    // }

    function getMyTokenCollection() public view returns (uint256[] memory myCollectables) {
        return myCollectableAssets[msg.sender];
    }

    function setBaseURI(string memory newBaseUri) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "ERC721: must have admin role to change baseUri");
        _prefixURI = newBaseUri;
    }

    function getTokenIdByAssetIndex(uint256 assetIndex) public view returns (uint256) {
        return idToAssetIndex.get(assetIndex);
    }

    function getAssetIndexByTokenId(uint256 tokenId) public view returns (uint256) {
        return indexToTokenId.get(tokenId);
    }

    function ownerOf(uint256 tokenId) public view override returns (address) {
        return super.ownerOf(tokenId);
    }

    //--------------------- Selling functions ------------------------

    function putToSell(uint256 _tokenId, uint256 _price) public virtual whenNotPaused {
        require(!listings.contains(_tokenId), "listing already exists");
        require(msg.sender == ownerOf(_tokenId), "It is not your token");
        require(msg.sender != address(0), "invalid Address");
        approve(address(this), _tokenId);
        engine.putToSell(_tokenId, _price);
        listings.set(_tokenId, _price);
        _userSellingTokens[msg.sender].add(_tokenId);
        uint256 assetIndex = indexToTokenId.get(_tokenId);
        updateAssetNFTStatus(assetIndex, Status.listed);
    }

    function changeSellingPrice(uint256 _tokenId, uint256 _newPrice) public listingExists(_tokenId) whenNotPaused {
        require(msg.sender == ownerOf(_tokenId), "It is not your token");
        require(msg.sender != address(0), "invalid Address");
        engine.changeSellingPrice(_tokenId, _newPrice);
        listings.set(_tokenId, _newPrice);
        uint256 assetIndex = indexToTokenId.get(_tokenId);
        updateAssetNFTPrice(assetIndex, _newPrice);
    }

    function cancelSelling(uint256 _tokenId) public virtual {
        require(listings.contains(_tokenId), "Non existant token");
        require(msg.sender == ownerOf(_tokenId), "It is not your token");
        require(msg.sender != address(0), "invalid Address");
        approve(address(0), _tokenId);
        engine.cancelSelling(_tokenId);
        listings.remove(_tokenId);
        _userSellingTokens[msg.sender].remove(_tokenId);
        uint256 assetIndex = indexToTokenId.get(_tokenId);
        updateAssetNFTStatus(assetIndex, Status.unListed);
    }

    function buyNFT(uint256 _tokenId) public payable virtual whenNotPaused {
        require(listings.contains(_tokenId), "Non existant token");
        require(msg.sender != ownerOf(_tokenId), "It is your token");
        require(msg.sender != address(0), "invalid Address");
        require(msg.value == listings.get(_tokenId), "Not the price");

        engine.cancelSelling(_tokenId);
        listings.remove(_tokenId);
        _userSellingTokens[ownerOf(_tokenId)].remove(_tokenId);
        /// Bought-amount is transferred into a seller wallet and the fee to EuraNov
        payable(ownerOf(_tokenId)).transfer((msg.value * 97) / 100);
        _casimir.transfer((msg.value * 3) / 100);

        emit SellingSuccess(msg.value, _tokenId, ownerOf(_tokenId), msg.sender);

        uint256 assetIndex = indexToTokenId.get(_tokenId);

        updateAssetNFTStatus(assetIndex, Status.sold);

        /// safeTransfer to the buyer address
        this.safeTransferFrom(ownerOf(_tokenId), msg.sender, _tokenId);

        AssetNFT storage asset = _assets[assetIndex];
        asset._ownerAddress = ownerOf(_tokenId);

        myCollectableAssets[msg.sender].push(assetIndex);
    }

    function isToSell(uint256 _tokenId) public view virtual returns (bool) {
        return engine.isToSell(_tokenId);
    }

    function isInAuction(uint256 tokenID) public view virtual returns (bool) {
        return engine.isInAuction(tokenToAuction[tokenID]);
    }

    function getPrice(uint256 _tokenId) public view returns (uint256) {
        return engine.getPrice(_tokenId);
    }

    function updateEngine(address _engine) external onlyOwner {
        engine = AssetDriving(_engine);
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
