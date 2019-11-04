pragma solidity ^0.5.0;
import './IVendingMachine.sol';

contract ForwardingAddress {
  IVendingMachine public vendingMachine;
  address payable[] public recipients;

  uint constant GAS_THRESHOLD = 90000;

  event ForwardPending();

  constructor(address payable _vendingMachine, address payable[] memory _recipients) public {
    vendingMachine = IVendingMachine(_vendingMachine);
    recipients = _recipients;
  }

  function () payable external {
    if (msg.sender != address(vendingMachine)) {
      if (gasleft() > GAS_THRESHOLD) {
        vendingMachine.distribute.value(address(this).balance)(recipients);
        msg.sender.transfer(address(this).balance);
      } else {
        emit ForwardPending();
      }
    }
  }
}
