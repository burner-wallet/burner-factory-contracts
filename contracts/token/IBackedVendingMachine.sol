pragma solidity ^0.5.0;

contract IBackedVendingMachine {

  function () payable external;

  function distribute(address payable[] calldata recipients) external payable;
  function createForwardingAddress(address payable[] calldata recipients) external;
}
