pragma solidity ^0.5.0;

import '@ensdomains/ens/contracts/ENSRegistry.sol';
import 'openzeppelin-solidity/contracts/GSN/Context.sol';
import 'openzeppelin-solidity/contracts/token/ERC721/ERC721.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';
import 'openzeppelin-solidity/contracts/math/SafeMath.sol';
import './BurnableResolver.sol';
import './INameToken.sol';

contract NameToken is Context, Ownable, ERC721, INameToken {
  struct Name {
    uint256 registrationTime;
    bytes32 node;
    string name;
  }

  mapping(uint256 => Name) private tokens;
  mapping(bytes32 => uint256) private nodeToTokenId;
  mapping(address => uint256) private addressToTokenId;

  uint256 public expirationTime;
  uint256 public extentionTime;
  uint256 private nextId;

  address public resolver;
  bytes32 public rootNode;
  string public domain;
  ENSRegistry private ens;

  event Registered(bytes32 node, uint256 id);

  constructor(
    ENSRegistry _ens,
    bytes32 _rootNode,
    string memory _domain,
    uint256 _expirationTime,
    uint256 _extentionTime
  ) public {
    ens = _ens;
    rootNode = _rootNode;
    domain = _domain;
    expirationTime = _expirationTime;
    extentionTime = _extentionTime;
    resolver = address(new BurnableResolver());
  }

  function isTokenExpired(uint256 id) public view returns (bool) {
    return now - tokens[id].registrationTime > expirationTime;
  }

  function canExtend(uint256 id) public view returns (bool) {
    return now - tokens[id].registrationTime > extentionTime;
  }

  function setExpirationTime(uint256 newExpirationTime) external onlyOwner {
    expirationTime = newExpirationTime;
  }

  function setExtentionTime(uint256 newExtentionTime) external onlyOwner {
    extentionTime = newExtentionTime;
  }

  function transferENSOwnership(address newOwner) external onlyOwner {
    ens.setOwner(rootNode, newOwner);
  }

  function ownerOf(uint256 tokenId) public view returns (address) {
    if (isTokenExpired(tokenId)) {
      return address(0);
    }
    return ERC721.ownerOf(tokenId);
  }

  function reverse(address user) public view returns (bytes32) {
    uint256 id = addressToTokenId[user];
    if (isTokenExpired(id)) {
      return bytes32(0);
    }
    return tokens[id].node;
  }

  function name(address user) public view returns (string memory) {
    uint256 id = addressToTokenId[user];
    if (isTokenExpired(id)) {
      return '';
    }
    return string(abi.encodePacked(tokens[id].name, '.', domain));
  }

  function resolveToken(bytes32 node) public view returns (uint256) {
    uint256 tokenId = nodeToTokenId[node];
    if (isTokenExpired(tokenId)) {
      return 0;
    }
    return tokenId;
  }

  function resolveAddress(bytes32 node) public view returns (address) {
    uint256 tokenId = nodeToTokenId[node];
    if (isTokenExpired(tokenId)) {
      return address(0);
    }
    return ERC721.ownerOf(tokenId);
  }

  function register(string calldata _name) external {
    bytes32 label = keccak256(bytes(_name));
    bytes32 node = keccak256(abi.encodePacked(rootNode, label));
    address sender = _msgSender();

    if (nodeToTokenId[node] != 0) {
      require(isTokenExpired(nodeToTokenId[node]), "Name is already registered");
    }

    require(isTokenExpired(addressToTokenId[sender]), "User already holds token");

    nextId = nextId + 1;
    _mint(sender, nextId);
    nodeToTokenId[node] = nextId;
    tokens[nextId].registrationTime = now;
    tokens[nextId].node = node;
    tokens[nextId].name = _name;
    addressToTokenId[sender] = nextId;

    ens.setSubnodeOwner(rootNode, label, address(this));
    ens.setResolver(node, resolver);
  }
}
