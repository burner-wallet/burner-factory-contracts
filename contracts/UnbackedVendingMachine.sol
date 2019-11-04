pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/introspection/IERC1820Registry.sol";
import "openzeppelin-solidity/contracts/token/ERC777/IERC777Recipient.sol";
import "./VendingMachine.sol";
import "./Whitelist.sol";

contract UnbackedVendingMachine is IERC777Recipient, VendingMachine {
  Whitelist public whitelist;

  constructor(string memory _name, string memory _symbol, uint256 _cap, uint256 timeout, address _whitelist)
    public VendingMachine(_name, _symbol, _cap, timeout)
  {
    whitelist = Whitelist(_whitelist);
    if (_whitelist != address(0)) {
      whitelist.setWhitelisted(address(this), msg.sender, true);
    }
  }

  modifier requireWhitelisted(address user) {
    require(address(whitelist) == address(0) || whitelist.isWhitelisted(address(this), user),
      "Account must be whitelisted");
    _;
  }

  function tokensReceived(
    address /* operator */,
    address /* from */,
    address /* to */,
    uint256 amount,
    bytes calldata /* userData */,
    bytes calldata /* operatorData */
  ) external {
    token.burn(amount, new bytes(0));
  }

  function distribute(address payable[] calldata recipients) external payable {
    revert();
  }

  function distribute(address[] calldata recipients, uint256[] calldata values) external requireWhitelisted(msg.sender) {
    require(recipients.length == values.length);
    for (uint i = 0; i < recipients.length; i += 1) {
      token.mint(recipients[i], values[i], new bytes(0));
    }
  }
}
