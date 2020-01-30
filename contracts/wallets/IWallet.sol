pragma solidity ^0.5.8;

contract IWallet {
  function initialize(address factory, address owner) external;
  function execute(
    address target,
    bytes calldata data,
    uint256 value
  ) external payable returns (bytes memory response);

  function isValidSignature(bytes32 hash, bytes memory signature) public view returns (bytes4);

  function addOwner(address newOwner) external;

  function nonce() external view returns (uint256);
}
