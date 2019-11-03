pragma solidity ^0.5.0;

import "./ForwardingAddress.sol";
import './IVendingMachine.sol';

contract NativeVendingMachine is IVendingMachine {
  event NewForwardingAddress(address forwardingAddress);
  event Distributed(address indexed sender, uint256 total, uint256 share);

  function distribute(address payable[] calldata recipients) external payable {
    uint256 share = msg.value / recipients.length;
    uint256 remainder = msg.value % recipients.length;
    for (uint i = 0; i < recipients.length; i += 1) {
      recipients[i].transfer(share);
    }
    msg.sender.transfer(remainder);
    emit Distributed(msg.sender, msg.value - remainder, share);
  }

  function createForwardingAddress(address payable[] calldata recipients) external {
    ForwardingAddress newAddress = new ForwardingAddress(address(uint160(address(this))), recipients);
    emit NewForwardingAddress(address(newAddress));
  }

  function forwardRelayDeposit(address sender) external payable {}
}
