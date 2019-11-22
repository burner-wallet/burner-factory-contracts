pragma solidity ^0.5.8;

contract Wallet {
  address public creator;
  address public factory;

  constructor(address _factory, address _creator) public {
    factory = _factory;
    creator = _creator;
  }

  function execute(
    address target,
    bytes calldata data,
    uint256 value
  ) external payable returns (bytes memory response) {
    require(msg.sender == creator || msg.sender == factory, "Must be called by the creator");

    (bool success, bytes memory returnData) = address(target).call.value(value)(data);
    require(success);
    return returnData;
  }
}
