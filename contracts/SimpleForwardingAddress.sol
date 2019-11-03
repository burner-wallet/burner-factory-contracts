pragma solidity ^0.5.0;

import "./IVendingMachine.sol";

contract SimpleForwardingAddress {
  IVendingMachine private machine;
  constructor() public {
    machine = IVendingMachine(msg.sender);
  }

  function () payable external {
    require(msg.value != 0);
    machine.forwardRelayDeposit.value(msg.value)(msg.sender);
  }
}
