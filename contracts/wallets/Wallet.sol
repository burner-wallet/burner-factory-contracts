pragma solidity ^0.5.8;

contract Wallet {
  address public creator;

  mapping(address => bool) public owners;

  event OwnerAdded(address owner);
  event OwnerRemoved(address owner);

  constructor(address _factory, address _creator) public {
    owners[_factory] = true;
    owners[_creator] = true;
    owners[address(this)] = true;
    emit OwnerAdded(_creator);
  }

  modifier onlyOwner() {
    require(owners[msg.sender], "Must be called by the creator");
    _;
  }

  function execute(
    address target,
    bytes calldata data,
    uint256 value
  ) external payable onlyOwner returns (bytes memory response) {
    (bool success, bytes memory returnData) = address(target).call.value(value)(data);
    require(success);
    return returnData;
  }

  function isOwner(address owner) external view returns (bool) {
    return owners[owner];
  }

  function addOwner(address newOwner) external onlyOwner {
    owners[newOwner] = true;
  }

  function removeOwner(address otherOwner) external onlyOwner {
    require(otherOwner != msg.sender);
    require(creator != msg.sender);
    owners[otherOwner] = false;
  }
}
