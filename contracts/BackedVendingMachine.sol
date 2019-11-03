pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./ForwardingAddress.sol";
import "./VendingMachine.sol";

contract BackedVendingMachine is IERC777Recipient, VendingMachine {
  using SafeMath for uint256;

  event NewForwardingAddress(address forwardingAddress);
  event Distributed(address indexed sender, uint256 total, uint256 share);

  constructor(string memory _name, string memory _symbol, uint256 _cap)
    public payable VendingMachine(_name, _symbol, _cap) {
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
}
