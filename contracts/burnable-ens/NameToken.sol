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
  }

  mapping(uint256 => Name) private tokens;
  mapping(bytes32 => uint256) public nodeToTokenId;

  uint256 public expirationTime;
  uint256 public extentionTime;
  uint256 private nextId;

  address public resolver;
  bytes32 public rootNode;
  ENSRegistry private ens;

  event Registered(bytes32 node, uint256 id);

  constructor(ENSRegistry _ens, bytes32 _rootNode, uint256 _expirationTime, uint256 _extentionTime) public {
    ens = _ens;
    rootNode = _rootNode;
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

  function register(bytes32 label) external {
    bytes32 node = keccak256(abi.encodePacked(rootNode, label));

    if (nodeToTokenId[node] != 0) {
      require(isTokenExpired(nodeToTokenId[node]), "Address is already registered");
    }

    nextId = nextId + 1;
    _mint(_msgSender(), nextId);
    nodeToTokenId[node] = nextId;
    tokens[nextId].registrationTime = now;
    tokens[nextId].node = node;

    ens.setSubnodeOwner(rootNode, label, address(this));
    ens.setResolver(node, resolver);
  }
}
