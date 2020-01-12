pragma solidity ^0.5.0;

import "./INameResolver.sol";
import "./INameToken.sol";
import "./Resolver.sol";

contract BurnableResolver is Resolver, INameResolver {
  INameToken public token;

  constructor() public {
    token = INameToken(msg.sender);
  }

  function supportsInterface(bytes4 interfaceID) public pure returns (bool) {
    return interfaceID == 0x3b3b57de // addrResolver
      || interfaceID == 0x691f3431; // nameResolver
  }

  function addr(bytes32 node) public view returns (address) {
    return token.resolveAddress(node);
  }

  function name(bytes32 node) external view returns (string memory) {
    address user = token.reverseNodes(node);
    if (user == address(0)) {
      user = token.resolveAddress(node);
    }
    return token.name(user);
  }
}
