pragma solidity ^0.5.0;

import 'openzeppelin-solidity/contracts/token/ERC721/IERC721.sol';

contract INameToken is IERC721 {
  function resolve(bytes32 node) public view returns (address);
}
