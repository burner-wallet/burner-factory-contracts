pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/introspection/IERC1820Registry.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC777/IERC777Recipient.sol";
import "./ForwardingAddress.sol";
import "./VendableToken.sol";

contract SimpleForwardingAddress {
  BackedVendingMachine private machine;
  constructor() public {
    machine = BackedVendingMachine(msg.sender);
  }

  function () payable external {
    require(msg.value != 0);
    machine.forward.value(msg.value)(msg.sender);
  }
}

contract BackedVendingMachine is IERC777Recipient {
  using SafeMath for uint256;

  VendableToken public token;
  SimpleForwardingAddress public relayFundingAddress;
  mapping(address => uint256) public relayDeposits;

  IERC1820Registry private _erc1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

  event NewForwardingAddress(address forwardingAddress);
  event Distributed(address indexed sender, uint256 total, uint256 share);

  constructor(string memory _name, string memory _symbol, uint256 _cap, address relayHub) public payable {
    token = new VendableToken(address(this), _name, _symbol, _cap, relayHub);
    relayFundingAddress = new SimpleForwardingAddress();

    _erc1820.setInterfaceImplementer(address(this), keccak256("ERC777TokensRecipient"), address(this));

    if (msg.value > 0) {
      relayDeposits[msg.sender] = msg.value;
      token.depositForRelay.value(msg.value)();
    }
  }

  function () payable external {
    token.mint(msg.sender, msg.value, msg.data);
  }

  function tokensReceived(
    address /* operator */,
    address from,
    address /* to */,
    uint256 amount,
    bytes calldata /* userData */,
    bytes calldata /* operatorData */
  ) external {
    token.burn(amount, new bytes(0));
    address payable _from = address(uint160(from));
    _from.transfer(amount);
  }

  function distribute(address payable[] calldata recipients) external payable {
    uint256 share = msg.value / recipients.length;
    uint256 remainder = msg.value % recipients.length;
    for (uint i = 0; i < recipients.length; i += 1) {
      token.mint(recipients[i], share, new bytes(0));
    }
    msg.sender.transfer(remainder);
    emit Distributed(msg.sender, msg.value - remainder, share);
  }

  function createForwardingAddress(address payable[] calldata recipients) external {
    ForwardingAddress newAddress = new ForwardingAddress(address(this), recipients);
    emit NewForwardingAddress(address(newAddress));
  }

  function forward(address sender) external payable {
    require(msg.sender == address(relayFundingAddress));
    relayDeposits[sender] = relayDeposits[sender].add(msg.value);
    token.depositForRelay.value(msg.value)();
  }

  function depositRelayFunds() external payable {
    relayDeposits[msg.sender] = relayDeposits[msg.sender].add(msg.value);
    token.depositForRelay.value(msg.value)();
  }

  function withdrawRelayFunds() external {
    token.withdrawFromRelay();
  }
}
