pragma solidity ^0.5.0;

import "./RelayableERC777.sol";

contract VendableToken is RelayableERC777 {

  address public vendingMachine;
  uint256 public cap;

  mapping(address => uint256) public lastActivity;

  constructor(
      string memory _name,
      string memory _symbol,
      uint256 _cap,
      address[] memory defaultOperators
    ) public RelayableERC777(_name, _symbol, defaultOperators) {
    vendingMachine = msg.sender;
    cap = _cap;
    // expirationTime = _expirationTime;
  }

  modifier onlyVendingMachine {
    require(msg.sender == vendingMachine);
    _;
  }

  /**
   * @dev Function to mint tokens
   * @param to The address that will receive the minted tokens.
   * @param amount The amount of tokens to mint.
   * @return A boolean that indicates if the operation was successful.
   */
  function mint(address to, uint256 amount, bytes memory data) public onlyVendingMachine returns (bool) {
    require(totalSupply().add(amount) <= cap);
    _mint(to, to, amount, data, new bytes(0));
    return true;
  }

  function withdrawFromRelay(address payable recipient, uint256 amount) public onlyVendingMachine {
    _withdrawFromRelay(recipient, amount);
  }
}
