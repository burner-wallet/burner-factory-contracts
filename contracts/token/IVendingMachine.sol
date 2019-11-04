pragma solidity ^0.5.0;

contract IVendingMachine {
  function distribute(address payable[] calldata recipients) external payable;
  function forwardRelayDeposit(address sender) external payable;
}
