pragma solidity ^0.5.0;
import "./IVendingMachine.sol";
import "./VendableToken.sol";

contract VendingMachine is IVendingMachine {
  VendableToken public token;

  function deployToken(
    string memory _name,
    string memory _symbol,
    uint256 _cap
  ) internal returns (VendableToken) {
    address[] memory defaultOperators;
    defaultOperators[0] = address(this);
    token = new VendableToken(_name, _symbol, _cap, defaultOperators);
  }
}