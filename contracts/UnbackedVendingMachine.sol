pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/introspection/IERC1820Registry.sol";
import "openzeppelin-solidity/contracts/token/ERC777/IERC777Recipient.sol";
import "./VendableToken.sol";

contract UnbackedVendingMachine is IERC777Recipient {

  VendableToken public token;

  IERC1820Registry private _erc1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

  mapping(address => bool) private admins;

  constructor(string memory _name, string memory _symbol, uint256 _cap, address relayHub) public {
    token = new VendableToken(address(this), _name, _symbol, _cap, relayHub);
    admins[msg.sender] = true;

    _erc1820.setInterfaceImplementer(address(this), keccak256("ERC777TokensRecipient"), address(this));
  }

  modifier onlyAdmin() {
    require(admins[msg.sender]);
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

  function distribute(address[] calldata recipients, uint256[] calldata values) external onlyAdmin {
    require(recipients.length == values.length);
    for (uint i = 0; i < recipients.length; i += 1) {
      token.mint(recipients[i], values[i], new bytes(0));
    }
  }

  function setAdmin(address user, bool isAdmin) external onlyAdmin {
    require(msg.sender != user);
    admins[user] = isAdmin;
  }
}
