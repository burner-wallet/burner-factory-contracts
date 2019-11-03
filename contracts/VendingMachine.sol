pragma solidity ^0.5.0;

import "./IVendingMachine.sol";
import "./VendableToken.sol";
import "./SimpleForwardingAddress.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/introspection/IERC1820Registry.sol";
import "openzeppelin-solidity/contracts/token/ERC777/IERC777Recipient.sol";


contract VendingMachine is IVendingMachine {
  using SafeMath for uint256;

  IERC1820Registry private _erc1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

  VendableToken public token;

  SimpleForwardingAddress public relayFundingAddress;
  mapping(address => uint256) public relayDeposits;

  constructor(string memory _name, string memory _symbol, uint256 _cap) public payable {
    deployToken(_name, _symbol, _cap);
    depositInitialRelayFunds();

    relayFundingAddress = new SimpleForwardingAddress();

    _erc1820.setInterfaceImplementer(address(this), keccak256("ERC777TokensRecipient"), address(this));
  }

  function deployToken(
    string memory _name,
    string memory _symbol,
    uint256 _cap
  ) internal {
    address[] memory defaultOperators = new address[](1);
    defaultOperators[0] = address(this);
    token = new VendableToken(_name, _symbol, _cap, defaultOperators);
  }

  function depositInitialRelayFunds() internal {
    if (msg.value > 0) {
      relayDeposits[msg.sender] = msg.value;
      token.depositForRelay.value(msg.value)();
    }
  }

  function depositRelayFunds() external payable {
    relayDeposits[msg.sender] = relayDeposits[msg.sender].add(msg.value);
    token.depositForRelay.value(msg.value)();
  }

  function withdrawRelayFunds() external {
    uint256 totalBalance = token.getRecipientBalance();
    uint256 amount = relayDeposits[msg.sender] < totalBalance ? relayDeposits[msg.sender] : totalBalance;
    relayDeposits[msg.sender] = relayDeposits[msg.sender].sub(amount);
    address payable recipient = address(uint160(msg.sender));
    token.withdrawFromRelay(recipient, amount);
  }

  function forwardRelayDeposit(address sender) external payable {
    require(msg.sender == address(relayFundingAddress));
    relayDeposits[sender] = relayDeposits[sender].add(msg.value);
    token.depositForRelay.value(msg.value)();
  }
}
