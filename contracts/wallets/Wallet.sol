pragma solidity ^0.5.8;

contract Wallet {
  address public creator;

  constructor(address _creator) public {
    creator = _creator;
  }

  function execute(
    address target,
    bytes memory data,
    uint256 value
  ) public payable returns (bytes memory response) {
    require(msg.sender == creator, "Must be called by the creator");

    (bool success, bytes memory returnData) = address(target).call.value(value)(data);
    require(success);
    return returnData;
  }
}
