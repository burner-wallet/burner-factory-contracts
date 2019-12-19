pragma solidity ^0.5.8;

import "openzeppelin-solidity/contracts/cryptography/ECDSA.sol";
import "./ERC1271.sol";
import "./IWallet.sol";
import "./LibBytes.sol";

contract Wallet is ERC1271, IWallet {
  using ECDSA for bytes32;
  using _LibBytes for bytes;

  address public creator;

  mapping(address => bool) public owners;

  event OwnerAdded(address owner);
  event OwnerRemoved(address owner);

  function initialize(address _factory, address _creator) external {
    assert(creator == address(0));

    owners[_factory] = true;
    owners[_creator] = true;
    creator = _creator;
  }

  function () external payable {}

  modifier onlyOwner() {
    require(owners[msg.sender] || msg.sender == address(this), "Must be called by the creator");
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

  function executeBatch(
    address[] calldata targets,
    bytes calldata data,
    uint256[] calldata dataLengths,
    uint256[] calldata values
  ) external payable /*onlyOwner returns (bytes memory response, uint256[] responseLengths)*/ {
    require(targets.length == dataLengths.length && targets.length == values.length, "Invalid lengths");

    uint256 dataPointer = 0;

    for (uint8 i = 0; i < targets.length; i++) {
      bytes memory _data = data.slice(dataPointer, dataPointer + dataLengths[i]);
      dataPointer = dataPointer + dataLengths[i];

      (bool success,) = address(targets[i]).call.value(values[i])(_data);
      require(success);
    }
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

  function isValidSignature(bytes32 hash, bytes memory signature) public view returns (bytes4) {
    address signer = hash.toEthSignedMessageHash().recover(signature);
    return returnIsValidSignatureMagicNumber(owners[signer]);
  }
}
