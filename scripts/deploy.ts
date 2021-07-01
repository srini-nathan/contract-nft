import { Contract } from "@ethersproject/contracts";
// We require the Hardhat Runtime Environment explicitly here. This is optional but useful for running the
// script in a standalone fashion through `node <script>`. When running the script with `hardhat run <script>`,
// you'll find the Hardhat Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

import { Asset__factory, AssetMarketPlace__factory, AssetDriving__factory } from "../typechain";

async function main(): Promise<void> {

  
  const AssetDriving: AssetDriving__factory = await ethers.getContractFactory("AssetDriving");

  const assetDriving: Contract = await AssetDriving.deploy();
  assetDriving.deployed();
  console.log("AssetDriving deployed to: ", assetDriving.address);

  const AssetNFTData: Asset__factory = await ethers.getContractFactory("Asset");
  const assetNFTData: Contract = await AssetNFTData.deploy(
    "CasimirX",
    "CRX",
    "https://gateway.pinata.cloud/ipfs/",
    "0xb1F503baB54E397A768cF4bf3a8714843E51A4A1",
    assetDriving.address
  );
  await assetNFTData.deployed();
  console.log("AssetNFTData deployed to: ", assetNFTData.address);

  //const AssetMarketPlace: AssetMarketPlace__factory = await ethers.getContractFactory("AssetMarketPlace");
  // const assetMarketPlace: Contract = await AssetMarketPlace.deploy(
  //   assetDriving.address,
  //   assetNFTData.address,
  //   "0xb1F503baB54E397A768cF4bf3a8714843E51A4A1",
  // );
  // assetMarketPlace.deployed();
  // console.log("AssetMarketPlace deployed to: ", assetMarketPlace.address);
}

// We recommend this pattern to be able to use async/await everywhere and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
