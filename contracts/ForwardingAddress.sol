pragma solidity ^0.5.0;
import './IVendingMachine.sol';

contract ForwardingAddress {
  IVendingMachine public vendingMachine;
  address payable[] public recipients;

  constructor(address payable _vendingMachine, address payable[] memory _recipients) public {
    vendingMachine = IVendingMachine(_vendingMachine);
    recipients = _recipients;
  }

  function () payable external {
    if (msg.sender != address(vendingMachine)) {
      vendingMachine.distribute.value(msg.value)(recipients);
      msg.sender.transfer(address(this).balance);
    }
  }
}
