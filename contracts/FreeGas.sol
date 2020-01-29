pragma solidity ^0.5.0;

import 'openzeppelin-solidity/contracts/GSN/GSNRecipient.sol';

contract SimpleForwardingAddress {
  FreeGas private parent;
  constructor() public {
    parent = FreeGas(msg.sender);
  }

  function () payable external {
    require(msg.value != 0);
    parent.depositForRelay.value(msg.value)();
  }
}

contract FreeGas is GSNRecipient {
  SimpleForwardingAddress public gsnDepositAddress;

  constructor() public {
    gsnDepositAddress = new SimpleForwardingAddress();
  }

  // accept all requests
  function acceptRelayedCall(
    address,
    address,
    bytes calldata,
    uint256,
    uint256,
    uint256,
    uint256,
    bytes calldata,
    uint256
  ) external view returns (uint256, bytes memory) {
    return _approveRelayedCall();
  }

  function getRecipientBalance() public view returns (uint) {
    return getRelayHub().balanceOf(address(this));
  }

  function depositForRelay() public payable {
    getRelayHub().depositFor.value(msg.value)(address(this));
  }

  function getRelayHub() internal view returns (IRelayHub) {
    return IRelayHub(getHubAddr());
  }

  function _preRelayedCall(bytes memory) internal returns (bytes32) {
    // solhint-disable-previous-line no-empty-blocks
  }

  function _postRelayedCall(bytes memory, bool, uint256, bytes32) internal {
    // solhint-disable-previous-line no-empty-blocks
  }

}
