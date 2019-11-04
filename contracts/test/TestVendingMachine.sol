pragma solidity ^0.5.0;

import '../token/VendingMachine.sol';

contract TestVendingMachine is VendingMachine {
  constructor(uint timeout) public VendingMachine("Test Token", "TST", 100 ether, timeout) payable {
    token.mint(msg.sender, 100 ether, new bytes(0));
  }

  function distribute(address payable[] calldata recipients) external payable {}

  function time() external view returns (uint) {
    return now;
  }

  function recover(address from, address to, uint256 amount) external {
    _recover(from, to, amount);
  }
}
