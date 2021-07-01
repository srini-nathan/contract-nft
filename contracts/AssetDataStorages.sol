// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

import { AssetDataObjects } from "./AssetDataObjects.sol";


// shared storage
contract AssetDataStorages is AssetDataObjects {

    AssetNFT[] public assets;

}