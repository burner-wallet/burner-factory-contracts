pragma solidity ^0.5.0;

contract IVendableToken {
  function mint(address to, uint256 amount, bytes memory data) public returns (bool);
}
