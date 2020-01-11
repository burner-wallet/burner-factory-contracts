pragma solidity ^0.5.0;

import "./INameToken.sol";
import "./Resolver.sol";

// TODO: Reverse

contract BurnableResolver is Resolver {
  INameToken public token;

  constructor() public {
    token = INameToken(msg.sender);
  }

  function supportsInterface(bytes4 interfaceID) public pure returns (bool) {
    return interfaceID == 0x3b3b57de;
  }

  function addr(bytes32 node) public view returns (address) {
    return token.resolveAddress(node);
  }
}
