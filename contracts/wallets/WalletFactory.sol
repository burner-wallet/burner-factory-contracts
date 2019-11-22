pragma solidity ^0.5.8;

import "./Factory2.sol";
import "./Wallet.sol";

interface InnerWalletFactory {
  function create(address factory, address creator) external returns (Wallet);
  function getAddress(address factory, address creator) view external returns (address);
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
    return innerFactory.getAddress(address(this), creator);
  }

  function createWallet(address creator) external returns (address) {
    return address(innerFactory.create(address(this), creator));
  }

  function createAndExecute(
    address target,
    bytes calldata data,
    uint256 value
  ) external returns (bytes memory response) {
    Wallet wallet = innerFactory.create(address(this), msg.sender);
    return wallet.execute(target, data, value);
  }
}
