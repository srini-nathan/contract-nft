import hre, { ethers } from "hardhat";
import { Artifact } from "hardhat/types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

import { Asset } from "../typechain/Asset";
import { BigNumber, Contract, ContractFactory, Signer } from "ethers";
import { expect } from "chai";

const { deployContract } = hre.waffle;

enum Status {
  created,
  minted,
}

describe("AssetNFT", () => {
  const { provider } = ethers;
  let accounts: Signer[];

  let admin: Signer;
  let user: Signer;

  let adminAddress: string;
  let userAddress: string;

  before("provider & accounts setting", async () => {
    // @ts-ignore
    accounts = await ethers.getSigners();
    admin = accounts[1];
    user = accounts[2];

    adminAddress = await admin.getAddress();
    userAddress = await user.getAddress();
  });

  let Asset: ContractFactory;
  let AssetDriving: ContractFactory;

  before("fetch contract factories", async () => {
    Asset = await ethers.getContractFactory("Asset");
    AssetDriving = await ethers.getContractFactory("AssetDriving");
  });

  let assetNFT: Contract;
  let assetDriving: Contract;

  before("deploy contracts", async () => {
    assetDriving = await AssetDriving.connect(admin).deploy();
    assetNFT = await Asset.connect(admin).deploy(
      "CasimirX",
      "CRX",
      "https://gateway.pinata.cloud/ipfs/",
      "0xb1F503baB54E397A768cF4bf3a8714843E51A4A1",
      assetDriving.address,
    );
  });

  describe("#constructor", () => {
    it("should works correctly", async () => {
      expect(assetNFT.address).to.be.a("string");
    });

    it("calls `addAsset` function which create asset to be mint", async () => {
      const newAsset = {
        _ipfsHash: "Qmc2k5APh7WQxTupBbyzQC9qeNfBaxKfLMKATuHxCDvaTn",
        _ownerAddress: adminAddress,
        _assetPrice: ethers.utils.parseEther("0.002"),
      };

      await assetNFT.connect(admin).addAsset(newAsset._assetPrice, newAsset._ipfsHash, 123456);
      const result = await assetNFT.getAssetNFT(123456);

      expect(result[0]).to.be.eqls(newAsset._ipfsHash);
      expect(result[1]).to.be.eqls(newAsset._ownerAddress);
      expect(result[2]).to.be.eqls(newAsset._assetPrice);
      expect(result[3]).to.be.eqls(Status.created);
    });
    it("calls `mint` function with asset information", async () => {
      const newAsset = {
        _ipfsHash: "Qmc2k5APh7WQxTupBbyzQC9qeNfBaxKfLMKATuHxCDvaTn",
        _ownerAddress: adminAddress,
        _assetPrice: ethers.utils.parseEther("0.002"),
      };

      await assetNFT.connect(admin).addAsset(newAsset._assetPrice, newAsset._ipfsHash, 123456);

      await assetNFT.connect(admin).mint(123456, newAsset._ownerAddress);

      const tokenId = await assetNFT.connect(admin).getTokenIdByAssetIndex(123456);
      expect(tokenId.toNumber()).to.eql(0);

      const owner = await assetNFT.connect(admin).ownerOf(tokenId);
      expect(owner).to.eql(newAsset._ownerAddress);

      const tokenURI = await assetNFT.connect(admin).tokenURI(tokenId);
      expect(tokenURI).to.eql("https://gateway.pinata.cloud/ipfs/Qmc2k5APh7WQxTupBbyzQC9qeNfBaxKfLMKATuHxCDvaTn");
      const result = await assetNFT.getAssetNFT(123456);
    });
    it("calls `putToSell` function to list asset over marketplace", async () => {
      await assetDriving.connect(admin).registerMember(assetNFT.address);

      const newAsset = {
        _ipfsHash: "Qmc2k5APh7WQxTupBbyzQC9qeNfBaxKfLMKATuHxCDvaTn",
        _ownerAddress: adminAddress,
        _assetPrice: ethers.utils.parseEther("0.002"),
      };

      await assetNFT.connect(admin).addAsset(newAsset._assetPrice, newAsset._ipfsHash, 123456);

      await assetNFT.connect(admin).mint(123456, newAsset._ownerAddress);

      const tokenId = await assetNFT.connect(admin).getTokenIdByAssetIndex(123456);

      await assetNFT.connect(admin).putToSell(tokenId, newAsset._assetPrice);

      const result = await assetNFT.getAssetNFT(123456);
    });

    it("calls `buyNFT` function to transfer token to another user", async () => {
      // await assetDriving.connect(admin).registerMember(assetNFT.address);

      const newAsset = {
        _ipfsHash: "Qmc2k5APh7WQxTupBbyzQC9qeNfBaxKfLMKATuHxCDvaTn",
        _ownerAddress: adminAddress,
        _assetPrice: ethers.utils.parseEther("0.002"),
      };

      await assetNFT.connect(admin).addAsset(newAsset._assetPrice, newAsset._ipfsHash, 123456);

      await assetNFT.connect(admin).mint(123456, newAsset._ownerAddress);

      const tokenId = await assetNFT.connect(admin).getTokenIdByAssetIndex(123456);

      await assetNFT.connect(admin).putToSell(tokenId, newAsset._assetPrice);

      const userBalb = await provider.getBalance(userAddress);
      const adminBalb = await provider.getBalance(adminAddress);

      console.log(userBalb.toString());
      console.log(adminBalb.toString());

      const ownerb =   await assetNFT.connect(user).ownerOf(tokenId)
      console.log(ownerb);
      

      await assetNFT.connect(user).buyNFT(tokenId, { value: ethers.utils.parseEther("0.002") });

      const userBala = await provider.getBalance(userAddress);
      const adminBala = await provider.getBalance(adminAddress);
      console.log(userBala.toString());
      console.log(adminBala.toString());

    const ownera =   await assetNFT.connect(user).ownerOf(tokenId)
    console.log(ownera);

    const result = await assetNFT.getAssetNFTStatus(123456);
    console.log(result);
    
    
    });
  });
});
