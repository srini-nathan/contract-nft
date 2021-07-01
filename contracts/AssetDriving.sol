//SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract AssetDriving is Ownable, Pausable {
    mapping(address => bool) public actionAllowed;
    mapping(address => mapping(uint256 => uint256)) private selling;

    enum Status { pending, active, finished }
    struct Auction {
        address payable creator;
        address payable currentBidOwner;
        uint128 duration;
        uint128 bidCount;
        uint256 assetId;
        uint256 startTime;
        uint256 currentBidAmount;
        bool claimed;
    }

    mapping(address => Auction[]) private auctions;

    function registerMember(address _club) external onlyOwner {
        require(!actionAllowed[_club], "SC already registered");
        actionAllowed[_club] = true;
    }

    function cancelMember(address _club) external onlyOwner {
        actionAllowed[_club] = false;
    }

    function putToSell(uint256 id, uint price) public virtual whenNotPaused {
        require(actionAllowed[msg.sender], "Invalid User");
        require(price > 0, "Price invalid");
        require(msg.sender != address(0), "Invalid address");
        require(!isToSell(id) && !isInAuction(id), "This NFT is already to trade");
        selling[msg.sender][id] = price;
    }

    function changeSellingPrice(uint256 id, uint newPrice) public virtual whenNotPaused {
        require(actionAllowed[msg.sender], "Invalid User");
        require(newPrice > 0, "Price invalid");
        require(isToSell(id), "This token is not to sell");
        require(msg.sender != address(0), "Invalid address");
        require(!isInAuction(id), "This NFT is in auction");
        selling[msg.sender][id] = newPrice;
    }

    function cancelSelling(uint256 id) public virtual {
        require(actionAllowed[msg.sender], "Invalid User");
        require(isToSell(id), "This token is not to sell");
        require(msg.sender != address(0), "Invalid address");
        require(!isInAuction(id), "This NFT is in auction");
        selling[msg.sender][id] = 0;
    }

    function isToSell(uint256 id) public view virtual returns (bool) {
        return selling[msg.sender][id] != 0;
    }

    function getPrice(uint256 id) public view returns (uint) {
        return selling[msg.sender][id];
    }

    function isInAuction(uint256 auctionID) public view virtual returns (bool) {
        if (auctions[msg.sender].length == 0) {
            return false;
        }
        if (auctionID != 0) {
            return isActive(auctionID - 1) || isPending(auctionID - 1);
        }
        return false;
    }

    function isActive(uint256 index) internal view virtual returns (bool) {
        return getStatus(index) == Status.active;
    }

    function isPending(uint256 index) internal view virtual returns (bool) {
        return getStatus(index) == Status.pending;
    }

    function isFinished(uint256 index) internal view virtual returns (bool) {
        return getStatus(index) == Status.finished;
    }

    function getStatus(uint256 index) public view virtual returns (Status) {
        Auction storage auction = auctions[msg.sender][index];
        if (block.timestamp < auction.startTime + auction.duration * 1 minutes) {
            return Status.active;
        } else if (!auction.claimed) {
            return Status.pending;
        } else {
            return Status.finished;
        }
    }
}
