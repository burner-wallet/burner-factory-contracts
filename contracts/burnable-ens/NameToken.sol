pragma solidity ^0.5.0;

import '@ensdomains/ens/contracts/ENSRegistry.sol';
import 'openzeppelin-solidity/contracts/GSN/Context.sol';
import 'openzeppelin-solidity/contracts/token/ERC721/ERC721.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';
import 'openzeppelin-solidity/contracts/math/SafeMath.sol';
import './BurnableResolver.sol';
import './INameToken.sol';

contract NameToken is Context, Ownable, ERC721, INameToken {
  bytes32 private constant ADDR_REVERSE_NODE = 0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2;

  struct Name {
    bytes32 node;
    uint256 registrationTime;
    string name;
  }

  mapping(uint256 => Name) private tokens;
  mapping(bytes32 => uint256) private nodeToTokenId;
  mapping(address => uint256) private addressToTokenId;
  mapping(bytes32 => address) private _reverseNodes;

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

  function reverseNodes(bytes32 node) public view returns (address) {
    return _reverseNodes[node];
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

    bytes32 reverseNode = keccak256(abi.encodePacked(ADDR_REVERSE_NODE, sha3HexAddress(sender)));
    _reverseNodes[reverseNode] = sender;

    ens.setSubnodeOwner(rootNode, label, address(this));
    ens.setResolver(node, resolver);
  }

  function burn(uint256 id) external {
    require(!isTokenExpired(id));

    _burn(_msgSender(), id);
    tokens[id].node = bytes32(0);
    tokens[id].registrationTime = 0;
    tokens[id].name = '';
  }

  /**
   * @dev An optimised function to compute the sha3 of the lower-case
   *      hexadecimal representation of an Ethereum address.
   * @param addr The address to hash
   * @return The SHA3 hash of the lower-case hexadecimal encoding of the
   *         input address.
   */
  function sha3HexAddress(address addr) private pure returns (bytes32 ret) {
    addr;
    ret; // Stop warning us about unused variables
    assembly {
      let lookup := 0x3031323334353637383961626364656600000000000000000000000000000000

      for { let i := 40 } gt(i, 0) { } {
        i := sub(i, 1)
        mstore8(i, byte(and(addr, 0xf), lookup))
        addr := div(addr, 0x10)
        i := sub(i, 1)
        mstore8(i, byte(and(addr, 0xf), lookup))
        addr := div(addr, 0x10)
      }

      ret := keccak256(0, 40)
    }
  }
}
