pragma solidity ^0.5.8;

import "openzeppelin-solidity/contracts/cryptography/ECDSA.sol";
import "openzeppelin-solidity/contracts/introspection/IERC1820Registry.sol";
import "openzeppelin-solidity/contracts/token/ERC777/IERC777Recipient.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./ERC1271.sol";
import "./IWallet.sol";
import "./LibBytes.sol";

contract Wallet is ERC1271, IWallet, IERC777Recipient {
  using ECDSA for bytes32;
  using _LibBytes for bytes;
  using SafeMath for uint256;

  uint8 public decimals = 18;
  address public creator;
  uint256 public _nonce;

  mapping(address => bool) public owners;

  event OwnerAdded(address owner);
  event OwnerRemoved(address owner);
  event Transfer(address indexed from, address indexed to, uint256 value);

  function initialize(address _factory, address _creator) external {
    assert(creator == address(0));
    require(_creator != address(0));

    owners[_factory] = true;
    owners[_creator] = true;
    creator = _creator;

    IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24)
      .setInterfaceImplementer(address(this), keccak256("ERC777TokensRecipient"), address(this));
  }

  function () external payable {
    emit Transfer(msg.sender, address(this), msg.value);
  }

  modifier onlyOwner() {
    require(owners[msg.sender] || msg.sender == address(this), "Must be called by the creator");
    _;
  }

  function nonce() external view returns (uint256) {
    return _nonce;
  }

  function execute(
    address target,
    bytes calldata data,
    uint256 value
  ) external payable onlyOwner returns (bytes memory response) {
    _nonce = _nonce.add(1);

    (bool success, bytes memory returnData) = address(target).call.value(value)(data);
    require(success, "Execute failed");
    if (data.length == 0 && value > 0) {
      emit Transfer(address(this), target, value);
    }
    return returnData;
  }

  function executeBatch(
    address[] calldata targets,
    bytes calldata data,
    uint256[] calldata dataLengths,
    uint256[] calldata values
  ) external payable onlyOwner /*returns (bytes memory response, uint256[] responseLengths)*/ {
    _nonce = _nonce.add(1);

    require(targets.length == dataLengths.length && targets.length == values.length, "Invalid lengths");

    uint256 dataPointer = 0;

    for (uint16 i = 0; i < targets.length; i++) {
      bytes memory _data = data.slice(dataPointer, dataPointer + dataLengths[i]);
      dataPointer = dataPointer + dataLengths[i];

      (bool success,) = address(targets[i]).call.value(values[i])(_data);
      require(success, "Batch execute failed");
      if (dataLengths[i] == 0 && values[i] > 0) {
        emit Transfer(address(this), targets[i], values[i]);
      }
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
    require(otherOwner != creator);
    owners[otherOwner] = false;
  }

  function isValidSignature(bytes32 hash, bytes memory signature) public view returns (bytes4) {
    address signer = hash.toEthSignedMessageHash().recover(signature);
    return returnIsValidSignatureMagicNumber(owners[signer]);
  }

  function tokensReceived(
    address /* operator */,
    address /* from */,
    address /* to */,
    uint256 /* amount */,
    bytes calldata /* userData */,
    bytes calldata /* operatorData */
  ) external {}
}
