pragma solidity ^0.5.8;

contract Wallet {
  address public creator;

  constructor(address _creator) public {
    creator = _creator;
  }
}