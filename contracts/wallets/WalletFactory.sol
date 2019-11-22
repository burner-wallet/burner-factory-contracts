pragma solidity ^0.5.8;

import "./Factory2.sol";
import "./Wallet.sol";

interface InnerWalletFactory {
  function create(address creator) external returns (Wallet);
  function getAddress(address creator) view external returns (address);
  function setSalt(uint salt) external returns (InnerWalletFactory);
}

contract WalletFactory {
  InnerWalletFactory public innerFactory;

  constructor() public {
    innerFactory = createFactory();
  }

  function createFactory() internal returns (InnerWalletFactory) {
    return InnerWalletFactory(address(new Factory2(type(Wallet).creationCode, InnerWalletFactory(0).create.selector)));
  }

  function getAddress(address creator) external view returns (address) {
    return innerFactory.getAddress(creator);
  }

  function createWallet(address owner) external returns (address) {
    return address(innerFactory.create(owner));
  }
}
